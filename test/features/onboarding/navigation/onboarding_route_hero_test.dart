@Tags(['widget'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:libredb_mobile/app/router/app_routes_constants.dart';
import 'package:libredb_mobile/core/testing/app_key_constants.dart';
import 'package:libredb_mobile/features/onboarding/application/onboarding_cubit.dart';
import 'package:libredb_mobile/features/onboarding/data/repositories/onboarding_seen_preferences.dart';
import 'package:libredb_mobile/features/onboarding/navigation/onboarding_routes.dart';
import 'package:libredb_mobile/features/onboarding/presentation/pages/onboarding_page.dart';
import 'package:libredb_mobile/features/onboarding/presentation/steps/onboarding_steps.dart';
import 'package:libredb_mobile/features/onboarding/presentation/steps/step_1_connections.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/shared/design_system/theme/app_theme.dart';

import '../../../support/test_env.dart';

/// The one seam the chassis and the six steps meet across: the route hands [onboardingStepHero] to the page.
///
/// Both halves were written on branches that could not see each other — the chassis builds and passes its own tests
/// with `heroBuilder` left null, and the six steps build and pass theirs with nobody showing them. Nothing in either
/// half fails when the route forgets the line that joins them, which is exactly why this test exists here.
void main() {
  late OnboardingCubit cubit;

  setUp(() async {
    await TestEnv.onboardingUnseen();
    cubit = OnboardingCubit(store: OnboardingSeenPreferences());
    addTearDown(cubit.close);
    await cubit.restore();
  });

  Future<void> pumpRoute(WidgetTester tester) async {
    addTearDown(tester.view.reset);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    final router = GoRouter(
      initialLocation: ApplicationRoutesConstants.welcome,
      routes: OnboardingFeatureRoutes.routes,
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      BlocProvider<OnboardingCubit>.value(
        value: cubit,
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          localizationsDelegates: const [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.delegate.supportedLocales,
          locale: const Locale('en'),
          routerConfig: router,
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('the introduction route shows the first step, so the chassis is not an empty frame', (tester) async {
    await pumpRoute(tester);

    expect(find.byType(OnboardingPage), findsOneWidget);
    expect(find.byType(Step1Connections), findsOneWidget);
  });

  testWidgets('the route hands the page the hero of all six steps, not one of them', (tester) async {
    await pumpRoute(tester);

    final page = tester.widget<OnboardingPage>(find.byType(OnboardingPage));
    expect(page.heroBuilder, same(onboardingStepHero));
  });

  /// The text the counter is showing, so a tap that misses cannot pass for a tap that advanced.
  String counter(WidgetTester tester) => tester.widget<Text>(find.byKey(onboardingCounterKey)).data!;

  testWidgets('every one of the six steps lays out inside the chassis, not just the first', (tester) async {
    await pumpRoute(tester);

    // The chassis measures its own height with an `IntrinsicHeight` so the hero can absorb the slack, and a step
    // that answers no intrinsic question takes the whole page down with it. Each half passed its own tests without
    // ever meeting the other, so the only place that can catch it is a walk through all six with the real heroes.
    for (var step = 1; step <= 6; step++) {
      expect(counter(tester), '0$step / 06', reason: 'the walk is not on step $step');
      expect(tester.takeException(), isNull, reason: 'step $step did not lay out inside the chassis');
      expect(find.byKey(onboardingProgressKey), findsOneWidget, reason: 'the frame is gone at step $step');
      if (step < 6) {
        await tester.ensureVisible(find.byKey(onboardingDoneKey));
        await tester.pump();
        await tester.ensureVisible(find.byKey(onboardingHeadlineKey));
        await tester.pump();
        await tester.fling(find.byKey(onboardingHeadlineKey), const Offset(-300, 0), 800);
        await tester.pump();
        await tester.pump(const Duration(seconds: 2));
      }
    }
  });

  /// The geometry the approved prototype holds on every one of its six screens, measured off it at 390x844 in both
  /// themes and both languages: the controls are pinned to `772..820` in all 24 measurements, the content runs from
  /// x=48 to x=366, and nothing scrolls. The hero takes whatever is left and yields to the words rather than
  /// pushing them — `.hero{flex:1 1 auto;min-height:0}` in the prototype's own stylesheet.
  ///
  /// Steps 2 and 3 already land on 772..820, which is what makes the other four a defect rather than a redesign:
  /// the frame can hold the line, and a hero taller than the slack is what breaks it.
  testWidgets('the controls stay where the prototype pins them on all six screens', (tester) async {
    await pumpRoute(tester);

    final offenders = <String>[];
    for (var step = 1; step <= 6; step++) {
      final acts = tester.getRect(find.byKey(onboardingDoneKey));
      final scroll = tester.widget<Scrollable>(find.byType(Scrollable).first).controller;
      final scrolls = (scroll?.position.maxScrollExtent ?? 0) > 0.5;
      if ((acts.top - 772).abs() > 0.5 || (acts.bottom - 820).abs() > 0.5 || scrolls) {
        offenders.add(
          'step $step: controls ${acts.top.toStringAsFixed(1)}..${acts.bottom.toStringAsFixed(1)} '
          '(prototype 772.0..820.0)${scrolls ? ', and the page scrolls' : ''}',
        );
      }
      if (step < 6) {
        await tester.ensureVisible(find.byKey(onboardingDoneKey));
        await tester.pump();
        await tester.ensureVisible(find.byKey(onboardingHeadlineKey));
        await tester.pump();
        await tester.fling(find.byKey(onboardingHeadlineKey), const Offset(-300, 0), 800);
        await tester.pump();
        await tester.pump(const Duration(seconds: 2));
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });
}
