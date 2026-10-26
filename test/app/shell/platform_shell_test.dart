@Tags(['widget'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:libredb_mobile/app/app.dart';
import 'package:libredb_mobile/app/connectivity/connectivity_cubit.dart';
import 'package:libredb_mobile/app/di/mock_sign_in_dependencies.dart';
import 'package:libredb_mobile/app/router/app_routes_constants.dart';
import 'package:libredb_mobile/app/session/platform_account_refusal_cubit.dart';
import 'package:libredb_mobile/app/shell/platform_shell.dart';
import 'package:libredb_mobile/features/platform_home/presentation/pages/platform_home_page.dart';
import 'package:libredb_mobile/features/platform_status/application/platform_status_bloc.dart';
import 'package:libredb_mobile/features/platform_status/application/platform_status_state.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/features/auth/application/platform_identity_cubit.dart';
import 'package:libredb_mobile/features/auth/application/sign_out_bloc.dart';
import 'package:libredb_mobile/features/auth/application/studio_identity_cubit.dart';
import 'package:libredb_mobile/features/connections/application/connection_policy_cubit.dart';
import 'package:libredb_mobile/features/settings/presentation/pages/settings_screen.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/shared/models/platform_identity.dart';
import 'package:libredb_mobile/shared/models/session_target.dart';
import 'package:libredb_mobile/shared/user_data/signed_in_account_scope.dart';
import 'package:mocktail/mocktail.dart';

import '../../mocks/mock_classes.dart';
import '../../support/test_env.dart';

const _identity = PlatformIdentity(
  id: 'cm0platformadmin0000000001',
  email: 'platform.admin@example.org',
  name: 'Platform Admin',
  roles: ['PLATFORM_ADMIN'],
  permissions: [],
  tenant: PlatformTenant(id: 'cm0tenant00000000000000001', name: 'Example Org', slug: 'example-org'),
);

void main() {
  group('PlatformShell with doubles', () {
    late MockStudioIdentityCubit studioIdentity;
    late MockConnectionPolicyCubit policy;
    late MockPlatformIdentityCubit platformIdentity;
    late MockPlatformAccountRefusalCubit refusal;
    late MockConnectivityCubit connectivity;
    late MockSignOutBloc signOut;
    late MockPlatformStatusBloc platformStatus;

    setUp(() {
      platformStatus = MockPlatformStatusBloc();
      when(() => platformStatus.state).thenReturn(const PlatformReachable());
      studioIdentity = MockStudioIdentityCubit();
      policy = MockConnectionPolicyCubit();
      platformIdentity = MockPlatformIdentityCubit();
      refusal = MockPlatformAccountRefusalCubit();
      connectivity = MockConnectivityCubit();
      signOut = MockSignOutBloc();
      when(() => studioIdentity.state).thenReturn(const StudioIdentityInitial());
      when(() => policy.state).thenReturn(const ConnectionPolicyInitial());
      when(() => studioIdentity.load()).thenAnswer((_) async {});
      when(() => policy.load()).thenAnswer((_) async {});
      when(() => platformIdentity.load()).thenAnswer((_) async {});
      when(() => refusal.state).thenReturn(const PlatformAccountAccepted());
      when(() => connectivity.state).thenReturn(const ConnectivityState.initial());
      when(() => signOut.state).thenReturn(const SignOutInitial());
    });

    Future<void> pumpShell(WidgetTester tester) async {
      final router = GoRouter(
        initialLocation: ApplicationRoutesConstants.platformHome,
        routes: [
          ShellRoute(
            builder: (context, state, child) => PlatformShell(state: state, child: child),
            routes: [
              GoRoute(
                path: ApplicationRoutesConstants.platformHome,
                builder: (context, state) => const PlatformHomePage(),
              ),
            ],
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider<StudioIdentityCubit>.value(value: studioIdentity),
            BlocProvider<ConnectionPolicyCubit>.value(value: policy),
            BlocProvider<PlatformIdentityCubit>.value(value: platformIdentity),
            BlocProvider<PlatformAccountRefusalCubit>.value(value: refusal),
            BlocProvider<ConnectivityCubit>.value(value: connectivity),
            BlocProvider<SignOutBloc>.value(value: signOut),
            BlocProvider<PlatformStatusBloc>.value(value: platformStatus),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            locale: const Locale('en'),
            localizationsDelegates: const [
              S.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: S.delegate.supportedLocales,
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('loads the Platform identity once when it opens on a restored session', (tester) async {
      when(() => platformIdentity.state).thenReturn(const PlatformIdentityInitial());

      await pumpShell(tester);
      await tester.pump();

      verify(() => platformIdentity.load()).called(1);
    });

    testWidgets('asks nothing again when the sign-in has already loaded the identity', (tester) async {
      when(() => platformIdentity.state).thenReturn(const PlatformIdentityLoaded(_identity));

      await pumpShell(tester);

      verifyNever(() => platformIdentity.load());
      expect(find.text('Platform Admin'), findsOneWidget);
      expect(find.text('Example Org'), findsOneWidget);
    });

    testWidgets('never asks Studio who the user is or what it allows', (tester) async {
      when(() => platformIdentity.state).thenReturn(const PlatformIdentityInitial());

      await pumpShell(tester);
      await tester.pump();

      verifyNever(() => studioIdentity.load());
      verifyNever(() => policy.load());
    });

    testWidgets('the home shows the email when Platform has no name', (tester) async {
      when(() => platformIdentity.state).thenReturn(
        const PlatformIdentityLoaded(
          PlatformIdentity(
            id: 'cm0platformadmin0000000001',
            email: 'platform.admin@example.org',
            roles: [],
            permissions: [],
            tenant: PlatformTenant(id: 't', name: 'Example Org', slug: 'example-org'),
          ),
        ),
      );

      await pumpShell(tester);

      expect(find.text('platform.admin@example.org'), findsOneWidget);
    });

    testWidgets('the home shows a failed identity with a Retry that asks Platform again', (tester) async {
      when(() => platformIdentity.state).thenReturn(const PlatformIdentityFailure(AppErrorCode.platformInternalError));

      await pumpShell(tester);
      await tester.tap(find.widgetWithText(OutlinedButton, 'Retry'));

      verify(() => platformIdentity.load()).called(1);
    });
  });

  group('PlatformShell in the app', () {
    Future<void> pumpPlatformApp(WidgetTester tester) async {
      addTearDown(tester.view.reset);
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1.0;
      TestEnv.authenticate(target: SessionTarget.platform);
      await tester.pumpWidget(App(dependencies: MockSignInDependencies(), language: 'en'));
      await tester.pumpAndSettle();
      // The mock answers the identity after its latency.
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
    }

    GoRouter routerOf(WidgetTester tester) =>
        tester.widget<MaterialApp>(find.byType(MaterialApp)).routerConfig! as GoRouter;

    testWidgets('the settings page renders without Remove my data', (tester) async {
      await pumpPlatformApp(tester);

      routerOf(tester).go(ApplicationRoutesConstants.platformSettings);
      await tester.pumpAndSettle();

      expect(find.byType(SettingsScreen), findsOneWidget);
      expect(find.text('Remove my data'), findsNothing);
      expect(find.text('Example Org'), findsNothing, reason: 'the settings page names no tenant');
    });

    testWidgets('reloadStoredData of its account scope throws, since Platform mode keeps no account data', (
      tester,
    ) async {
      await pumpPlatformApp(tester);
      routerOf(tester).go(ApplicationRoutesConstants.platformSettings);
      await tester.pumpAndSettle();

      final scope = SignedInAccountScope.read(tester.element(find.byType(SettingsScreen)));

      expect(scope.subject, isNull);
      expect(scope.reloadStoredData, throwsStateError);
    });

    testWidgets('the home shows the admin and the tenant from the mock identity', (tester) async {
      await pumpPlatformApp(tester);

      expect(find.byType(PlatformShell), findsOneWidget);
      expect(find.text('Platform Admin'), findsWidgets);
      expect(find.text('Example Org'), findsOneWidget);
    });
  });
}
