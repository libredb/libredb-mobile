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
import 'package:libredb_mobile/features/onboarding/application/onboarding_state.dart';
import 'package:libredb_mobile/features/onboarding/data/repositories/onboarding_seen_preferences.dart';
import 'package:libredb_mobile/features/onboarding/navigation/onboarding_routes.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/infrastructure/storage/local_storage.dart';
import 'package:libredb_mobile/shared/design_system/theme/app_theme.dart';

import '../../../../support/test_env.dart';

/// The page the introduction's route builds, away from the app's own router.
///
/// What is settled here is the way it leaves, because the router depends on it and the body does not: both controls
/// remember that the introduction has been shown, and both hand the pending location to the login page. The four
/// panels replace the body in the flow's own step and should not have to re-establish any of this.
void main() {
  late OnboardingCubit cubit;

  setUp(() async {
    await TestEnv.onboardingUnseen();
    cubit = OnboardingCubit(store: OnboardingSeenPreferences());
    addTearDown(cubit.close);
    await cubit.restore();
  });

  Future<bool> isRemembered() async => await AppLocalStorage().read(StorageKeys.onboardingSeen.key) != null;

  Future<String> pumpWelcome(WidgetTester tester, {String? returnUrl}) async {
    final initial = returnUrl == null
        ? ApplicationRoutesConstants.welcome
        : '${ApplicationRoutesConstants.welcome}?returnUrl=${Uri.encodeQueryComponent(returnUrl)}';
    final router = GoRouter(
      initialLocation: initial,
      routes: [
        ...OnboardingFeatureRoutes.routes,
        GoRoute(
          path: ApplicationRoutesConstants.login,
          builder: (context, state) => const Scaffold(body: Text('the login page')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      BlocProvider<OnboardingCubit>.value(
        value: cubit,
        child: MaterialApp.router(
          theme: AppTheme.light(),
          locale: const Locale('en'),
          localizationsDelegates: const [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.delegate.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return router.state.uri.toString();
  }

  test('the flag starts unset, so each test below meets a first run', () async {
    expect(await isRemembered(), isFalse);
    expect(cubit.state, const OnboardingRequired());
  });

  for (final (name, key) in <(String, Key)>[('the final control', onboardingDoneKey), ('Skip', onboardingSkipKey)]) {
    testWidgets('$name remembers that the introduction has been shown', (tester) async {
      await pumpWelcome(tester);

      await tester.tap(find.byKey(key));
      await tester.pumpAndSettle();

      expect(cubit.state, const OnboardingSeen());
      expect(await isRemembered(), isTrue, reason: 'the next launch would show the introduction again');
    });

    testWidgets('$name opens the login page', (tester) async {
      await pumpWelcome(tester);

      await tester.tap(find.byKey(key));
      await tester.pumpAndSettle();

      expect(find.text('the login page'), findsOneWidget);
    });

    testWidgets('$name hands the pending location to the login page', (tester) async {
      await pumpWelcome(tester, returnUrl: ApplicationRoutesConstants.settings);

      await tester.tap(find.byKey(key));
      await tester.pumpAndSettle();

      final pending = Uri.encodeQueryComponent(ApplicationRoutesConstants.settings);
      expect(find.text('the login page'), findsOneWidget);
      expect(tester.widget<MaterialApp>(find.byType(MaterialApp)), isNotNull);
      expect(
        (tester.widget<MaterialApp>(find.byType(MaterialApp)).routerConfig! as GoRouter).state.uri.toString(),
        '${ApplicationRoutesConstants.login}?returnUrl=$pending',
      );
    });
  }

  testWidgets('without a pending location it opens the login page with nothing attached', (tester) async {
    await pumpWelcome(tester);

    await tester.tap(find.byKey(onboardingDoneKey));
    await tester.pumpAndSettle();

    expect(
      (tester.widget<MaterialApp>(find.byType(MaterialApp)).routerConfig! as GoRouter).state.uri.toString(),
      ApplicationRoutesConstants.login,
    );
  });
}
