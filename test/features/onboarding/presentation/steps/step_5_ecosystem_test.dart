@Tags(['widget'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/features/onboarding/presentation/steps/step_5_ecosystem.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/shared/design_system/theme/app_theme.dart';
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
  }) async {
    addTearDown(tester.view.reset);
    tester.view.physicalSize = viewport;
    tester.view.devicePixelRatio = 1.0;
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
        home: const Scaffold(
          body: SingleChildScrollView(
            child: Padding(padding: EdgeInsets.all(AppSpacing.lg), child: Step5Ecosystem()),
          ),
        ),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: disableAnimations),
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

  testWidgets('the Platform hub carries its three roles in the case the ARB writes them', (tester) async {
    final s = await pumpStep(tester, elapsed: Step5Beats.whole, locale: const Locale('tr'));

    expect(find.text(s.ob5_hub), findsOneWidget);
    for (final role in [s.ob5_role_connections, s.ob5_role_grants, s.ob5_role_audit]) {
      expect(find.text(role), findsOneWidget, reason: '$role is not on a chip');
      expect(find.text(role.toUpperCase()), findsNothing, reason: "Dart's toUpperCase turns a Turkish i into I");
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
}
