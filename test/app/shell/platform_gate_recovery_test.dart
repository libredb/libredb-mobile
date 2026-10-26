@Tags(['widget'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:libredb_mobile/app/connectivity/connectivity_cubit.dart';
import 'package:libredb_mobile/app/router/app_routes_constants.dart';
import 'package:libredb_mobile/app/session/platform_account_refusal_cubit.dart';
import 'package:libredb_mobile/app/shell/platform_shell.dart';
import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/auth/application/platform_identity_cubit.dart';
import 'package:libredb_mobile/features/auth/application/sign_out_bloc.dart';
import 'package:libredb_mobile/features/auth/application/studio_identity_cubit.dart';
import 'package:libredb_mobile/features/connections/application/connection_policy_cubit.dart';
import 'package:libredb_mobile/features/platform_connections/application/platform_connection_list_bloc.dart';
import 'package:libredb_mobile/features/platform_connections/domain/repositories/platform_connection_repository.dart';
import 'package:libredb_mobile/features/platform_connections/presentation/pages/platform_connection_list_page.dart';
import 'package:libredb_mobile/features/platform_connections/presentation/widgets/connection_list_providers.dart';
import 'package:libredb_mobile/features/platform_home/presentation/pages/platform_home_page.dart';
import 'package:libredb_mobile/features/platform_status/application/platform_status_bloc.dart';
import 'package:libredb_mobile/features/platform_status/application/platform_status_event.dart';
import 'package:libredb_mobile/features/platform_status/application/usecases/check_platform_liveness_usecase.dart';
import 'package:libredb_mobile/features/platform_status/presentation/pages/platform_status_gate.dart';
import 'package:libredb_mobile/features/platform_status/presentation/pages/platform_unreachable_page.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/infrastructure/config/environment.dart';
import 'package:libredb_mobile/shared/design_system/theme/app_theme.dart';
import 'package:libredb_mobile/shared/models/platform_connection.dart';
import 'package:libredb_mobile/shared/models/platform_identity.dart';
import 'package:mocktail/mocktail.dart';

import '../../mocks/mock_classes.dart';

const _down = NetworkError('Connection refused');
const _admin = PlatformIdentity(
  id: 'usr_1',
  email: 'admin@example.com',
  name: 'Ada Admin',
  roles: ['PLATFORM_ADMIN'],
  permissions: [],
  tenant: PlatformTenant(id: 'tnt_1', name: 'Example Org', slug: 'example-org'),
);
const _orders = PlatformConnection(
  id: 'c1',
  name: 'Orders',
  engine: 'postgres',
  status: 'active',
  hasWriteCredential: true,
);

/// A restored Platform session whose screens loaded under the Platform unreachable page, failed, and must show fresh
/// data once the user's Retry finds Platform answering again (#343), the mirror of the Studio gate (#339).
void main() {
  late MockIPlatformStatusRepository status;
  late MockPlatformIdentityRepository identityRepository;
  late MockIPlatformConnectionRepository connections;
  late PlatformStatusBloc statusBloc;
  late PlatformIdentityCubit identity;

  setUp(() {
    status = MockIPlatformStatusRepository();
    identityRepository = MockPlatformIdentityRepository();
    connections = MockIPlatformConnectionRepository();
  });

  void platformDown() {
    when(() => status.liveness()).thenAnswer((_) async => const Failure(_down));
    when(() => identityRepository.fetch()).thenAnswer((_) async => const Failure(_down));
    when(() => connections.list()).thenAnswer((_) async => const Failure(_down));
  }

  void platformUp() {
    when(() => status.liveness()).thenAnswer((_) async => const Success(null));
    when(() => identityRepository.fetch()).thenAnswer((_) async => const Success(_admin));
    when(() => connections.list()).thenAnswer((_) async => const Success([_orders]));
  }

  // The blocs are created inside the test body, so their streams run in the test's fake async zone.
  Future<void> pumpRestoredSession(WidgetTester tester, {required String at}) async {
    statusBloc = PlatformStatusBloc(checkLivenessUseCase: CheckPlatformLivenessUseCase(status));
    identity = PlatformIdentityCubit(repository: identityRepository);
    final studioIdentity = MockStudioIdentityCubit();
    when(() => studioIdentity.state).thenReturn(const StudioIdentityInitial());
    final policy = MockConnectionPolicyCubit();
    when(() => policy.state).thenReturn(const ConnectionPolicyInitial());
    final connectivity = MockConnectivityCubit();
    when(() => connectivity.state).thenReturn(const ConnectivityState.initial());
    final signOut = MockSignOutBloc();
    when(() => signOut.state).thenReturn(const SignOutInitial());
    final router = GoRouter(
      initialLocation: at,
      routes: [
        ShellRoute(
          builder: (context, state, child) => PlatformShell(state: state, child: child),
          routes: [
            GoRoute(path: ApplicationRoutesConstants.platformHome, builder: (_, _) => const PlatformHomePage()),
            GoRoute(
              path: ApplicationRoutesConstants.platformConnections,
              builder: (_, _) => const PlatformConnectionListProviders(child: PlatformConnectionListPage()),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: [
          RepositoryProvider<AppConfig>.value(
            value: const AppConfig(
              environment: Environment.mock,
              apiBaseUrl: 'https://studio.example.test/api',
              certificatePins: [],
              idleTimeout: null,
              platform: PlatformConfigured(baseUrl: 'https://platform.example.test/api'),
            ),
          ),
          RepositoryProvider<IPlatformConnectionRepository>.value(value: connections),
        ],
        child: MultiBlocProvider(
          providers: [
            BlocProvider<PlatformStatusBloc>(create: (_) => statusBloc),
            BlocProvider<PlatformIdentityCubit>(create: (_) => identity),
            BlocProvider<PlatformAccountRefusalCubit>(create: (_) => PlatformAccountRefusalCubit()),
            BlocProvider<StudioIdentityCubit>.value(value: studioIdentity),
            BlocProvider<ConnectionPolicyCubit>.value(value: policy),
            BlocProvider<ConnectivityCubit>.value(value: connectivity),
            BlocProvider<SignOutBloc>.value(value: signOut),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            theme: AppTheme.light(),
            locale: const Locale('en'),
            localizationsDelegates: const [
              S.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: S.delegate.supportedLocales,
            builder: (context, child) => PlatformStatusGate(child: child!),
          ),
        ),
      ),
    );
    // The app's first liveness check, sent once a Platform session needs it.
    statusBloc.add(const PlatformLivenessCheckRequested());
    await tester.pumpAndSettle();
  }

  PlatformConnectionListState listState(WidgetTester tester) => tester
      .element(find.byType(PlatformConnectionListPage, skipOffstage: false))
      .read<PlatformConnectionListBloc>()
      .state;

  testWidgets('a Retry that finds Platform answering reloads the identity and the list that failed covered', (
    tester,
  ) async {
    platformDown();
    await pumpRestoredSession(tester, at: ApplicationRoutesConstants.platformConnections);

    expect(find.byType(PlatformUnreachablePage), findsOneWidget);
    // The covered screens loaded meanwhile and failed, as on the phone.
    expect(identity.state, isA<PlatformIdentityFailure>());
    expect(listState(tester), isA<PlatformConnectionListFailure>());

    platformUp();
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.byType(PlatformUnreachablePage), findsNothing);
    expect(identity.state, const PlatformIdentityLoaded(_admin));
    expect(listState(tester), isA<PlatformConnectionListLoaded>());
    expect(find.text('Orders'), findsOneWidget);
    expect(find.text('Could not load the connections'), findsNothing);
  });

  testWidgets('a Retry that finds Platform answering shows the admin on Home instead of the failure', (tester) async {
    platformDown();
    await pumpRestoredSession(tester, at: ApplicationRoutesConstants.platformHome);
    expect(identity.state, isA<PlatformIdentityFailure>());

    platformUp();
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.byType(PlatformUnreachablePage), findsNothing);
    expect(find.text('Ada Admin'), findsOneWidget);
    expect(find.text('Example Org'), findsOneWidget);
    expect(find.text('Could not load your Platform account'), findsNothing);
  });

  testWidgets('a Retry that finds Platform still down asks nothing behind the page', (tester) async {
    platformDown();
    await pumpRestoredSession(tester, at: ApplicationRoutesConstants.platformConnections);
    clearInteractions(identityRepository);
    clearInteractions(connections);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.byType(PlatformUnreachablePage), findsOneWidget);
    verifyNever(() => identityRepository.fetch());
    verifyNever(() => connections.list());
  });

  testWidgets('uncovering screens that loaded keeps them and asks nothing again at once', (tester) async {
    platformUp();
    await pumpRestoredSession(tester, at: ApplicationRoutesConstants.platformConnections);
    expect(listState(tester), isA<PlatformConnectionListLoaded>());

    when(() => status.liveness()).thenAnswer((_) async => const Failure(_down));
    statusBloc.add(const PlatformLivenessCheckRequested());
    await tester.pumpAndSettle();
    expect(find.byType(PlatformUnreachablePage), findsOneWidget);
    clearInteractions(identityRepository);
    clearInteractions(connections);

    when(() => status.liveness()).thenAnswer((_) async => const Success(null));
    await tester.tap(find.text('Retry'));
    await tester.pump();
    await tester.pump();

    expect(find.byType(PlatformUnreachablePage), findsNothing);
    expect(identity.state, const PlatformIdentityLoaded(_admin));
    verifyNever(() => identityRepository.fetch());
    verifyNever(() => connections.list());
  });
}
