import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/shared/design_system/theme/app_theme.dart';
import 'package:libredb_mobile/shared/design_system/theme/app_theme_palette.dart';

import '../support/dart_code.dart';

/// Guards that no control in this app answers a finger with a spreading circle.
///
/// Material's ink is two separate things, and only one of them is the "shadow on tap" the owner asked to be rid of:
///
/// * the **splash** grows out of the touch point, past the control's own fill and over whatever is behind it, which
///   is what reads as a shadow hanging off the control (#416 took one of these off the login theme switch, and #417
///   is the app-wide half of the same complaint);
/// * the **highlight** is a flat tint clipped to the control's own shape — no growth, no halo — and it is what is
///   left to tell a finger that the press landed.
///
/// So the splash goes and the highlight stays, which is why this file does not simply assert that a pressed control
/// draws nothing. The opposite guard — that a press is still *visible* — is `test/support/pressed_frame.dart` and the
/// four files that measure `visiblePressFraction` against a real pressed frame; turning both inks off re-creates the
/// defect of #367, where a control used on eight screens answered a finger with nothing.
///
/// The three tests catch different ways the splash could come back:
///
/// * the theme test catches a `ThemeData` built without the lever, which is how every control gets Flutter's M3
///   default (`InkSparkle`) back at once;
/// * the widget test catches a control that carries its own `splashFactory` past the theme — every
///   `ButtonStyleButton` does exactly that, through `ButtonStyle`, so the theme-level lever reaching them is a
///   measured fact here rather than an assumption;
/// * the source test catches a widget nothing in this file pumps.
void main() {
  /// Every `ThemeData` the app can be shown in.
  Iterable<(String, ThemeData)> themes() => [
    for (final palette in AppThemePalette.values) ...[
      ('light/${palette.name}', AppTheme.light(palette)),
      ('dark/${palette.name}', AppTheme.dark(palette)),
    ],
  ];

  test('no theme the app can be shown in spreads a splash out of the touch point', () {
    final offenders = <String>[];
    for (final (name, theme) in themes()) {
      if (theme.splashFactory != NoSplash.splashFactory) offenders.add('$name — ${theme.splashFactory}');
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'these themes answer a tap with a circle that grows out of the touch point and over what is behind the '
          'control, which is the shadow #417 removed.\n'
          'Set `splashFactory: NoSplash.splashFactory` on the shared builder in '
          '`lib/shared/design_system/theme/app_theme.dart`:\n'
          '${offenders.join('\n')}',
    );
  });

  test('every theme still keeps the flat highlight, so a press is not silent', () {
    // Not a measurement — `pressed_frame.dart` does that against real pixels. This only pins the second half of the
    // decision, so a later change cannot reach "no splash" by taking all the ink away.
    final offenders = <String>[];
    for (final (name, theme) in themes()) {
      if (theme.highlightColor.a == 0) offenders.add('$name — ${theme.highlightColor}');
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'these themes have no press highlight left either, so a control answers a finger with nothing — the '
          'defect of #367, re-created while removing the splash:\n${offenders.join('\n')}',
    );
  });

  testWidgets('a control built under the app theme hands its ink no splash factory', (tester) async {
    // A `ButtonStyleButton` resolves its own `ButtonStyle.splashFactory` and passes it to the `InkWell` it builds, so
    // a theme-level lever reaching it is not obvious from the theme alone. Flutter's M3 defaults read it off the
    // theme, and this is what says that is still true for the widgets this app actually uses.
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: ListView(
            children: [
              FilledButton(onPressed: () {}, child: const Text('Filled')),
              OutlinedButton(onPressed: () {}, child: const Text('Outlined')),
              TextButton(onPressed: () {}, child: const Text('Text')),
              IconButton(onPressed: () {}, icon: const Icon(Icons.add)),
              ListTile(title: const Text('Tile'), onTap: () {}),
              InkWell(onTap: () {}, child: const SizedBox(height: 40)),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // `InkWell` is an `InkResponse`, so this finds both spellings of a control's ink.
    final inks = find.byWidgetPredicate((widget) => widget is InkResponse);
    expect(inks, findsWidgets, reason: 'no ink was found at all — the guard is looking for the wrong widget');

    final offenders = <String>[];
    for (final element in inks.evaluate()) {
      final ink = element.widget as InkResponse;
      // `null` is the control deferring to the theme, which the test above pins to `NoSplash`.
      if (ink.splashFactory == null || ink.splashFactory == NoSplash.splashFactory) continue;
      // The chain, rather than the ink itself: every offender is an `InkWell`, and what has to be named is the
      // control that built it.
      offenders.add('${ink.splashFactory} under ${element.debugGetCreatorChain(12)}');
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'these controls carry a splash of their own past the theme, so the app-wide lever does not reach them.\n'
          'Give the widget `splashFactory: NoSplash.splashFactory` where it builds its ink:\n'
          '${offenders.join('\n')}',
    );
  });

  test('no file in lib/ names a splash factory other than NoSplash', () {
    // A source guard as well as the two above, because the widget test can only speak for the controls it pumps, and
    // the next control to be given a splash of its own does not exist yet.
    final offenders = <String>[];
    var themeSetsTheLever = false;
    const themeFile = 'lib/shared/design_system/theme/app_theme.dart';

    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final path = entity.path.replaceAll(r'\', '/');
      final code = codeOnly(entity.readAsStringSync());
      for (final match in RegExp(r'splashFactory\s*:\s*([A-Za-z0-9_.]+)').allMatches(code)) {
        final factory = match.group(1)!;
        if (factory == 'NoSplash.splashFactory') {
          if (path == themeFile) themeSetsTheLever = true;
          continue;
        }
        final line = '\n'.allMatches(code.substring(0, match.start)).length + 1;
        offenders.add('$path:$line — $factory');
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'each of these puts a spreading splash back on one control, under a theme that removed it everywhere:\n'
          '${offenders.join('\n')}',
    );
    expect(
      themeSetsTheLever,
      isTrue,
      reason:
          'the shared theme builder in $themeFile no longer sets `splashFactory: NoSplash.splashFactory`, so every '
          'control is back on Flutter\'s default splash.',
    );
  });
}
