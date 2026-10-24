@Tags(['widget'])
library;

import 'dart:io';
import 'dart:async';

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
import 'package:libredb_mobile/app/shell/profile/profile_sheet.dart';
import 'package:libredb_mobile/app/shell/top_bar/active_connection_title.dart';
import 'package:libredb_mobile/features/connections/presentation/widgets/connection_switcher_sheet.dart';
import 'package:libredb_mobile/core/testing/app_key_constants.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/core/security/screen_capture_protection.dart';
import 'package:libredb_mobile/shared/models/query_result.dart';
import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:libredb_mobile/features/auth/application/sign_out_bloc.dart';
import 'package:libredb_mobile/features/auth/application/studio_identity_cubit.dart';
import 'package:libredb_mobile/features/auth/application/usecases/logout_usecase.dart';
import 'package:libredb_mobile/features/connections/application/connection_policy_cubit.dart';
import 'package:libredb_mobile/features/sql_editor/domain/entities/statement_draft.dart';
import 'package:libredb_mobile/features/sql_editor/domain/repositories/sql_editor_repository.dart';
import 'package:libredb_mobile/features/sql_editor/domain/repositories/statement_text_store.dart';
import 'package:libredb_mobile/features/sql_editor/domain/entities/statement_history_entry.dart';
import 'package:libredb_mobile/features/sql_editor/domain/repositories/statement_history_repository.dart';
import 'package:libredb_mobile/features/sql_editor/navigation/sql_editor_routes.dart';
import 'package:libredb_mobile/features/sql_editor/presentation/widgets/editor_actions.dart';
import 'package:libredb_mobile/features/sql_editor/presentation/widgets/editor_input.dart';
import 'package:libredb_mobile/features/sql_editor/presentation/widgets/statement_history_sheet.dart';
import 'package:libredb_mobile/features/sql_editor/presentation/widgets/write_confirmation_sheet.dart';
import 'package:libredb_mobile/features/studio_status/application/studio_status_bloc.dart';
import 'package:libredb_mobile/features/studio_status/application/studio_status_state.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/infrastructure/connectivity/connectivity_service.dart';
import 'package:libredb_mobile/infrastructure/studio/query_result_json.dart';
import 'package:libredb_mobile/shared/active_connection/active_catalog_cubit.dart';
import 'package:libredb_mobile/shared/active_connection/active_connection_cubit.dart';
import 'package:libredb_mobile/shared/models/containers_repository.dart';
import 'package:libredb_mobile/shared/models/provider_meta.dart';
import 'package:libredb_mobile/shared/models/provider_meta_repository.dart';
import 'package:libredb_mobile/shared/models/studio_identity.dart';
import 'package:libredb_mobile/shared/models/query_page.dart';
import 'package:libredb_mobile/shared/models/studio_connection.dart';
import 'package:libredb_mobile/shared/utils/schema_change_notifier.dart';
import 'package:libredb_mobile/shared/utils/subject_hash.dart';
import 'package:libredb_mobile/shared/widgets/result_view/result_view_mode_cubit.dart';
import 'package:libredb_mobile/shared/utils/app_lifecycle_source.dart';
import 'package:libredb_mobile/shared/utils/background_run_time.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mock_classes.dart';
import '../../../../support/screen_capture.dart';

/// The editor inside the real shell: the write confirmation covers the shell's top bar and tab bar, so nothing there
/// can leave the tab or close the editor while the sheet waits for an answer.
void main() {
  const postgres = StudioConnection(id: 'seed:dev-postgres', name: 'Dev Postgres', type: 'postgres');

  late ActiveConnectionCubit active;
  late MockISqlEditorRepository repository;
  late MockIProviderMetaRepository providerMeta;
  late MockIStatementHistoryRepository history;
  late MockIStatementTextStore textStore;
  late SchemaChangeNotifier schemaChanges;
  late ScreenCaptureProtection screenCapture;

  setUp(() {
    screenCapture = recordingScreenCaptureProtection();
    final store = MockIActiveConnectionStore();
    when(() => store.read(any())).thenAnswer((_) async => null);
    when(() => store.write(any(), any())).thenAnswer((_) async {});
    active = ActiveConnectionCubit(store: store)..select(postgres);
    repository = MockISqlEditorRepository();
    history = MockIStatementHistoryRepository();
    when(() => history.record(any(), any())).thenAnswer((invocation) async {
      final run = invocation.positionalArguments[1] as FinishedRun;
      return Success(
        StatementHistoryEntry(
          id: 'entry',
          connectionId: run.connectionId,
          connectionName: run.connectionName,
          text: run.text,
          status: run.status,
          duration: run.duration,
          executedAt: DateTime.utc(2026, 10, 23),
        ),
      );
    });
    textStore = MockIStatementTextStore();
    when(() => textStore.readDraft(any(), any())).thenAnswer((_) async => const Success(null));
    when(() => textStore.saveDraft(any(), any(), any())).thenAnswer((_) async => const Success(DraftSaveOutcome.kept));
    providerMeta = MockIProviderMetaRepository();
    when(() => providerMeta.providerMeta(postgres.id)).thenAnswer(
      (_) async => const Success(
        ProviderMeta(
          queryLanguage: 'sql',
          schemaRefreshPattern: 'DROP',
          containerLevels: [],
          objectKinds: [],
          supportsResultPagination: true,
        ),
      ),
    );
    schemaChanges = SchemaChangeNotifier(providerMeta: providerMeta, invalidateConnection: (_) {});
  });

  tearDown(() async {
    await schemaChanges.dispose();
    await active.close();
  });

  Future<GoRouter> pumpShell(
    WidgetTester tester, {
    // Studio named the account, so the editor's field is open; until it does the field is read only (#114).
    StudioIdentityState identityState = const StudioIdentityLoaded(
      StudioIdentity(username: 'ada', role: StudioUserRole(), subject: 'kc-ada'),
    ),
  }) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final identity = MockStudioIdentityCubit();
    whenListen(identity, const Stream<StudioIdentityState>.empty(), initialState: identityState);
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
      initialLocation: '/sql',
      routes: [
        ShellRoute(
          builder: (context, state, child) => AppShell(state: state, child: child),
          routes: [
            GoRoute(path: '/connections', builder: (_, _) => const Text('connections page')),
            GoRoute(path: '/browse', builder: (_, _) => const Text('browse root')),
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
          // The engine above declares no catalogSessions, so the editor never lists a server's databases here.
          RepositoryProvider<IContainersRepository>.value(value: MockIContainersRepository()),
          RepositoryProvider<IStatementHistoryRepository>.value(value: history),
          RepositoryProvider<IStatementTextStore>.value(value: textStore),
          RepositoryProvider<IAppLifecycleSource>(
            create: (_) => BindingAppLifecycleSource(),
            dispose: (source) => (source as BindingAppLifecycleSource).dispose(),
          ),
          RepositoryProvider<IBackgroundRunTime>.value(value: const NoBackgroundRunTime()),
          RepositoryProvider<ScreenCaptureProtection>.value(value: screenCapture),
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
    return router;
  }

  Future<void> openConfirmation(WidgetTester tester) async {
    await tester.enterText(find.byKey(EditorInput.fieldKey), 'DELETE FROM orders WHERE false');
    await tester.pump();
    await tester.tap(find.byKey(EditorActions.runKey));
    await tester.pumpAndSettle();
    expect(find.byType(WriteConfirmationSheet), findsOneWidget);
  }

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

  testWidgets('the confirmation covers the tab bar, so a tap on another tab changes nothing', (tester) async {
    final router = await pumpShell(tester);
    await openConfirmation(tester);

    await tester.tap(find.text('Browse'), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(router.state.uri.path, '/sql');
    expect(find.text('browse root'), findsNothing);
    expect(find.byKey(EditorInput.fieldKey), findsOneWidget);
    expect(active.state.connection, postgres);
    verifyNothingSent();
  });

  // On the SQL tab the top bar shows the active connection, which opens the switcher, and the profile button.
  testWidgets('the confirmation covers the top bar, so neither the switcher nor the profile sheet opens', (
    tester,
  ) async {
    final router = await pumpShell(tester);
    expect(find.byType(ActiveConnectionTitle), findsOneWidget);
    await openConfirmation(tester);

    await tester.tap(find.byType(ActiveConnectionTitle), warnIfMissed: false);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(profileButtonKey), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(router.state.uri.path, '/sql');
    expect(find.byType(ConnectionSwitcherSheet), findsNothing);
    expect(find.byType(ProfileSheet), findsNothing);
    expect(find.byKey(EditorInput.fieldKey), findsOneWidget);
    expect(active.state.connection, postgres);
    verifyNothingSent();
  });

  // The session ends while the sheet is open, as an inactivity sign-out or an ended Studio session does: the router
  // leaves the shell for the login page, which removes the editor and the sheet above it.
  testWidgets('a session that ends while the sheet is open sends nothing and adds nothing to the closed run', (
    tester,
  ) async {
    final router = await pumpShell(tester);
    await openConfirmation(tester);

    router.go('/login');
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('login page'), findsOneWidget);
    expect(find.byType(WriteConfirmationSheet), findsNothing);
    verifyNothingSent();
  });

  testWidgets('a deep link that leaves the tab while the Run sheet is open closes the sheet and sends nothing', (
    tester,
  ) async {
    final router = await pumpShell(tester);
    await openConfirmation(tester);

    router.go('/browse');
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('browse root'), findsOneWidget);
    expect(find.byType(WriteConfirmationSheet), findsNothing);
    verifyNothingSent();
  });

  // The tabs are routes of one ShellRoute: a tab change disposes the editor and its result, so nothing of it stays
  // mounted offstage to hold a lease, and the tab the user went to can be captured.
  testWidgets('a tap on another tab releases the lease of the result on screen', (tester) async {
    const read = 'SELECT * FROM customers';
    final rows = QueryResultJson.read(
      File('test/fixtures/studio/query_preview_postgres_customers.json').readAsStringSync(),
    );
    when(
      () => repository.run(
        any(),
        read,
        queryId: any(named: 'queryId'),
        page: any(named: 'page'),
        cancelSignal: any(named: 'cancelSignal'),
      ),
    ).thenAnswer((_) async => Success(rows));
    final router = await pumpShell(tester);
    expect(screenCapture.leases, 0, reason: 'the editor before a run stays capturable');
    await tester.enterText(find.byKey(EditorInput.fieldKey), read);
    await tester.pump();
    await tester.tap(find.byKey(EditorActions.runKey));
    await tester.pumpAndSettle();
    expect(screenCapture.leases, 1);

    await tester.tap(find.text('Browse'));
    await tester.pumpAndSettle();

    expect(router.state.uri.path, '/browse');
    expect(find.byKey(EditorInput.fieldKey, skipOffstage: false), findsNothing);
    expect(screenCapture.leases, 0);
    expect(screenCapture.isEngaged, isFalse);
  });

  testWidgets('a deep link that leaves the tab while the Load more sheet is open sends no page', (tester) async {
    const flagged = 'SELECT * FROM sales.ledger -- note: update';
    final first = QueryResultJson.read(File('test/fixtures/studio/query_page_postgres_first.json').readAsStringSync());
    when(
      () => repository.run(
        any(),
        flagged,
        queryId: any(named: 'queryId'),
        page: QueryPage.first,
        cancelSignal: any(named: 'cancelSignal'),
      ),
    ).thenAnswer((_) async => Success(first));
    when(
      () => repository.run(
        any(),
        flagged,
        queryId: any(named: 'queryId'),
        page: QueryPage.after(first.pagination!),
        cancelSignal: any(named: 'cancelSignal'),
      ),
    ).thenAnswer((_) async => Success(first));
    final router = await pumpShell(tester);
    await tester.enterText(find.byKey(EditorInput.fieldKey), flagged);
    await tester.pump();
    await tester.tap(find.byKey(EditorActions.runKey));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Run').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('result-load-more')));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Load 50 more'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(WriteConfirmationSheet), findsOneWidget);

    router.go('/browse');
    await tester.pumpAndSettle();
    // A sheet that outlived the editor would still take an answer here.
    if (find.byType(WriteConfirmationSheet).evaluate().isNotEmpty) {
      await tester.tap(find.widgetWithText(FilledButton, 'Run').last);
      await tester.pumpAndSettle();
    }

    expect(tester.takeException(), isNull);
    expect(find.byType(WriteConfirmationSheet), findsNothing);
    verifyNever(
      () => repository.run(
        any(),
        flagged,
        queryId: any(named: 'queryId'),
        page: QueryPage.after(first.pagination!),
        cancelSignal: any(named: 'cancelSignal'),
      ),
    );
  });

  Future<GoRouter> openHistory(WidgetTester tester) async {
    when(() => history.read(subjectHash('kc-ada'))).thenAnswer((_) async => const Success([]));
    final router = await pumpShell(
      tester,
      identityState: const StudioIdentityLoaded(
        StudioIdentity(username: 'ada', role: StudioUserRole(), subject: 'kc-ada'),
      ),
    );
    await tester.tap(find.byKey(EditorActions.historyKey));
    await tester.pumpAndSettle();
    expect(find.byType(StatementHistorySheet), findsOneWidget);
    return router;
  }

  testWidgets('a session that ends while the History sheet is open closes it with the editor', (tester) async {
    final router = await openHistory(tester);

    router.go('/login');
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('login page'), findsOneWidget);
    expect(find.byType(StatementHistorySheet), findsNothing);
  });

  testWidgets('a deep link that leaves the tab while the History sheet is open closes it', (tester) async {
    final router = await openHistory(tester);

    router.go('/browse');
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('browse root'), findsOneWidget);
    expect(find.byType(StatementHistorySheet), findsNothing);
  });

  testWidgets('a history write refused after the editor closed is still said, on the page the user went to', (
    tester,
  ) async {
    final answer = Completer<Result<QueryResult>>();
    when(
      () => repository.run(
        any(),
        any(),
        queryId: any(named: 'queryId'),
        page: any(named: 'page'),
        cancelSignal: any(named: 'cancelSignal'),
      ),
    ).thenAnswer((_) => answer.future);
    when(() => history.record(any(), any()))
        .thenAnswer((_) async => const Failure(UnknownError('Could not add', code: 'editor.saved_text_not_stored')));
    final router = await pumpShell(
      tester,
      identityState: const StudioIdentityLoaded(
        StudioIdentity(username: 'ada', role: StudioUserRole(), subject: 'kc-ada'),
      ),
    );
    await tester.enterText(find.byKey(EditorInput.fieldKey), 'SELECT 1');
    await tester.pump();
    await tester.tap(find.byKey(EditorActions.runKey));
    await tester.pump();

    router.go('/browse');
    await tester.pumpAndSettle();
    expect(find.byKey(EditorInput.fieldKey), findsNothing);
    answer.complete(
      const Success(QueryResult(fields: [], rows: [], rowCount: 0, executionTime: Duration(milliseconds: 1))),
    );
    await tester.pumpAndSettle();

    expect(find.text('browse root'), findsOneWidget);
    expect(
      find.text('This phone could not save the statement text. Check its free storage and try again.'),
      findsOneWidget,
    );
  });
}
