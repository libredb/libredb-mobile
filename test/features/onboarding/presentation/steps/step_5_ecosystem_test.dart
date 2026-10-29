@Tags(['widget'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/features/onboarding/presentation/steps/step_5_ecosystem.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/shared/design_system/theme/app_theme.dart';
import 'package:libredb_mobile/shared/design_system/tokens/app_typography.dart';
import 'package:libredb_mobile/shared/design_system/tokens/tokens.dart';

/// The fifth screen of the introduction: the ecosystem the person has been standing inside for four screens.
///
/// What is asserted here is the **claim the headline makes**, not the picture. "Studios connect to Platform" is a
/// direction, and a diagram whose lines grow the other way says the opposite of its own caption — an audit caught
/// exactly that in the prototype this widget is built from, where the connectors were drawn downward while the
/// sparks ran up them. So the order of the beats is measured, frame by frame, off the boxes that paint the lines:
///
/// * the legs from the databases reach the Studios **before** anything is drawn toward Platform;
/// * the branch — the rail under Platform and the stem up to it — is drawn **before** the twigs that drop to each
///   Studio;
/// * only `orders-prod`'s path lights, because the person ran their statement on that one and on no other.
///
/// The probe instants come from [Step5Beats], so the schedule and the test cannot drift apart; each one is the
/// midpoint between two beats, which is a frame at which exactly one of the two claims may be true.
///
/// The mode switch is measured against the app's own words rather than the prototype's: `profile_mode_platform` is
/// "Platform yöneticisi", and the note under the pills has to say that the first switch takes an admin seat of the
/// licence (`docs/platform.md`), because the prototype promised every new user a mode that is admin-only.
void main() {
  /// A frame at [elapsed] of the step's timeline, pumped from the first frame so every beat before it has run.
  Future<S> pumpStep(
    WidgetTester tester, {
    Duration elapsed = Duration.zero,
    Locale locale = const Locale('en'),
    bool disableAnimations = false,
    Size viewport = const Size(390, 844),
    double textScale = 1.0,
    double? hero,
  }) async {
    addTearDown(tester.view.reset);
    tester.view.physicalSize = viewport;
    tester.view.devicePixelRatio = 1.0;
    // [hero] draws the step in the box the chassis really gives it — 318 points wide on a 390 phone, scrolling
    // itself vertically — rather than across the whole test surface, because the only axis a hero cannot absorb is
    // the horizontal one.
    final body = hero == null
        ? const SingleChildScrollView(
            child: Padding(padding: EdgeInsets.all(AppSpacing.lg), child: Step5Ecosystem()),
          )
        : Center(
            child: SizedBox(
              width: hero,
              height: 405,
              child: const SingleChildScrollView(child: Step5Ecosystem()),
            ),
          );
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        localizationsDelegates: const [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.delegate.supportedLocales,
        locale: locale,
        home: Scaffold(body: body),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(disableAnimations: disableAnimations, textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
      ),
    );
    if (elapsed > Duration.zero) await tester.pump(elapsed);
    return S.of(tester.element(find.byType(Step5Ecosystem)));
  }

  /// A frame between two beats: the one instant at which the earlier claim must hold and the later must not.
  Duration midway(Duration earlier, Duration later) => earlier + (later - earlier) ~/ 2;

  /// The painted height of the box behind [key], which is what "this line has been drawn" means for a connector that
  /// grows out of nothing.
  double drawnHeight(WidgetTester tester, String key) => tester.getSize(find.byKey(ValueKey(key))).height;

  double drawnWidth(WidgetTester tester, String key) => tester.getSize(find.byKey(ValueKey(key))).width;

  /// The border colour of a keyed tier box, the only thing that says whether its path lit.
  Color borderOf(WidgetTester tester, String key) {
    final decoration = tester.widget<Container>(find.byKey(ValueKey(key))).decoration! as BoxDecoration;
    return decoration.border!.top.color;
  }

  group('the connectors grow the way the headline claims', () {
    testWidgets('the legs from the databases reach the Studios before anything is drawn toward Platform', (
      tester,
    ) async {
      await pumpStep(tester, elapsed: midway(Step5Beats.lit, Step5Beats.branch));

      expect(drawnHeight(tester, 'ob5-leg-0'), greaterThan(0), reason: 'the first database has not reached its Studio');
      expect(drawnHeight(tester, 'ob5-leg-2'), greaterThan(0), reason: 'the last database has not reached its Studio');
      expect(drawnHeight(tester, 'ob5-stem'), 0, reason: 'the stem to Platform is drawn before the legs are finished');
      expect(drawnWidth(tester, 'ob5-rail'), 0, reason: 'the rail under Platform is drawn before the legs finish');
    });

    testWidgets('the branch is drawn before its twigs', (tester) async {
      await pumpStep(tester, elapsed: midway(Step5Beats.branch, Step5Beats.twigs));

      expect(drawnWidth(tester, 'ob5-rail'), greaterThan(0), reason: 'the rail has not been drawn');
      expect(drawnHeight(tester, 'ob5-stem'), greaterThan(0), reason: 'the stem has not been drawn');
      expect(drawnHeight(tester, 'ob5-twig-0'), 0, reason: 'a twig is drawn before the branch it hangs from');
    });

    testWidgets('every connector is drawn by the end', (tester) async {
      await pumpStep(tester, elapsed: Step5Beats.whole);

      for (final key in ['ob5-leg-0', 'ob5-leg-1', 'ob5-leg-2', 'ob5-twig-0', 'ob5-twig-1', 'ob5-twig-2', 'ob5-stem']) {
        expect(drawnHeight(tester, key), greaterThan(0), reason: '$key was never drawn');
      }
      expect(drawnWidth(tester, 'ob5-rail'), greaterThan(0), reason: 'the rail was never drawn');
    });
  });

  testWidgets("only orders-prod's path lights; the other two arrive quietly", (tester) async {
    await pumpStep(tester, elapsed: Step5Beats.whole);
    final scheme = AppTheme.light().colorScheme;

    expect(borderOf(tester, 'ob5-database-0'), scheme.primary, reason: 'orders-prod did not light');
    expect(borderOf(tester, 'ob5-studio-0'), scheme.primary, reason: 'studio-eu, which holds it, did not light');
    expect(borderOf(tester, 'ob5-database-1'), scheme.outline, reason: 'a database nobody ran on lit');
    expect(borderOf(tester, 'ob5-studio-1'), scheme.outline, reason: 'a Studio nobody reached lit');
    expect(borderOf(tester, 'ob5-studio-2'), scheme.outline, reason: 'a Studio nobody reached lit');
  });

  testWidgets('the mode switch names the admin mode and says it is the same session', (tester) async {
    final s = await pumpStep(tester, elapsed: Step5Beats.whole, locale: const Locale('tr'));
    final scheme = AppTheme.light().colorScheme;

    expect(find.text(s.profile_mode_studio), findsOneWidget);
    expect(find.text(s.profile_mode_platform), findsOneWidget, reason: 'the admin mode is not named with the app word');
    expect(s.profile_mode_platform, 'Platform yöneticisi');
    expect(find.text(s.ob5_mode_note), findsOneWidget, reason: 'nothing says the switch takes an admin seat');
    expect(borderOf(tester, 'ob5-mode-studio'), scheme.primary);
    expect(
      borderOf(tester, 'ob5-mode-platform'),
      scheme.outline,
      reason: 'the deck shows the person in Studio mode; a lit Platform pill promises a seat they may not hold',
    );
  });

  testWidgets('the Platform hub carries its three roles in capitals, by the rules of the language', (tester) async {
    final s = await pumpStep(tester, elapsed: Step5Beats.whole, locale: const Locale('tr'));

    expect(find.text(s.ob5_hub), findsOneWidget);
    // `.role{text-transform:uppercase}`, which a browser applies by the document's language: a Turkish `i` becomes
    // `İ`, and Dart's own `toUpperCase` would write `I`.
    for (final role in ['BAĞLANTILAR', 'YETKİLER', 'DENETİM KAYDI']) {
      expect(find.text(role), findsOneWidget, reason: '$role is not on a chip');
    }
  });

  testWidgets('the person is on the map, with the identity that knows them once', (tester) async {
    final s = await pumpStep(tester, elapsed: Step5Beats.whole);

    expect(find.text(s.ob5_you), findsOneWidget, reason: 'a map that does not show where the viewer stands');
    expect(find.text(s.ob5_keycloak), findsOneWidget);
    expect(find.text(s.ob5_keycloak_note), findsOneWidget);
  });

  testWidgets('nothing in the step answers a finger', (tester) async {
    await pumpStep(tester, elapsed: Step5Beats.whole);

    expect(find.descendant(of: find.byType(Step5Ecosystem), matching: find.byType(InkWell)), findsNothing);
    expect(find.descendant(of: find.byType(Step5Ecosystem), matching: find.byType(GestureDetector)), findsNothing);
  });

  testWidgets('with animations off the ecosystem is whole on the first frame', (tester) async {
    await pumpStep(tester, disableAnimations: true);
    final scheme = AppTheme.light().colorScheme;

    expect(drawnHeight(tester, 'ob5-stem'), greaterThan(0));
    expect(drawnWidth(tester, 'ob5-rail'), greaterThan(0));
    expect(drawnHeight(tester, 'ob5-twig-2'), greaterThan(0));
    expect(drawnHeight(tester, 'ob5-leg-2'), greaterThan(0));
    expect(borderOf(tester, 'ob5-database-0'), scheme.primary);
    expect(tester.widget<Opacity>(find.byKey(const ValueKey('ob5-modes'))).opacity, 1.0);
  });

  /// The geometry of the prototype's fifth screen, read in headless Chrome at 390x844 and a device scale of 2 (Turkish,
  /// light; the same in English and dark). Keycloak is a 45 high box (`padding:7px 11px` round a 14.5 name over a
  /// 14.5 mono line), the phone a 31.5 high bar and Platform a 68 high one, 7 apart; the fan is 34 high — a stem of 13,
  /// a rail at 13 and three drops of 21 at the centres of the columns — over three Studios of 46.5 in columns with a
  /// 6 gap, 15 of legs, three databases of 26.5, the mode pills 9 under them, 28 high, and the note 5 under those.
  ///
  /// **The font trap:** every height is a box round lines whose heights are multipliers of their sizes, which Ahem lays
  /// out as the product font does, and every x is an inset from an edge or a column. The hero is 700 wide so that no
  /// word wraps in Ahem's full-em glyphs.
  group('the screen is the prototype\'s', () {
    Rect rect(WidgetTester tester, String key) => tester.getRect(find.byKey(ValueKey(key)));

    Future<void> whole(WidgetTester tester) async {
      await pumpStep(tester, elapsed: Step5Beats.whole, viewport: const Size(800, 900), hero: 700);
    }

    testWidgets('Keycloak is 45, the phone 31.5 and Platform 68, 7 apart', (tester) async {
      await whole(tester);

      expect(rect(tester, 'ob5-kc').height, closeTo(45, 0.6));
      expect(rect(tester, 'ob5-you').height, closeTo(31.5, 0.6));
      expect(rect(tester, 'ob5-hub').height, closeTo(68, 0.6));
      expect(rect(tester, 'ob5-you').top - rect(tester, 'ob5-kc').bottom, closeTo(7, 0.6));
      expect(rect(tester, 'ob5-hub').top - rect(tester, 'ob5-you').bottom, closeTo(7, 0.6));
    });

    testWidgets('the three drops hang from the rail down into the tops of the Studios, at the column centres', (
      tester,
    ) async {
      await whole(tester);

      final hub = rect(tester, 'ob5-hub');
      final column = (700 - 12) / 3;
      final rail = rect(tester, 'ob5-rail');
      expect(rail.top - hub.bottom, closeTo(13, 0.6));
      expect(rail.left - hub.left, closeTo(column / 2, 0.6), reason: 'the rail starts at the first column\'s centre');
      expect(hub.right - rail.right, closeTo(column / 2, 0.6));
      final stem = rect(tester, 'ob5-stem');
      expect(stem.height, closeTo(13, 0.6));
      expect(stem.center.dx, closeTo(hub.center.dx, 0.6));
      for (var i = 0; i < 3; i++) {
        final twig = rect(tester, 'ob5-twig-$i');
        final studio = rect(tester, 'ob5-studio-$i');
        expect(twig.height, closeTo(21, 0.6), reason: 'twig $i');
        expect(twig.width, 1);
        expect(twig.center.dx, closeTo(studio.center.dx, 0.6), reason: 'twig $i is not over its Studio');
        expect(twig.top, closeTo(rail.top, 0.6), reason: 'twig $i hangs from the rail');
        expect(twig.bottom, closeTo(studio.top, 0.6), reason: 'twig $i does not reach the top of its Studio');
      }
    });

    testWidgets('the Studios are 46.5 in columns with 6 between, the legs 15 and the databases 26.5', (tester) async {
      await whole(tester);

      final column = (700 - 12) / 3;
      for (var i = 0; i < 3; i++) {
        final studio = rect(tester, 'ob5-studio-$i');
        final leg = rect(tester, 'ob5-leg-$i');
        final database = rect(tester, 'ob5-database-$i');
        expect(studio.width, closeTo(column, 0.6));
        expect(studio.height, closeTo(46.5, 0.6), reason: 'Studio $i');
        expect(leg.height, closeTo(15, 0.6));
        expect(leg.top, closeTo(studio.bottom, 0.6));
        expect(leg.center.dx, closeTo(studio.center.dx, 0.6));
        expect(database.height, closeTo(26.5, 0.6), reason: 'database $i');
        expect(database.top, closeTo(leg.bottom, 0.6));
      }
      expect(rect(tester, 'ob5-studio-1').left - rect(tester, 'ob5-studio-0').right, closeTo(6, 0.6));
    });

    testWidgets('the mode pills are 28 high, 9 under the databases, and the note is 5 under them', (tester) async {
      await whole(tester);

      final database = rect(tester, 'ob5-database-0');
      final studio = rect(tester, 'ob5-mode-studio');
      final platform = rect(tester, 'ob5-mode-platform');
      expect(studio.top - database.bottom, closeTo(9, 0.6));
      expect(studio.height, closeTo(28, 0.6));
      expect(platform.left - studio.right, closeTo(6, 0.6));
      final note = tester.getRect(find.byKey(const ValueKey('ob5-note')));
      expect(note.top - studio.bottom, closeTo(5, 0.6));
      final style = tester.widget<Text>(find.byKey(const ValueKey('ob5-note'))).style!;
      expect(style.fontFamily, AppTypography.mono);
      expect(style.fontSize, 11);
      expect(style.height, 1.5);
      expect(style.letterSpacing, 0);
    });

    testWidgets('the footnote is there, centred, in both languages', (tester) async {
      for (final locale in [const Locale('en'), const Locale('tr')]) {
        final s = await pumpStep(
          tester,
          elapsed: Step5Beats.whole,
          viewport: const Size(800, 900),
          hero: 700,
          locale: locale,
        );
        expect(find.text(s.ob5_mode_note), findsOneWidget);
        expect(tester.widget<Text>(find.byKey(const ValueKey('ob5-note'))).textAlign, TextAlign.center);
      }
    });
  });

  group('the ecosystem survives the text size the phone is set to', () {
    /// The hero on a 390 phone, and the one a 320 phone leaves: the two widths the chassis measures the step at.
    ///
    /// Vertical growth is the hero's own problem — it scrolls — so what is asserted is that **no row of the step is
    /// wider than the hero it is drawn in**. An accessibility text size is a real Android setting, not a hypothesis:
    /// at 3.0 in Turkish the identity row was 363 points wider than its box and drew the overflow stripe across the
    /// top of the diagram.
    for (final (name, hero) in [('a 390 phone', 318.0), ('a 320 phone', 248.0)]) {
      for (final scale in [1.0, 1.3, 2.0, 3.0]) {
        for (final locale in [const Locale('en'), const Locale('tr')]) {
          testWidgets('nothing overflows the hero of $name at a text scale of $scale in ${locale.languageCode}', (
            tester,
          ) async {
            await pumpStep(tester, elapsed: Step5Beats.whole, locale: locale, hero: hero, textScale: scale);
            final step = tester.getRect(find.byType(Step5Ecosystem));

            // Measured off the boxes themselves rather than read off an overflow stripe: a layout that draws past
            // its parent without a flex in it says nothing at all, and this step is drawn with boxes of its own.
            for (final element
                in find.descendant(of: find.byType(Step5Ecosystem), matching: find.byType(Text)).evaluate()) {
              final box = element.renderObject! as RenderBox;
              final rect = box.localToGlobal(Offset.zero) & box.size;
              final word = (element.widget as Text).data;
              expect(rect.left, greaterThanOrEqualTo(step.left - 0.01), reason: '"$word" starts before the hero');
              expect(rect.right, lessThanOrEqualTo(step.right + 0.01), reason: '"$word" runs past the hero');
            }
            expect(tester.takeException(), isNull);
          });
        }
      }
    }

    /// The shape the prototype draws: the identity's name over its note, both against the left edge of the box. It used
    /// to be a name at one edge and a note at the other on one line; the prototype's `.kc` stacks them, and stacking
    /// them is also what holds at an accessibility text size, so the measuring render object it needed is gone.
    testWidgets('the identity stacks its name over its note, both on the left edge', (tester) async {
      final s = await pumpStep(
        tester,
        elapsed: Step5Beats.whole,
        locale: const Locale('tr'),
        viewport: const Size(800, 844),
        hero: 600,
      );
      final step = tester.getRect(find.byType(Step5Ecosystem));
      final name = tester.getRect(find.text(s.ob5_keycloak));
      final note = tester.getRect(find.text(s.ob5_keycloak_note));

      expect(name.left, closeTo(step.left + 12, 0.01), reason: '1 border + 11 padding');
      expect(note.left, closeTo(name.left, 0.01), reason: 'the note is under the name, not at the other edge');
      expect(note.top, greaterThanOrEqualTo(name.bottom - 0.01));
    });
  });
}
