@Tags(['widget'])
library;

import 'dart:async';
import 'dart:io';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:libredb_mobile/app/analytics/analytics_route_observer.dart';
import 'package:libredb_mobile/app/connectivity/app_connectivity_scope.dart';
import 'package:libredb_mobile/app/connectivity/connectivity_cubit.dart';
import 'package:libredb_mobile/app/router/app_routes_constants.dart';
import 'package:libredb_mobile/app/session/studio_account_refusal_cubit.dart';
import 'package:libredb_mobile/app/shell/app_shell.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/auth/application/sign_out_bloc.dart';
import 'package:libredb_mobile/features/auth/application/studio_identity_cubit.dart';
import 'package:libredb_mobile/features/auth/application/usecases/logout_usecase.dart';
import 'package:libredb_mobile/features/connections/application/connection_policy_cubit.dart';
import 'package:libredb_mobile/features/object_browser/data/models/object_browser_json.dart';
import 'package:libredb_mobile/features/sql_editor/domain/entities/statement_history_entry.dart';
import 'package:libredb_mobile/features/sql_editor/domain/repositories/sql_editor_repository.dart';
import 'package:libredb_mobile/features/sql_editor/domain/repositories/statement_history_repository.dart';
import 'package:libredb_mobile/features/sql_editor/navigation/sql_editor_routes.dart';
import 'package:libredb_mobile/features/sql_editor/presentation/widgets/editor_actions.dart';
import 'package:libredb_mobile/features/sql_editor/presentation/widgets/editor_catalog_chip.dart';
import 'package:libredb_mobile/features/sql_editor/presentation/widgets/editor_input.dart';
import 'package:libredb_mobile/features/sql_editor/presentation/widgets/statement_history_sheet.dart';
import 'package:libredb_mobile/features/studio_status/application/studio_status_bloc.dart';
import 'package:libredb_mobile/features/studio_status/application/studio_status_state.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/infrastructure/connectivity/connectivity_service.dart';
import 'package:libredb_mobile/infrastructure/studio/provider_meta_json.dart';
import 'package:libredb_mobile/shared/active_connection/active_catalog_cubit.dart';
import 'package:libredb_mobile/shared/active_connection/active_connection_cubit.dart';
import 'package:libredb_mobile/shared/models/answered.dart';
import 'package:libredb_mobile/shared/models/containers_repository.dart';
import 'package:libredb_mobile/shared/models/editor_open_request.dart';
import 'package:libredb_mobile/shared/models/provider_meta_repository.dart';
import 'package:libredb_mobile/shared/models/studio_connection.dart';
import 'package:libredb_mobile/shared/models/studio_identity.dart';
import 'package:libredb_mobile/shared/utils/schema_change_notifier.dart';
import 'package:libredb_mobile/shared/utils/subject_hash.dart';
import 'package:libredb_mobile/shared/widgets/result_view/result_view_mode_cubit.dart';
import 'package:logging/logging.dart' as logging;
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mock_classes.dart';
import '../../../../support/printed_lines.dart';

String _fixture(String name) => File('test/fixtures/studio/$name.json').readAsStringSync();

const _postgres = StudioConnection(id: 'seed:dev-postgres', name: 'Dev Postgres', type: 'postgres');
const _server = StudioConnection(id: 'seed:dev-postgres-server', name: 'Dev Postgres server', type: 'postgres');

/// A statement with customer data in a literal, which no location, log line or analytics event may carry.
const _statement = "SELECT * FROM customers WHERE email = 'ada@example.com'";

/// Any screen opening the editor through [openEditor]: the statement travels in memory to the SQL tab, the editor opens
/// the request's connection and database, and the text lands in the field without running.
void main() {
  late ActiveConnectionCubit active;
  late MockISqlEditorRepository repository;
  late MockIProviderMetaRepository providerMeta;
  late MockIContainersRepository containers;
  late MockIStatementHistoryRepository history;
  late MockAnalyticsService analytics;
  late SchemaChangeNotifier schemaChanges;
  late List<ActiveConnectionState> switches;

  setUp(() {
    final store = MockIActiveConnectionStore();
    when(() => store.read(any())).thenAnswer((_) async => null);
    when(() => store.write(any(), any())).thenAnswer((_) async {});
    active = ActiveConnectionCubit(store: store)
      ..connectionsListed(const [_postgres, _server])
      ..select(_postgres);
    switches = [];
    final subscription = active.stream.listen(switches.add);
    addTearDown(subscription.cancel);
    repository = MockISqlEditorRepository();
    providerMeta = MockIProviderMetaRepository();
    when(() => providerMeta.providerMeta(_postgres.id))
        .thenAnswer((_) async => Success(ProviderMetaJson.read(_fixture('meta_postgres'))));
    when(() => providerMeta.providerMeta(_server.id))
        .thenAnswer((_) async => Success(ProviderMetaJson.read(_fixture('meta_postgres_server'))));
    containers = MockIContainersRepository();
    when(() => containers.containers(_server.id, refresh: any(named: 'refresh'))).thenAnswer(
      (_) async =>
          Success(Answered(ObjectBrowserJson.containers(_fixture('containers_postgres_server')), at: DateTime(2026))),
    );
    history = MockIStatementHistoryRepository();
    when(() => history.read(any())).thenAnswer((_) async => const Success([]));
    analytics = MockAnalyticsService();
    schemaChanges = SchemaChangeNotifier(providerMeta: providerMeta, invalidateConnection: (_) {});
  });

  tearDown(() async {
    await schemaChanges.dispose();
    await active.close();
  });

  Future<GoRouter> pumpShell(WidgetTester tester, {String location = '/sql'}) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final identity = MockStudioIdentityCubit();
    whenListen(
      identity,
      const Stream<StudioIdentityState>.empty(),
      initialState: const StudioIdentityLoaded(
        StudioIdentity(username: 'ada', role: StudioUserRole(), subject: 'kc-ada'),
      ),
    );
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
      // As the app's router runs, so go_router logs every location it goes to.
      debugLogDiagnostics: true,
      observers: [AnalyticsRouteObserver(analytics)],
      routes: [
        ShellRoute(
          builder: (context, state, child) => AppShell(state: state, child: child),
          routes: [
            GoRoute(path: '/connections', builder: (_, _) => const Text('connections page')),
            GoRoute(
              name: 'browse',
              path: '/browse',
              builder: (_, _) => const Text('browse root'),
              routes: [GoRoute(path: 'objects', builder: (_, _) => const Text('browse objects'))],
            ),
            ...SqlEditorFeatureRoutes.routes,
          ],
        ),
        GoRoute(path: '/login', builder: (_, _) => const Text('login page')),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: [
          RepositoryProvider<ISqlEditorRepository>.value(value: repository),
          RepositoryProvider<IProviderMetaRepository>.value(value: providerMeta),
          RepositoryProvider<SchemaChangeNotifier>.value(value: schemaChanges),
          RepositoryProvider<IContainersRepository>.value(value: containers),
          RepositoryProvider<IStatementHistoryRepository>.value(value: history),
        ],
        child: MultiBlocProvider(
          providers: [
            BlocProvider<ActiveConnectionCubit>.value(value: active),
            BlocProvider<ActiveCatalogCubit>(
              create: (_) => ActiveCatalogCubit(store: MockIActiveCatalogStore(), connectionIds: active.connectionIds),
            ),
            BlocProvider<StudioIdentityCubit>.value(value: identity),
            BlocProvider<ConnectionPolicyCubit>.value(value: policy),
            BlocProvider<ConnectivityCubit>.value(value: connectivity),
            BlocProvider<StudioStatusBloc>.value(value: studioStatus),
            BlocProvider<StudioAccountRefusalCubit>(create: (_) => StudioAccountRefusalCubit()),
            BlocProvider<ResultViewModeCubit>(create: (_) => ResultViewModeCubit(store: MockIResultViewModeStore())),
            BlocProvider<SignOutBloc>(create: (_) => SignOutBloc(logoutUseCase: LogoutUseCase(MockIAuthRepository()))),
          ],
          child: AppConnectivityScope(
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
      ),
    );
    await tester.pumpAndSettle();
    switches.clear();
    return router;
  }

  BuildContext anyPage(WidgetTester tester) => tester.element(find.byType(AppShell));

  Future<void> open(WidgetTester tester, EditorOpenRequest request) async {
    openEditor(anyPage(tester), request);
    await tester.pumpAndSettle();
  }

  String editorText(WidgetTester tester) => tester.widget<TextField>(find.byKey(EditorInput.fieldKey)).controller!.text;

  Future<void> type(WidgetTester tester, String text) async {
    await tester.enterText(find.byKey(EditorInput.fieldKey), text);
    await tester.pump();
  }

  ActiveCatalogCubit catalogOf(WidgetTester tester) => BlocProvider.of<ActiveCatalogCubit>(anyPage(tester));

  Finder chip() => find.byKey(EditorCatalogChip.chipKey);

  void verifyNothingSent() => verifyNever(
    () => repository.run(
      any(),
      any(),
      queryId: any(named: 'queryId'),
      page: any(named: 'page'),
      params: any(named: 'params'),
      catalog: any(named: 'catalog'),
      cancelSignal: any(named: 'cancelSignal'),
    ),
  );

  testWidgets('a request lands on the SQL tab with the text in the editor, not run, and a location without it', (
    tester,
  ) async {
    final router = await pumpShell(tester, location: '/browse');
    final records = <logging.LogRecord>[];
    final subscription = logging.Logger('GoRouter').onRecord.listen(records.add);
    addTearDown(subscription.cancel);

    final lines = await printedLines(
      () => open(tester, const EditorOpenRequest(connectionId: 'seed:dev-postgres', text: _statement)),
    );

    expect(router.state.uri.toString(), ApplicationRoutesConstants.sql);
    expect(router.routerDelegate.currentConfiguration.uri.toString(), ApplicationRoutesConstants.sql);
    expect(editorText(tester), _statement);
    expect(active.state.connection, _postgres);
    verifyNothingSent();
    expect(records.map((record) => record.message), contains('going to /sql'));
    for (final record in records) {
      expect(record.message, isNot(contains('customers')));
      expect(record.level < logging.Level.WARNING, isTrue, reason: record.message);
    }
    expect(lines.where((line) => line.contains('customers') || line.contains('ada@example.com')), isEmpty);
    final screens = verify(
      () => analytics.logScreenView(
        screenName: captureAny(named: 'screenName'),
        screenClass: any(named: 'screenClass'),
      ),
    ).captured.cast<String>();
    expect(screens, contains('sql'));
    expect(screens.where((screen) => screen.contains('customers')), isEmpty);
  });

  testWidgets('a request on the open connection switches nothing, and a rebuild does not put the text in again', (
    tester,
  ) async {
    await pumpShell(tester);

    await open(tester, const EditorOpenRequest(connectionId: 'seed:dev-postgres', text: 'SELECT 1'));
    await type(tester, 'SELECT 2');
    tester.view.physicalSize = const Size(800, 400);
    await tester.pumpAndSettle();

    expect(editorText(tester), 'SELECT 2');
    expect(switches, isEmpty);
  });

  group('the replace prompt', () {
    testWidgets('an empty editor takes the text without asking', (tester) async {
      await pumpShell(tester);
      await type(tester, '   ');

      await open(tester, const EditorOpenRequest(connectionId: 'seed:dev-postgres', text: 'SELECT 1'));

      expect(find.text("Replace the editor's text?"), findsNothing);
      expect(editorText(tester), 'SELECT 1');
    });

    testWidgets('the same text asks nothing', (tester) async {
      await pumpShell(tester);
      await type(tester, 'SELECT 1');

      await open(tester, const EditorOpenRequest(connectionId: 'seed:dev-postgres', text: 'SELECT 1'));

      expect(find.text("Replace the editor's text?"), findsNothing);
      expect(editorText(tester), 'SELECT 1');
    });

    testWidgets('a different text is replaced only after asking, and nothing runs', (tester) async {
      await pumpShell(tester);
      await type(tester, 'SELECT 2');

      await open(tester, const EditorOpenRequest(connectionId: 'seed:dev-postgres', text: 'SELECT 1'));
      expect(find.text("Replace the editor's text?"), findsOneWidget);
      // One wording for every source of a request, History and Browse alike.
      expect(
        find.text('The new statement takes the place of the text in the editor. It does not run.'),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Replace'));
      await tester.pumpAndSettle();

      expect(editorText(tester), 'SELECT 1');
      verifyNothingSent();
    });

    testWidgets('a cancel keeps the text and the database', (tester) async {
      active.select(_server);
      await pumpShell(tester);
      expect(catalogOf(tester).catalogOf(_server.id), 'app');
      await type(tester, 'SELECT 2');

      await open(
        tester,
        const EditorOpenRequest(connectionId: 'seed:dev-postgres-server', text: 'SELECT 1', catalog: 'archive'),
      );
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();

      expect(editorText(tester), 'SELECT 2');
      expect(catalogOf(tester).catalogOf(_server.id), 'app');
      expect(find.descendant(of: chip(), matching: find.text('Database: app')), findsOneWidget);
    });
  });

  testWidgets('a request on a server-level connection with a database shows that database in the chip', (tester) async {
    await pumpShell(tester, location: '/browse');

    await open(
      tester,
      const EditorOpenRequest(connectionId: 'seed:dev-postgres-server', text: 'SELECT 1', catalog: 'archive'),
    );

    expect(active.state.connection, _server);
    expect(editorText(tester), 'SELECT 1');
    expect(find.descendant(of: chip(), matching: find.text('Database: archive')), findsOneWidget);
    expect(catalogOf(tester).catalogOf(_server.id), 'archive');
    verifyNothingSent();
  });

  testWidgets('a request on another connection opens it from deep in Browse and lands on the SQL tab', (tester) async {
    final router = await pumpShell(tester, location: '/browse/objects');

    await open(tester, const EditorOpenRequest(connectionId: 'seed:dev-postgres-server', text: 'SELECT 1'));

    expect(router.state.uri.toString(), ApplicationRoutesConstants.sql);
    expect(active.state.connection, _server);
    expect(editorText(tester), 'SELECT 1');
  });

  testWidgets('a request for a connection Studio no longer lists opens nothing and says so', (tester) async {
    await pumpShell(tester);
    await type(tester, 'SELECT 2');

    await open(tester, const EditorOpenRequest(connectionId: 'seed:gone', text: 'SELECT 1'));

    expect(find.text('That connection is no longer available, so the statement was not opened.'), findsOneWidget);
    expect(find.text("Replace the editor's text?"), findsNothing);
    expect(active.state.connection, _postgres);
    expect(switches, isEmpty);
    expect(editorText(tester), 'SELECT 2');
  });

  testWidgets('a history entry of another connection opens that connection with the entry, not run', (tester) async {
    final entry = StatementHistoryEntry(
      id: '1',
      connectionId: _server.id,
      connectionName: _server.name,
      text: 'SELECT * FROM archive_orders',
      status: StatementRunStatus.success,
      duration: const Duration(milliseconds: 3),
      executedAt: DateTime.utc(2026, 10, 23),
    );
    when(() => history.read(subjectHash('kc-ada'))).thenAnswer((_) async => Success([entry]));
    final router = await pumpShell(tester);
    await type(tester, 'SELECT 2');

    await tester.tap(find.byKey(EditorActions.historyKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(StatementHistorySheet.allConnectionsKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(StatementHistorySheet.entryKey('1')));
    await tester.pumpAndSettle();

    expect(router.state.uri.toString(), ApplicationRoutesConstants.sql);
    expect(active.state.connection, _server);
    expect(find.text("Replace the editor's text?"), findsNothing);
    expect(editorText(tester), 'SELECT * FROM archive_orders');
    verifyNothingSent();
  });

  testWidgets('the request travels in memory only: the extra encodes as nothing', (tester) async {
    final router = await pumpShell(tester);

    await open(tester, const EditorOpenRequest(connectionId: 'seed:dev-postgres', text: _statement));

    final restored = router.routeInformationParser.restoreRouteInformation(router.routerDelegate.currentConfiguration);
    expect(restored?.uri.toString(), ApplicationRoutesConstants.sql);
    expect('${restored?.state}', isNot(contains('customers')));
  });
}
