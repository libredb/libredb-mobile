@Tags(['widget'])
library;

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:libredb_mobile/app/connectivity/app_connectivity_scope.dart';
import 'package:libredb_mobile/app/connectivity/connectivity_cubit.dart';
import 'package:libredb_mobile/app/session/studio_account_refusal_cubit.dart';
import 'package:libredb_mobile/app/shell/app_shell.dart';
import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/auth/application/sign_out_bloc.dart';
import 'package:libredb_mobile/features/auth/application/studio_identity_cubit.dart';
import 'package:libredb_mobile/features/auth/application/usecases/logout_usecase.dart';
import 'package:libredb_mobile/features/connections/application/connection_list_bloc.dart';
import 'package:libredb_mobile/features/connections/application/connection_policy_cubit.dart';
import 'package:libredb_mobile/features/connections/application/favorite_connections_bloc.dart';
import 'package:libredb_mobile/features/connections/domain/entities/connection_favorites.dart';
import 'package:libredb_mobile/features/connections/domain/entities/connection_policy.dart';
import 'package:libredb_mobile/features/connections/domain/entities/managed_connections.dart';
import 'package:libredb_mobile/features/connections/domain/repositories/collapsed_sections_repository.dart';
import 'package:libredb_mobile/features/connections/domain/repositories/connection_repository.dart';
import 'package:libredb_mobile/features/connections/presentation/pages/connection_list_page.dart';
import 'package:libredb_mobile/features/connections/presentation/widgets/connection_list_providers.dart';
import 'package:libredb_mobile/features/studio_status/application/studio_status_bloc.dart';
import 'package:libredb_mobile/features/studio_status/application/studio_status_event.dart';
import 'package:libredb_mobile/features/studio_status/application/usecases/check_studio_liveness_usecase.dart';
import 'package:libredb_mobile/features/studio_status/application/usecases/read_studio_readiness_usecase.dart';
import 'package:libredb_mobile/features/studio_status/presentation/pages/studio_status_gate.dart';
import 'package:libredb_mobile/features/studio_status/presentation/pages/studio_unreachable_page.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/infrastructure/config/environment.dart';
import 'package:libredb_mobile/infrastructure/connectivity/connectivity_service.dart';
import 'package:libredb_mobile/shared/active_connection/active_catalog_cubit.dart';
import 'package:libredb_mobile/shared/active_connection/active_connection_cubit.dart';
import 'package:libredb_mobile/shared/models/studio_connection.dart';
import 'package:libredb_mobile/shared/models/studio_identity.dart';
import 'package:mocktail/mocktail.dart';

import '../../mocks/mock_classes.dart';

const _down = NetworkError('Connection refused');
const _ada = StudioIdentity(username: 'ada', role: StudioUserRole(), subject: 'kc-ada');
const _sales = StudioConnection(id: 'seed:sales', name: 'Sales', type: 'postgres');

/// A restored Studio session whose screens loaded under the Studio unreachable page, failed, and must show fresh data
/// once the user's Retry finds Studio answering again (#339).
void main() {
  late MockIStudioStatusRepository status;
  late MockIStudioIdentityRepository identityRepository;
  late MockIConnectionRepository connections;
  late StudioStatusBloc statusBloc;
  late StudioIdentityCubit identity;
  late ConnectionPolicyCubit policy;

  setUp(() {
    status = MockIStudioStatusRepository();
    identityRepository = MockIStudioIdentityRepository();
    connections = MockIConnectionRepository();
  });

  void studioDown() {
    when(() => status.liveness()).thenAnswer((_) async => const Failure(_down));
    when(() => identityRepository.fetch()).thenAnswer((_) async => const Failure(_down));
    when(() => connections.listManaged()).thenAnswer((_) async => const Failure(_down));
    when(() => connections.fetchPolicy()).thenAnswer((_) async => const Failure(_down));
  }

  void studioUp() {
    when(() => status.liveness()).thenAnswer((_) async => const Success(null));
    when(() => identityRepository.fetch()).thenAnswer((_) async => const Success(_ada));
    when(() => connections.listManaged())
        .thenAnswer((_) async => const Success(ManagedConnections(connections: [_sales])));
    when(() => connections.fetchPolicy())
        .thenAnswer((_) async => const Success(ConnectionPolicy(customConnections: false, governance: false)));
  }

  // The blocs are created inside the test body, so their streams run in the test's fake async zone.
  Future<void> pumpRestoredSession(WidgetTester tester) async {
    statusBloc = StudioStatusBloc(
      checkLivenessUseCase: CheckStudioLivenessUseCase(status),
      readReadinessUseCase: ReadStudioReadinessUseCase(status),
    );
    identity = StudioIdentityCubit(repository: identityRepository);
    policy = ConnectionPolicyCubit(repository: connections);
    final active = ActiveConnectionCubit(store: MockIActiveConnectionStore());
    final connectivity = MockConnectivityCubit();
    whenListen(
      connectivity,
      const Stream<ConnectivityState>.empty(),
      initialState: const ConnectivityState(status: ConnectivityStatus.online),
    );
    final favorites = MockIFavoriteConnectionsRepository();
    when(() => favorites.read(any())).thenAnswer((_) async => ConnectionFavorites.empty);
    final collapsed = MockICollapsedSectionsRepository();
    when(() => collapsed.read()).thenAnswer((_) async => <String>{});
    final router = GoRouter(
      initialLocation: '/connections',
      routes: [
        ShellRoute(
          builder: (context, state, child) => AppShell(state: state, child: child),
          routes: [
            GoRoute(
              path: '/connections',
              builder: (_, _) => const ConnectionListProviders(child: ConnectionListPage()),
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
            ),
          ),
          RepositoryProvider<IConnectionRepository>.value(value: connections),
          RepositoryProvider<ICollapsedSectionsRepository>.value(value: collapsed),
        ],
        child: MultiBlocProvider(
          providers: [
            BlocProvider<StudioStatusBloc>(create: (_) => statusBloc),
            BlocProvider<StudioIdentityCubit>(create: (_) => identity),
            BlocProvider<ConnectionPolicyCubit>(create: (_) => policy),
            BlocProvider<ActiveConnectionCubit>(create: (_) => active),
            BlocProvider<ActiveCatalogCubit>(
              create: (_) => ActiveCatalogCubit(store: MockIActiveCatalogStore(), connectionIds: active.connectionIds),
            ),
            BlocProvider<ConnectivityCubit>.value(value: connectivity),
            BlocProvider<FavoriteConnectionsBloc>(create: (_) => FavoriteConnectionsBloc(repository: favorites)),
            BlocProvider<StudioAccountRefusalCubit>(create: (_) => StudioAccountRefusalCubit()),
            BlocProvider<SignOutBloc>(create: (_) => SignOutBloc(logoutUseCase: LogoutUseCase(MockIAuthRepository()))),
          ],
          child: AppConnectivityScope(
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
              builder: (context, child) => StudioStatusGate(child: child!),
            ),
          ),
        ),
      ),
    );
    // The app's first liveness check, sent when the gate first builds.
    statusBloc.add(const StudioLivenessCheckRequested());
    await tester.pumpAndSettle();
  }

  ConnectionListState listState(WidgetTester tester) =>
      tester.element(find.byType(ConnectionListPage, skipOffstage: false)).read<ConnectionListBloc>().state;

  testWidgets('a Retry that finds Studio answering reloads the identity, the policy and the list that failed covered', (
    tester,
  ) async {
    studioDown();
    await pumpRestoredSession(tester);

    expect(find.byType(StudioUnreachablePage), findsOneWidget);
    // The covered screens loaded meanwhile and failed, as on the phone.
    expect(identity.state, isA<StudioIdentityFailure>());
    expect(policy.state, isA<ConnectionPolicyFailure>());
    expect(listState(tester), isA<ConnectionListFailure>());

    studioUp();
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.byType(StudioUnreachablePage), findsNothing);
    expect(identity.state, const StudioIdentityLoaded(_ada));
    expect(policy.state, isA<ConnectionPolicyLoaded>());
    expect(listState(tester), isA<ConnectionListLoaded>());
    expect(find.text('Sales'), findsOneWidget);
    expect(find.text('Could not load the connections'), findsNothing);
  });

  testWidgets('a Retry that finds Studio still down asks nothing behind the page', (tester) async {
    studioDown();
    await pumpRestoredSession(tester);
    clearInteractions(identityRepository);
    clearInteractions(connections);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.byType(StudioUnreachablePage), findsOneWidget);
    verifyNever(() => identityRepository.fetch());
    verifyNever(() => connections.listManaged());
    verifyNever(() => connections.fetchPolicy());
  });

  testWidgets('uncovering screens that loaded keeps them and asks nothing again at once', (tester) async {
    studioUp();
    await pumpRestoredSession(tester);
    expect(listState(tester), isA<ConnectionListLoaded>());

    when(() => status.liveness()).thenAnswer((_) async => const Failure(_down));
    statusBloc.add(const StudioLivenessCheckRequested());
    await tester.pumpAndSettle();
    expect(find.byType(StudioUnreachablePage), findsOneWidget);
    clearInteractions(identityRepository);
    clearInteractions(connections);

    when(() => status.liveness()).thenAnswer((_) async => const Success(null));
    await tester.tap(find.text('Retry'));
    await tester.pump();
    await tester.pump();

    expect(find.byType(StudioUnreachablePage), findsNothing);
    expect(identity.state, const StudioIdentityLoaded(_ada));
    verifyNever(() => identityRepository.fetch());
    verifyNever(() => connections.fetchPolicy());
    verifyNever(() => connections.listManaged());
  });
}
