@Tags(['widget'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/core/testing/app_key_constants.dart';
import 'package:libredb_mobile/features/onboarding/application/onboarding_cubit.dart';
import 'package:libredb_mobile/features/onboarding/data/repositories/onboarding_seen_preferences.dart';
import 'package:libredb_mobile/features/onboarding/presentation/pages/onboarding_page.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/shared/design_system/theme/app_theme.dart';

import '../../../../support/test_env.dart';

/// The accessibility floor of the first screen the app ever shows.
///
/// It is held on **every one of the six screens**, not only the first, because the flow is the one place in this
/// app where most of the screen changes under the same chrome: a tap target that is big enough on the screen a
/// test happens to open on says nothing about the five a user actually reaches.
///
/// `textContrastGuideline` is deliberately absent for the same reason it is absent from the login screen's file:
/// under Ahem every glyph is a solid block, so what it measures is the block and not the type. The palettes' own
/// contrast is measured where the values are, in `palette_contrast_test.dart` and `semantic_contrast_test.dart`.
///
/// **Where in the flow this is was said by the panels and is said by the counter now.** The four panels each
/// carried a `Panel n of 4` label of their own; the six screens have one counter, drawn as `01 / 06`, and it is
/// the counter that says it in words — `ob_step_semantics`. The claim is the same one: it is said once, and the
/// drawing that repeats it is excluded.
void main() {
  late OnboardingCubit cubit;

  setUp(() async {
    await TestEnv.onboardingUnseen();
    cubit = OnboardingCubit(store: OnboardingSeenPreferences());
    addTearDown(cubit.close);
    await cubit.restore();
  });

  Future<S> pumpIntroduction(WidgetTester tester) async {
    addTearDown(tester.view.reset);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    await tester.pumpWidget(
      BlocProvider<OnboardingCubit>.value(
        value: cubit,
        child: MaterialApp(
          theme: AppTheme.light(),
          localizationsDelegates: const [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.delegate.supportedLocales,
          locale: const Locale('en'),
          home: const OnboardingPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return S.of(tester.element(find.byType(OnboardingPage)));
  }

  /// Moves to the next screen the way a user does: the deck is turned by dragging it, and the primary control is
  /// gone from every screen but the last.
  Future<void> advance(WidgetTester tester) async {
    await tester.fling(find.byKey(onboardingHeadlineKey), const Offset(-300, 0), 800);
    await tester.pumpAndSettle();
  }

  for (final (guideline, what) in [
    (androidTapTargetGuideline, 'the Android minimum of 48 pt'),
    (iOSTapTargetGuideline, 'the iOS minimum of 44 pt'),
    (labeledTapTargetGuideline, 'a label, so nothing is an unnamed target'),
  ]) {
    testWidgets('every tappable on every screen meets $what', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpIntroduction(tester);

      for (var step = 0; step < onboardingStepCount; step++) {
        await expectLater(tester, meetsGuideline(guideline));
        if (step < onboardingStepCount - 1) await advance(tester);
      }
      handle.dispose();
    });
  }

  testWidgets('each screen says where in the flow it is, because the drawn rule cannot say it', (tester) async {
    final handle = tester.ensureSemantics();
    final l10n = await pumpIntroduction(tester);

    for (var step = 1; step <= onboardingStepCount; step++) {
      expect(
        find.bySemanticsLabel(l10n.ob_step_semantics(step, onboardingStepCount)),
        findsOneWidget,
        reason: 'screen $step announces its position',
      );
      if (step < onboardingStepCount) await advance(tester);
    }
    handle.dispose();
  });

  testWidgets('the progress rule does not repeat what the counter already said', (tester) async {
    final handle = tester.ensureSemantics();
    final l10n = await pumpIntroduction(tester);

    // One node carries the position, not two: the rule and the padded digits are both excluded, so a screen reader
    // hears "Step 1 of 6" once and never "01 / 06".
    expect(find.bySemanticsLabel(l10n.ob_step_semantics(1, onboardingStepCount)), findsOneWidget);
    expect(find.bySemanticsLabel(l10n.ob_step(1, onboardingStepCount)), findsNothing);
    handle.dispose();
  });
}
