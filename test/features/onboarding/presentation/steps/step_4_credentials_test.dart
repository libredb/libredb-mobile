@Tags(['widget'])
library;

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/features/onboarding/presentation/steps/step_4_credentials.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/shared/design_system/theme/app_theme.dart';
import 'package:libredb_mobile/shared/design_system/tokens/app_typography.dart';

/// How far past the left or right edge of its own box the screen draws, on the frame now on screen, in logical
/// pixels. Zero when every box of the hero is inside it.
///
/// This is measured off the laid-out boxes rather than read off Flutter's overflow stripe, because the stripe is a
/// debug-paint artefact of `RenderFlex` alone: a `Positioned`, an `Align` or a `Transform` that puts something
/// outside the hero draws no stripe and throws nothing. The hero's own box is the reference, so the measurement does
/// not depend on where the chassis puts it.
double _drawsOutsideItsBox(WidgetTester tester) {
  final hero = tester.renderObject<RenderBox>(find.byType(Step4Credentials));
  var worst = 0.0;
  void measure(RenderObject node) {
    // A box that is popping scales to 1.05 of itself for 400 ms and the hero clips it at its edge, as the prototype's
    // `overflow-x:hidden` does; its words are measured on every other frame.
    final creator = node.debugCreator;
    if (creator is DebugCreator) {
      final key = creator.element.widget.key;
      if (key is ValueKey<String> && key.value.startsWith('ob4-pop')) return;
    }
    if (node is RenderBox && node.hasSize) {
      final box = MatrixUtils.transformRect(node.getTransformTo(hero), Offset.zero & node.size);
      worst = max(worst, max(box.right - hero.size.width, -box.left));
    }
    node.visitChildren(measure);
  }

  measure(hero);
  return worst;
}

/// The fourth screen's hero: this app, Studio and the database on one wire, the padlock shutting on Studio, and rows
/// coming back up.
///
/// What is settled here is the claim the screen makes. The padlock is open until its own beat and shut after it, and
/// the token that carries `seed:7` never leaves the wire between the app and Studio — the drawing says the request
/// stops at Studio, so the drawing is what is measured, not the caption.
void main() {
  /// The whole timeline and a little more, so a pump of this length lands on the finished screen.
  const past = Duration(seconds: 6);

  Future<void> show(
    WidgetTester tester, {
    bool animations = true,
    Locale locale = const Locale('en'),
    double textScale = 1.0,
    double heroWidth = 318,
  }) async {
    addTearDown(tester.view.reset);
    // A hero wider than the phone needs a screen wider than it: the scroll view hands its child the screen's width.
    tester.view.physicalSize = Size(heroWidth > 390 ? heroWidth + 100 : 390, 844);
    tester.view.devicePixelRatio = 1.0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        locale: locale,
        localizationsDelegates: const [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.delegate.supportedLocales,
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(disableAnimations: !animations, textScaler: TextScaler.linear(textScale)),
            // The hero box the chassis gives a step scrolls, as the prototype's does, so a step that
            // grows past it is the ordinary case. What must not happen is an overflow.
            child: Scaffold(
              body: SingleChildScrollView(
                // The hero's own width, not the screen's: the chassis pads the panel 48 pt on the
                // leading edge and 24 on the trailing one, which leaves a step 318 pt on a 390 pt phone.
                // A step tested at the full screen width is tested 48 pt wider than it will ever be.
                child: SizedBox(width: heroWidth, child: const Step4Credentials()),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// How wide a box is drawn, scale included: `getRect` takes the transformed corner and the untransformed size.
  double drawnWidth(WidgetTester tester, String key) {
    final finder = find.byKey(ValueKey(key));
    return tester.getBottomRight(finder).dx - tester.getTopLeft(finder).dx;
  }

  S l10n(WidgetTester tester) => S.of(tester.element(find.byType(Step4Credentials)));

  group('the key on Studio', () {
    Color keyColour(WidgetTester tester) {
      final painter = tester.widget<CustomPaint>(
        find.descendant(of: find.byKey(const ValueKey('ob4-key')), matching: find.byType(CustomPaint)),
      );
      return (painter.painter! as dynamic).color as Color;
    }

    testWidgets('is the edge ink before its beat and the accent after it', (tester) async {
      await show(tester);
      final colors = AppTheme.light().colorScheme;
      await tester.pump(Step4Credentials.keyShutsAt - const Duration(milliseconds: 20));
      expect(keyColour(tester), colors.outline);

      await tester.pump(const Duration(milliseconds: 500));
      expect(keyColour(tester), colors.primary);
    });

    testWidgets('stays shut to the end, 16 drawn at 1.15 of itself', (tester) async {
      await show(tester);
      await tester.pump(past);
      expect(keyColour(tester), AppTheme.light().colorScheme.primary);
      expect(drawnWidth(tester, 'ob4-key'), closeTo(18.4, 0.1));
    });

    testWidgets('is a key, not a padlock', (tester) async {
      await show(tester);
      await tester.pump(past);
      expect(find.byIcon(Icons.lock_outline), findsNothing);
      expect(find.byIcon(Icons.lock_open_outlined), findsNothing);
    });
  });

  group('what travels', () {
    testWidgets('the token carrying seed:7 never leaves the wire above Studio', (tester) async {
      await show(tester);
      final wire = find.byKey(Step4Credentials.upperWireKey);
      final token = find.byKey(Step4Credentials.requestTokenKey);
      var sawIt = false;
      for (var elapsed = Duration.zero; elapsed < past; elapsed += const Duration(milliseconds: 40)) {
        if (token.evaluate().isNotEmpty) {
          sawIt = true;
          final travelled = tester.getRect(token);
          final rails = tester.getRect(wire);
          expect(
            rails.inflate(1).contains(travelled.topLeft) && rails.inflate(1).contains(travelled.bottomRight),
            isTrue,
            reason: 'the request token was at $travelled, outside the upper wire $rails',
          );
        }
        await tester.pump(const Duration(milliseconds: 40));
      }
      expect(sawIt, isTrue, reason: 'the request token was never drawn');
    });

    testWidgets('the comet moves down the wire rather than sitting still, and the token stays where it is', (
      tester,
    ) async {
      await show(tester);
      await tester.pump(Step4Credentials.requestAt + const Duration(milliseconds: 120));
      final first = tester.getRect(find.byKey(const ValueKey('ob4-comet-upper'))).top;
      final token = tester.getRect(find.byKey(Step4Credentials.requestTokenKey)).top;
      await tester.pump(const Duration(milliseconds: 200));
      final later = tester.getRect(find.byKey(const ValueKey('ob4-comet-upper'))).top;
      expect(later, greaterThan(first));
      expect(tester.getRect(find.byKey(Step4Credentials.requestTokenKey)).top, token);
    });

    testWidgets('the closing note, that rows come back and the password does not, shows at the end', (tester) async {
      await show(tester);
      await tester.pump(Step4Credentials.rowsReturnAt - const Duration(milliseconds: 40));
      final s = l10n(tester);
      expect(tester.widget<Opacity>(find.byKey(Step4Credentials.closingNoteKey)).opacity, 0.0);

      await tester.pump(past);
      expect(tester.widget<Opacity>(find.byKey(Step4Credentials.closingNoteKey)).opacity, 1.0);
      expect(find.text('\u2191 ${s.ob4_back}'), findsOneWidget);
    });
  });

  /// The geometry of the prototype's fourth screen, read in headless Chrome at 390x844 (Turkish, light; the same in
  /// English and dark). Three nodes of 54 (`padding:10px 12px` round a 16 title and a 14 line 2 below it, in a 1px
  /// border, radius 12) on two wires of 42, a rail at 26 and the pill at 10 and 12 into the wire (18 high,
  /// `padding:2px 7px`), the key 16 square at the trailing end, and a note 8 under the last node: 270.5 in all.
  ///
  /// **The font trap:** every height here is a box round a line whose height is a multiplier of its size, which Ahem
  /// lays out as the product font does, and every width is read as a box less the text inside it.
  group('the screen is the prototype\'s', () {
    Rect rect(WidgetTester tester, String key) => tester.getRect(find.byKey(ValueKey(key)));

    testWidgets('three nodes of 54, two wires of 42 and a note, 270.5 in all', (tester) async {
      // 700 wide so the note is the one line it is on a phone and not two of Ahem's.
      await show(tester, heroWidth: 700);
      await tester.pump(past);

      for (var i = 0; i < 3; i++) {
        expect(rect(tester, 'ob4-node-$i').height, closeTo(54, 0.5), reason: 'node $i');
      }
      expect(tester.getRect(find.byKey(Step4Credentials.upperWireKey)).height, closeTo(42, 0.5));
      expect(tester.getSize(find.byType(Step4Credentials)).height, closeTo(270.5, 0.5));
      final note = tester.getRect(find.byKey(Step4Credentials.closingNoteKey));
      expect(note.top - rect(tester, 'ob4-node-2').bottom, closeTo(8, 0.5));
    });

    testWidgets('the title is 12.5 semibold and the line under it mono 11, 2 below', (tester) async {
      await show(tester);
      await tester.pump(past);

      final title = tester.widget<Text>(find.text(Step4Credentials.connectionName)).style!;
      final detail = tester.widget<Text>(find.text(Step4Credentials.engine)).style!;
      expect(title.fontSize, 12.5);
      expect(title.fontWeight, FontWeight.w600);
      expect(detail.fontSize, 11);
      expect(detail.fontFamily, AppTypography.mono);
      expect(
        tester.getRect(find.text(Step4Credentials.engine)).top -
            tester.getRect(find.text(Step4Credentials.connectionName)).bottom,
        closeTo(2, 0.5),
      );
    });

    testWidgets('the rail is 26 in, the pill 10 and 12 into the wire, 18 high round a 7 inset', (tester) async {
      await show(tester);
      await tester.pump(past);

      final wire = tester.getRect(find.byKey(Step4Credentials.upperWireKey));
      final hero = tester.getRect(find.byType(Step4Credentials));
      expect(wire.left - hero.left, closeTo(26, 0.5));
      final pill = tester.getRect(find.byKey(Step4Credentials.requestTokenKey));
      expect(pill.left - wire.left, closeTo(10, 0.5));
      expect(pill.top - wire.top, closeTo(12, 0.5));
      expect(pill.height, closeTo(18, 0.5));
      expect(pill.width - tester.getRect(find.text(Step4Credentials.connectionReference)).width, closeTo(14, 0.5));
    });

    testWidgets('only Studio is lit at the end, and the key is 12 in from its trailing edge', (tester) async {
      await show(tester);
      await tester.pump(past);

      final colors = AppTheme.light().colorScheme;
      Color? border(int i) =>
          (tester.widget<Container>(find.byKey(ValueKey('ob4-node-$i'))).decoration! as BoxDecoration)
              .border
              ?.top
              .color;
      expect(border(0), colors.outlineVariant);
      expect(border(1), colors.primary);
      expect(border(2), colors.outlineVariant);
      final node = rect(tester, 'ob4-node-1');
      expect(
        node.right - tester.getRect(find.byKey(const ValueKey('ob4-key'))).center.dx,
        closeTo(21, 0.5),
        reason: '1 border + 12 padding + half of the 16',
      );
    });

    testWidgets('a ring runs out of a box when it pops, and the note is an arrow, a space and the sentence', (
      tester,
    ) async {
      await show(tester);
      await tester.pump(Step4Credentials.keyShutsAt + const Duration(milliseconds: 150));
      expect(
        tester.widget<Container>(find.byKey(const ValueKey('ob4-node-1'))).foregroundDecoration,
        isNotNull,
        reason: 'the ring is running out of Studio',
      );

      await tester.pump(past);
      for (var i = 0; i < 3; i++) {
        expect(
          tester.widget<Container>(find.byKey(ValueKey('ob4-node-$i'))).foregroundDecoration,
          isNull,
          reason: 'node $i still has a ring on it at the end: the timeline stops before the last ring has finished',
        );
      }
      final style = tester.widget<Text>(find.textContaining(l10n(tester).ob4_back)).style!;
      expect(style.fontFamily, AppTypography.mono);
      expect(style.fontSize, 11);
      expect(style.height, 1.5);
      expect(style.color, AppTheme.light().colorScheme.onPrimaryContainer);
    });
  });

  group('the screen itself', () {
    testWidgets('names all three nodes of the chain', (tester) async {
      await show(tester);
      await tester.pump(past);
      final s = l10n(tester);
      expect(find.text(s.ob4_app), findsOneWidget);
      expect(find.text(s.ob4_studio), findsOneWidget);
      expect(find.text(Step4Credentials.connectionName), findsOneWidget);
      expect(find.text(s.ob4_vault), findsOneWidget);
      expect(find.text(s.ob4_connects), findsOneWidget);
    });

    testWidgets('settles into the shut padlock and the note at once when animations are off', (tester) async {
      await show(tester, animations: false);
      await tester.pump();
      final s = l10n(tester);
      expect(drawnWidth(tester, 'ob4-key'), closeTo(18.4, 0.1));
      expect(tester.widget<Opacity>(find.byKey(Step4Credentials.closingNoteKey)).opacity, 1.0);
      expect(find.text('\u2191 ${s.ob4_back}'), findsOneWidget);
    });

    testWidgets('lays out at every ordinary text scale without overflowing', (tester) async {
      for (final scale in [1.0, 1.5, 2.0, 3.0]) {
        await show(tester, textScale: scale);
        await tester.pump(past);
      }
    });

    testWidgets('holds nothing a finger can press', (tester) async {
      await show(tester);
      await tester.pump(past);
      expect(find.byType(ButtonStyleButton), findsNothing);
      expect(find.byType(TextField), findsNothing);
      expect(find.byType(InkWell), findsNothing);
    });

    testWidgets('says the same thing in Turkish', (tester) async {
      await show(tester, locale: const Locale('tr'));
      await tester.pump(past);
      final s = l10n(tester);
      expect(find.text(s.ob4_app), findsOneWidget);
      expect(find.text(s.ob4_vault), findsOneWidget);
      expect(find.text('\u2191 ${s.ob4_back}'), findsOneWidget);
    });
  });

  /// The chassis gives the hero a box that scrolls vertically, so a screen that grows taller than the slack is
  /// absorbed; what nothing absorbs is width. At an accessibility text size the words of this screen are two and
  /// three times as long, and every one of them has to fold inside the hero's own width instead of running out of
  /// it — which is what [_drawsOutsideItsBox] measures, frame by frame, rather than trusting the drawing.
  ///
  /// The widths are the ones the chassis actually hands a step on the devices `onboarding_page_test.dart` walks:
  /// the viewport less the 48 pt leading and 24 pt trailing gutter — 318 pt on a 390 pt phone, 248 pt on a 320 pt
  /// one, 772 pt turned sideways.
  group('the screen folds inside the width it is given', () {
    const heroWidths = <double>[318, 248, 772];
    const frame = Duration(milliseconds: 100);

    for (final scale in [1.3, 2.0, 3.0]) {
      testWidgets('draws nothing outside its own box at a text scale of $scale', (tester) async {
        for (final width in heroWidths) {
          for (final locale in [const Locale('en'), const Locale('tr')]) {
            await show(tester, textScale: scale, heroWidth: width, locale: locale);
            // Every frame of the timeline, not only the last: a token is mid-wire for most of it, and a label that
            // ran out of the hero would be back inside it by the time the screen settled.
            for (var at = Duration.zero; at < past; at += frame) {
              await tester.pump(frame);
              expect(
                _drawsOutsideItsBox(tester),
                lessThanOrEqualTo(0.0001),
                reason: 'at $width pt, a text scale of $scale, ${locale.languageCode}, ${at.inMilliseconds} ms in',
              );
            }
          }
        }
      });
    }
  });
}
