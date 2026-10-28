@Tags(['widget'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/core/testing/app_key_constants.dart';
import 'package:libredb_mobile/features/onboarding/application/onboarding_cubit.dart';
import 'package:libredb_mobile/features/onboarding/data/repositories/onboarding_seen_preferences.dart';
import 'package:libredb_mobile/features/onboarding/domain/repositories/adoption_figures_source.dart';
import 'package:libredb_mobile/features/onboarding/presentation/pages/onboarding_page.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/shared/adoption/adoption_figures.dart';
import 'package:libredb_mobile/shared/design_system/theme/app_theme.dart';

import '../../../../support/test_env.dart';

/// The accessibility floor of the first screen the app ever shows.
///
/// It is held on **every one of the four panels**, not only the first, because the flow is the one place in this app
/// where most of the screen changes under the same chrome: a tap target that is big enough on the panel a test
/// happens to open on says nothing about the three a user actually swipes to.
///
/// `textContrastGuideline` is deliberately absent for the same reason it is absent from the login screen's file:
/// under Ahem every glyph is a solid block, so what it measures is the block and not the type. The palettes' own
/// contrast is measured where the values are, in `palette_contrast_test.dart` and `semantic_contrast_test.dart`.
void main() {
  late OnboardingCubit cubit;

  setUp(() async {
    await TestEnv.onboardingUnseen();
    cubit = OnboardingCubit(store: OnboardingSeenPreferences());
    addTearDown(cubit.close);
    await cubit.restore();
  });

  Future<void> pumpIntroduction(WidgetTester tester) async {
    addTearDown(tester.view.reset);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    await tester.pumpWidget(
      RepositoryProvider<IAdoptionFiguresSource>(
        create: (_) => const _ShippedFigures(),
        child: BlocProvider<OnboardingCubit>.value(
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
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Moves to the next panel the way a user does.
  Future<void> advance(WidgetTester tester) async {
    await tester.tap(find.byKey(onboardingDoneKey));
    await tester.pumpAndSettle();
  }

  for (final (guideline, what) in [
    (androidTapTargetGuideline, 'the Android minimum of 48 pt'),
    (iOSTapTargetGuideline, 'the iOS minimum of 44 pt'),
    (labeledTapTargetGuideline, 'a label, so nothing is an unnamed target'),
  ]) {
    testWidgets('every tappable on every panel meets $what', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpIntroduction(tester);

      for (var panel = 0; panel < 4; panel++) {
        await expectLater(tester, meetsGuideline(guideline));
        if (panel < 3) await advance(tester);
      }
      handle.dispose();
    });
  }

  testWidgets('each panel says where in the flow it is, because the dots cannot say it', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpIntroduction(tester);

    for (var panel = 1; panel <= 4; panel++) {
      expect(
        find.bySemanticsLabel(RegExp('Panel $panel of 4')),
        findsOneWidget,
        reason: 'panel $panel announces its position',
      );
      if (panel < 4) await advance(tester);
    }
    handle.dispose();
  });

  testWidgets('the dots do not repeat what the panel already said', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpIntroduction(tester);

    // One node carries the position, not two: the drawn dots are excluded, so a screen reader hears it once.
    expect(find.bySemanticsLabel(RegExp('Panel 1 of 4')), findsOneWidget);
    handle.dispose();
  });
}

/// The figures the source ships, which is what every failure collapses into — the worst case the page meets.
class _ShippedFigures implements IAdoptionFiguresSource {
  const _ShippedFigures();

  @override
  Future<AdoptionFigures> read() async => AdoptionFigures.fallback;
}
