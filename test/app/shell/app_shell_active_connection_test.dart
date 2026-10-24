@Tags(['widget'])
library;

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:libredb_mobile/app/connectivity/connectivity_cubit.dart';
import 'package:libredb_mobile/app/session/studio_account_refusal_cubit.dart';
import 'package:libredb_mobile/app/shell/app_shell.dart';
import 'package:libredb_mobile/app/shell/top_bar/top_bar_widget.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/auth/application/sign_out_bloc.dart';
import 'package:libredb_mobile/features/auth/application/studio_identity_cubit.dart';
import 'package:libredb_mobile/features/auth/application/usecases/logout_usecase.dart';
import 'package:libredb_mobile/features/connections/application/connection_policy_cubit.dart';
import 'package:libredb_mobile/features/connections/application/favorite_connections_bloc.dart';
import 'package:libredb_mobile/features/connections/domain/entities/managed_connections.dart';
import 'package:libredb_mobile/features/connections/domain/repositories/collapsed_sections_repository.dart';
import 'package:libredb_mobile/features/connections/domain/repositories/connection_repository.dart';
import 'package:libredb_mobile/features/connections/presentation/widgets/connection_switcher_sheet.dart';
import 'package:libredb_mobile/features/studio_status/application/studio_status_bloc.dart';
import 'package:libredb_mobile/features/studio_status/application/studio_status_state.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/infrastructure/connectivity/connectivity_service.dart';
import 'package:libredb_mobile/shared/active_connection/active_connection_cubit.dart';
import 'package:libredb_mobile/shared/models/studio_connection.dart';
import 'package:libredb_mobile/shared/widgets/studio_role_scope.dart';
import 'package:mocktail/mocktail.dart';

import '../../mocks/mock_classes.dart';

/// What the shell does when the active connection changes, on a router with a page deeper in the Browse tab, as the
/// object browser pages of M3 are.
void main() {
  const sales = StudioConnection(id: 'seed:sales', name: 'Sales', type: 'postgres');
  const billing = StudioConnection(id: 'seed:billing', name: 'Billing', type: 'mysql');

  late ActiveConnectionCubit active;
  late MockIActiveConnectionStore store;

  setUp(() {
    store = MockIActiveConnectionStore();
    when(() => store.read(any())).thenAnswer((_) async => null);
    when(() => store.write(any(), any())).thenAnswer((_) async {});
    active = ActiveConnectionCubit(store: store);
  });

  tearDown(() => active.close());

  Future<GoRouter> pumpShellOn(WidgetTester tester, String location) async {
    final identity = MockStudioIdentityCubit();
    whenListen(identity, const Stream<StudioIdentityState>.empty(), initialState: const StudioIdentityLoading());
    final policy = MockConnectionPolicyCubit();
    whenListen(policy, const Stream<ConnectionPolicyState>.empty(), initialState: const ConnectionPolicyLoading());
    final connectivity = MockConnectivityCubit();
    whenListen(
      connectivity,
      const Stream<ConnectivityState>.empty(),
      initialState: const ConnectivityState(status: ConnectivityStatus.online),
    );
    final studioStatus = MockStudioStatusBloc();
    whenListen(studioStatus, const Stream<StudioStatusState>.empty(), initialState: const StudioReachable());
    final router = GoRouter(
      initialLocation: location,
      routes: [
        ShellRoute(
          builder: (context, state, child) => AppShell(state: state, child: child),
          routes: [
            GoRoute(path: '/connections', builder: (_, _) => const Text('connections page')),
            GoRoute(
              path: '/sql',
              builder: (_, _) => const Text('sql editor'),
              routes: [GoRoute(path: 'deeper', builder: (_, _) => const Text('deeper sql page'))],
            ),
            GoRoute(
              path: '/browse',
              builder: (_, _) => const Text('browse root'),
              routes: [GoRoute(path: 'seed:sales/containers', builder: (_, _) => const Text('deep page'))],
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    final connections = MockIConnectionRepository();
    // The switcher lists both connections, so opening it reports neither as vanished.
    when(() => connections.listManaged())
        .thenAnswer((_) async => const Success(ManagedConnections(connections: [sales, billing])));
    final favorites = FavoriteConnectionsBloc(repository: MockIFavoriteConnectionsRepository());
    addTearDown(favorites.close);
    final collapsed = MockICollapsedSectionsRepository();
    when(() => collapsed.read()).thenAnswer((_) async => <String>{});
    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: [
          RepositoryProvider<IConnectionRepository>.value(value: connections),
          RepositoryProvider<ICollapsedSectionsRepository>.value(value: collapsed),
        ],
        child: MultiBlocProvider(
          providers: [
            BlocProvider<ActiveConnectionCubit>.value(value: active),
            BlocProvider<StudioIdentityCubit>.value(value: identity),
            BlocProvider<ConnectionPolicyCubit>.value(value: policy),
            BlocProvider<ConnectivityCubit>.value(value: connectivity),
            BlocProvider<StudioStatusBloc>.value(value: studioStatus),
            BlocProvider<FavoriteConnectionsBloc>.value(value: favorites),
            BlocProvider<StudioAccountRefusalCubit>(create: (_) => StudioAccountRefusalCubit()),
            BlocProvider<SignOutBloc>(create: (_) => SignOutBloc(logoutUseCase: LogoutUseCase(MockIAuthRepository()))),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            localizationsDelegates: const [
              S.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: S.delegate.supportedLocales,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  String path(GoRouter router) => router.state.uri.path;

  testWidgets('a page in the shell reads no role while the identity loads, so it masks with the user settings', (
    tester,
  ) async {
    await pumpShellOn(tester, '/connections');

    expect(StudioRoleScope.of(tester.element(find.text('connections page'))), isNull);
  });

  testWidgets('a switch returns a deeper Browse page to the Browse root', (tester) async {
    active.select(sales);
    final router = await pumpShellOn(tester, '/browse/seed:sales/containers');

    active.select(billing);
    await tester.pumpAndSettle();

    expect(path(router), '/browse');
    expect(find.text('browse root'), findsOneWidget);
  });

  testWidgets('what Studio now says about the same connection is no switch', (tester) async {
    active.select(sales);
    final router = await pumpShellOn(tester, '/browse/seed:sales/containers');

    active.connectionsListed(const [
      StudioConnection(id: 'seed:sales', name: 'Sales', type: 'postgres', readOnly: true),
    ]);
    await tester.pumpAndSettle();

    expect(path(router), '/browse/seed:sales/containers');
  });

  testWidgets('a switch leaves another tab as it is', (tester) async {
    active.select(sales);
    final router = await pumpShellOn(tester, '/connections');

    active.select(billing);
    await tester.pumpAndSettle();

    expect(path(router), '/connections');
  });

  testWidgets('a vanished connection is named, and its pages close for the connection list', (tester) async {
    active.select(sales);
    final router = await pumpShellOn(tester, '/browse/seed:sales/containers');

    active.reportUnavailable(sales.id);
    await tester.pumpAndSettle();

    expect(find.text(S.current.connection_vanished('Sales')), findsOneWidget);
    expect(path(router), '/connections');
  });

  testWidgets('a connection that vanishes on the connection list is named there', (tester) async {
    active.select(sales);
    final router = await pumpShellOn(tester, '/connections');

    active.connectionsListed(const [billing]);
    await tester.pumpAndSettle();

    expect(find.text(S.current.connection_vanished('Sales')), findsOneWidget);
    expect(path(router), '/connections');
  });

  group('the SQL tab top bar', () {
    Finder inTopBar(Finder finder) => find.descendant(of: find.byType(TopBarWidget), matching: finder);

    testWidgets('with no connection open, reads SQL and opens the switcher', (tester) async {
      await pumpShellOn(tester, '/sql');

      expect(inTopBar(find.text('SQL')), findsOneWidget);
      await tester.tap(inTopBar(find.text('SQL')));
      await tester.pumpAndSettle();

      expect(find.byType(ConnectionSwitcherSheet), findsOneWidget);
    });

    testWidgets('names the open connection and opens the switcher', (tester) async {
      active.select(sales);
      await pumpShellOn(tester, '/sql');

      expect(inTopBar(find.text('Sales')), findsOneWidget);
      expect(inTopBar(find.text('SQL')), findsNothing);
      await tester.tap(inTopBar(find.text('Sales')));
      await tester.pumpAndSettle();

      expect(find.byType(ConnectionSwitcherSheet), findsOneWidget);
    });

    testWidgets('marks a production connection with the PROD label and the environment strip', (tester) async {
      active.select(
        const StudioConnection(id: 'seed:prod', name: 'Prod Postgres', type: 'postgres', environment: 'production'),
      );
      await pumpShellOn(tester, '/sql');

      expect(inTopBar(find.text('Prod Postgres')), findsOneWidget);
      expect(inTopBar(find.text('PROD')), findsOneWidget);
      expect(inTopBar(find.byKey(const ValueKey('active-connection-strip'))), findsOneWidget);
    });

    testWidgets('shows the lock for a read-only connection', (tester) async {
      active.select(const StudioConnection(id: 'seed:ro', name: 'Read Only', type: 'postgres', readOnly: true));
      await pumpShellOn(tester, '/sql');

      expect(inTopBar(find.text('Read Only')), findsOneWidget);
      expect(inTopBar(find.byIcon(Icons.lock_outline)), findsOneWidget);
    });

    testWidgets('names the new connection after a switch, as a History entry opened with Replace makes', (
      tester,
    ) async {
      active.select(sales);
      final router = await pumpShellOn(tester, '/sql');

      active.select(billing);
      await tester.pumpAndSettle();

      expect(path(router), '/sql');
      expect(inTopBar(find.text('Billing')), findsOneWidget);
      expect(inTopBar(find.text('Sales')), findsNothing);
    });

    testWidgets('names the open connection on a page under the SQL tab', (tester) async {
      active.select(sales);
      await pumpShellOn(tester, '/sql/deeper');

      expect(inTopBar(find.text('Sales')), findsOneWidget);
    });
  });
}
