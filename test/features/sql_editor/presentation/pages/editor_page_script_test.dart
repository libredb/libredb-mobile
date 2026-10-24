@Tags(['widget'])
library;

import 'dart:async';
import 'dart:io';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/core/security/screen_capture_protection.dart';
import 'package:libredb_mobile/features/sql_editor/data/models/sql_editor_json.dart';
import 'package:libredb_mobile/features/sql_editor/domain/entities/script_result.dart';
import 'package:libredb_mobile/features/sql_editor/domain/entities/statement_draft.dart';
import 'package:libredb_mobile/features/sql_editor/domain/entities/statement_history_entry.dart';
import 'package:libredb_mobile/features/sql_editor/domain/repositories/sql_editor_repository.dart';
import 'package:libredb_mobile/features/sql_editor/domain/repositories/statement_history_repository.dart';
import 'package:libredb_mobile/features/sql_editor/domain/repositories/statement_text_store.dart';
import 'package:libredb_mobile/features/sql_editor/presentation/pages/sql_page.dart';
import 'package:libredb_mobile/features/sql_editor/presentation/widgets/editor_actions.dart';
import 'package:libredb_mobile/features/sql_editor/presentation/widgets/editor_input.dart';
import 'package:libredb_mobile/features/sql_editor/presentation/widgets/script_result_view.dart';
import 'package:libredb_mobile/features/sql_editor/presentation/widgets/write_confirmation_sheet.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/infrastructure/studio/provider_meta_json.dart';
import 'package:libredb_mobile/infrastructure/studio/query_result_json.dart';
import 'package:libredb_mobile/features/object_browser/data/models/object_browser_json.dart';
import 'package:libredb_mobile/shared/active_connection/active_catalog_cubit.dart';
import 'package:libredb_mobile/shared/active_connection/active_connection_cubit.dart';
import 'package:libredb_mobile/shared/models/answered.dart';
import 'package:libredb_mobile/shared/models/containers_repository.dart';
import 'package:libredb_mobile/shared/models/cancel_signal.dart';
import 'package:libredb_mobile/shared/models/provider_meta_repository.dart';
import 'package:libredb_mobile/shared/models/query_page.dart';
import 'package:libredb_mobile/shared/models/query_result.dart';
import 'package:libredb_mobile/shared/models/studio_connection.dart';
import 'package:libredb_mobile/shared/models/studio_identity.dart';
import 'package:libredb_mobile/shared/utils/schema_change_notifier.dart';
import 'package:libredb_mobile/shared/widgets/offline_status.dart';
import 'package:libredb_mobile/shared/widgets/result_view/result_view_mode_cubit.dart';
import 'package:libredb_mobile/shared/widgets/statement_capture.dart';
import 'package:libredb_mobile/shared/widgets/studio_role_scope.dart';
import 'package:libredb_mobile/shared/widgets/studio_subject_scope.dart';
import 'package:libredb_mobile/shared/utils/app_lifecycle_source.dart';
import 'package:libredb_mobile/shared/utils/background_run_time.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mock_classes.dart';
import '../../../../support/screen_capture.dart';

String _fixture(String name) => File('test/fixtures/studio/$name.json').readAsStringSync();

ScriptResult _recordedScript(String name) => SqlEditorJson.scriptResult(_fixture(name));

const _postgres = StudioConnection(
  id: 'seed:dev-postgres',
  name: 'Dev Postgres',
  type: 'postgres',
  environment: 'development',
);
const _server = StudioConnection(
  id: 'seed:dev-postgres-server',
  name: 'Dev Postgres server',
  type: 'postgres',
  environment: 'development',
);
const _production = StudioConnection(
  id: 'seed:dev-postgres-prod',
  name: 'Prod Postgres',
  type: 'postgres',
  environment: 'production',
);

/// A script answer that Studio rolled back, of statements that all succeeded or of one that failed.
ScriptResult _rolledBack({required bool failed}) => ScriptResult(
  statements: [
    const StatementResult(
      index: 0,
      sql: 'BEGIN',
      startLine: 0,
      executionTime: Duration(milliseconds: 1),
      rowCount: 0,
      result: QueryResult(fields: [], rows: [], rowCount: 0, executionTime: Duration(milliseconds: 1)),
    ),
    if (failed)
      const StatementResult(
        index: 1,
        sql: 'SELECT * FROM nope',
        startLine: 0,
        executionTime: Duration(milliseconds: 1),
        error: 'relation "nope" does not exist',
      ),
  ],
  statementCount: 2,
  executedCount: failed ? 2 : 1,
  executionTime: const Duration(milliseconds: 2),
  openTransactionRolledBack: true,
);

/// The SQL editor page with a script (#117): the routing to the script route, the cards, the not-run line, the rows
/// of a statement, the rolled-back notice, a selection, and the elapsed time and Cancel of a script that runs.
void main() {
  late ScreenCaptureProtection screenCapture;
  late MockISqlEditorRepository repository;
  late MockIProviderMetaRepository providerMeta;
  late MockActiveConnectionCubit active;
  late SchemaChangeNotifier schemaChanges;
  late MockIContainersRepository containers;
  late ActiveCatalogCubit catalog;
  late MockIStatementHistoryRepository history;
  late MockIStatementTextStore textStore;

  setUp(() {
    screenCapture = recordingScreenCaptureProtection();
    repository = MockISqlEditorRepository();
    providerMeta = MockIProviderMetaRepository();
    for (final connection in [_postgres, _production]) {
      when(() => providerMeta.providerMeta(connection.id))
          .thenAnswer((_) async => Success(ProviderMetaJson.read(_fixture('meta_postgres'))));
    }
    when(() => providerMeta.providerMeta(_server.id))
        .thenAnswer((_) async => Success(ProviderMetaJson.read(_fixture('meta_postgres_server'))));
    containers = MockIContainersRepository();
    final catalogStore = MockIActiveCatalogStore();
    when(() => catalogStore.read(any(), any())).thenAnswer((_) async => null);
    when(() => catalogStore.write(any(), any(), any())).thenAnswer((_) async {});
    catalog = ActiveCatalogCubit(store: catalogStore, connectionIds: const Stream.empty());
    active = MockActiveConnectionCubit();
    history = MockIStatementHistoryRepository();
    textStore = MockIStatementTextStore();
    when(() => textStore.readDraft(any(), any())).thenAnswer((_) async => const Success(null));
    when(() => textStore.saveDraft(any(), any(), any())).thenAnswer((_) async => const Success(DraftSaveOutcome.kept));
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
          rowCount: run.rowCount,
          executedAt: DateTime.utc(2026, 10, 23),
        ),
      );
    });
    schemaChanges = SchemaChangeNotifier(providerMeta: providerMeta, invalidateConnection: (_) {});
  });

  tearDown(() async {
    await schemaChanges.dispose();
    await catalog.close();
  });

  void answerScript(String sql, Result<ScriptResult> Function() answer) => when(
    () => repository.runScript(
      any(),
      sql,
      queryId: any(named: 'queryId'),
      catalog: any(named: 'catalog'),
      page: any(named: 'page'),
      cancelSignal: any(named: 'cancelSignal'),
    ),
  ).thenAnswer((_) async => answer());

  int scriptsOf(String sql) => verify(
    () => repository.runScript(
      any(),
      sql,
      queryId: any(named: 'queryId'),
      catalog: any(named: 'catalog'),
      page: any(named: 'page'),
      cancelSignal: any(named: 'cancelSignal'),
    ),
  ).callCount;

  void verifyNoScript() => verifyNever(
    () => repository.runScript(
      any(),
      any(),
      queryId: any(named: 'queryId'),
      catalog: any(named: 'catalog'),
      page: any(named: 'page'),
      cancelSignal: any(named: 'cancelSignal'),
    ),
  );

  /// [offline], when given, turns the device on and off line while the page is open; the page opens online otherwise.
  Future<void> pump(
    WidgetTester tester, {
    StudioConnection connection = _postgres,
    Locale? locale,
    ValueNotifier<bool>? offline,
  }) async {
    whenListen(active, const Stream<ActiveConnectionState>.empty(), initialState: ActiveConnectionSelected(connection));
    final offlineStatus = offline ?? ValueNotifier(false);
    if (offline == null) addTearDown(offlineStatus.dispose);
    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: [
          RepositoryProvider<ISqlEditorRepository>.value(value: repository),
          RepositoryProvider<IProviderMetaRepository>.value(value: providerMeta),
          RepositoryProvider<SchemaChangeNotifier>.value(value: schemaChanges),
          RepositoryProvider<IContainersRepository>.value(value: containers),
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
            BlocProvider<ActiveCatalogCubit>.value(value: catalog),
            BlocProvider<ResultViewModeCubit>(create: (_) => ResultViewModeCubit(store: MockIResultViewModeStore())),
          ],
          child: MaterialApp(
            locale: locale,
            localizationsDelegates: const [
              S.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: S.delegate.supportedLocales,
            home: Scaffold(
              body: StudioRoleScope(
                role: const StudioUserRole(),
                child: StudioSubjectScope(
                  subjectHash: 'account-hash',
                  child: StatementCaptureScope(
                    recordsInFull: false,
                    child: ValueListenableBuilder<bool>(
                      valueListenable: offlineStatus,
                      builder: (context, isOffline, _) => OfflineStatus(isOffline: isOffline, child: const SqlPage()),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Finder runButton() => find.byKey(EditorActions.runKey);

  Future<void> type(WidgetTester tester, String text) async {
    await tester.enterText(find.byKey(EditorInput.fieldKey), text);
    await tester.pump();
  }

  Future<void> runAndConfirm(WidgetTester tester) async {
    await tester.tap(runButton());
    await tester.pumpAndSettle();
    expect(find.byType(WriteConfirmationSheet), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Run').last);
    await tester.pumpAndSettle();
  }

  testWidgets(
    "a script with a failure shows a success card, a failure card with Postgres's words and the not-run line",
    (tester) async {
      const text = 'SELECT 1 AS a; SELECT * FROM nope; SELECT 3 AS c';
      answerScript(text, () => Success(_recordedScript('multi_postgres')));
      await pump(tester);
      await type(tester, text);

      await runAndConfirm(tester);

      final first = find.byKey(ScriptResultView.cardKey(0));
      expect(find.descendant(of: first, matching: find.text('Statement 1')), findsOneWidget);
      expect(find.descendant(of: first, matching: find.text('Succeeded')), findsOneWidget);
      expect(find.descendant(of: first, matching: find.text('SELECT 1 AS a')), findsOneWidget);
      expect(find.descendant(of: first, matching: find.text('1 row, 1 ms')), findsOneWidget);
      final second = find.byKey(ScriptResultView.cardKey(1));
      expect(find.descendant(of: second, matching: find.text('Statement 2')), findsOneWidget);
      expect(find.descendant(of: second, matching: find.text('Failed')), findsOneWidget);
      expect(find.descendant(of: second, matching: find.text('SELECT * FROM nope')), findsOneWidget);
      expect(find.descendant(of: second, matching: find.text('1 ms')), findsOneWidget);
      expect(find.descendant(of: second, matching: find.text('relation "nope" does not exist')), findsOneWidget);
      // Under the cards, which scroll above the open rows.
      expect(
        find.descendant(
          of: find.byKey(ScriptResultView.notRunKey, skipOffstage: false),
          matching: find.text('1 statement not run', skipOffstage: false),
        ),
        findsOneWidget,
      );
      expect(scriptsOf(text), 1);
      final entry = verify(() => history.record('account-hash', captureAny())).captured.single as FinishedRun;
      expect(entry.text, text);
      expect(entry.status, StatementRunStatus.failure);
    },
  );

  testWidgets('two SELECTs show two cards and the second result open, with no Load more', (tester) async {
    const text = 'SELECT 1 AS a; SELECT 2 AS b';
    answerScript(text, () => Success(_recordedScript('multi_postgres_rows')));
    await pump(tester);
    await type(tester, text);

    await runAndConfirm(tester);

    expect(find.byKey(ScriptResultView.cardKey(0)), findsOneWidget);
    expect(find.byKey(ScriptResultView.cardKey(1)), findsOneWidget);
    expect(find.byKey(ScriptResultView.notRunKey), findsNothing);
    // The open result's row, under the cards: a one-column row shows its value.
    expect(find.text('2'), findsOneWidget);
    expect(find.text('1'), findsNothing);
    expect(find.byKey(const ValueKey('result-load-more')), findsNothing);
  });

  testWidgets("a tap on another card opens that statement's rows", (tester) async {
    const text = 'SELECT 1 AS a; SELECT 2 AS b';
    answerScript(text, () => Success(_recordedScript('multi_postgres_rows')));
    await pump(tester);
    await type(tester, text);
    await runAndConfirm(tester);

    await tester.tap(find.byKey(ScriptResultView.cardKey(0)));
    await tester.pumpAndSettle();

    expect(find.text('1'), findsOneWidget);
    expect(find.text('2'), findsNothing);
    expect(scriptsOf(text), 1);
  });

  testWidgets("the open statement's rows hold one capture lease, and opening another card keeps one", (tester) async {
    const text = 'SELECT 1 AS a; SELECT 2 AS b';
    answerScript(text, () => Success(_recordedScript('multi_postgres_rows')));
    await pump(tester);
    await type(tester, text);
    expect(screenCapture.leases, 0);

    await runAndConfirm(tester);
    expect(screenCapture.leases, 1);

    await tester.tap(find.byKey(ScriptResultView.cardKey(0)));
    await tester.pumpAndSettle();
    expect(find.text('1'), findsOneWidget);
    expect(screenCapture.leases, 1);
  });

  testWidgets('a failed card opens no rows', (tester) async {
    const text = 'SELECT 1 AS a; SELECT * FROM nope; SELECT 3 AS c';
    answerScript(text, () => Success(_recordedScript('multi_postgres')));
    await pump(tester);
    await type(tester, text);
    await runAndConfirm(tester);
    expect(find.text('1'), findsOneWidget);

    await tester.ensureVisible(find.byKey(ScriptResultView.cardKey(1)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ScriptResultView.cardKey(1)));
    await tester.pumpAndSettle();

    expect(find.text('1'), findsOneWidget);
    expect(find.byKey(ScriptResultView.cardKey(1)), findsOneWidget);
  });

  testWidgets('a script on a server-level connection runs in the active database', (tester) async {
    const text = 'SELECT 1 AS a; SELECT 2 AS b';
    when(() => containers.containers(_server.id, refresh: any(named: 'refresh'))).thenAnswer(
      (_) async =>
          Success(Answered(ObjectBrowserJson.containers(_fixture('containers_postgres_server')), at: DateTime(2026))),
    );
    answerScript(text, () => Success(_recordedScript('multi_postgres_rows')));
    await pump(tester, connection: _server);
    await tester.pumpAndSettle();
    final active = catalog.catalogOf(_server.id);
    expect(active, isNotNull);
    await type(tester, text);

    await runAndConfirm(tester);

    verify(
      () => repository.runScript(
        _server.id,
        text,
        queryId: any(named: 'queryId'),
        catalog: active,
        page: QueryPage.first,
        cancelSignal: any(named: 'cancelSignal'),
      ),
    ).called(1);
  });

  group('the rolled-back notice', () {
    testWidgets('keeps the COMMIT advice when every statement succeeded', (tester) async {
      const text = 'BEGIN; SELECT 1';
      answerScript(text, () => Success(_rolledBack(failed: false)));
      await pump(tester);
      await type(tester, text);

      await runAndConfirm(tester);

      expect(
        find.text(
          'The script left a transaction open, and Studio rolled it back, so its changes were discarded. '
          'Add COMMIT to keep them.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('drops the advice when a statement failed', (tester) async {
      const text = 'BEGIN; SELECT * FROM nope';
      answerScript(text, () => Success(_rolledBack(failed: true)));
      await pump(tester);
      await type(tester, text);

      await runAndConfirm(tester);

      expect(
        find.text('The script left a transaction open, and Studio rolled it back, so its changes were discarded.'),
        findsOneWidget,
      );
      expect(find.textContaining('to keep them'), findsNothing);
    });
  });

  testWidgets('a script with DELETE on line 3 names it, and on production needs the typed name', (tester) async {
    const text = 'SELECT 1;\nSELECT 2;\nDELETE FROM orders WHERE false';
    answerScript(text, () => Success(_recordedScript('multi_postgres_rows')));
    await pump(tester, connection: _production);
    await type(tester, text);

    await tester.tap(runButton());
    await tester.pumpAndSettle();

    expect(find.byType(WriteConfirmationSheet), findsOneWidget);
    expect(find.textContaining('DELETE'), findsWidgets);
    expect(find.textContaining('line 3'), findsOneWidget);
    final sheetRun = find.widgetWithText(FilledButton, 'Run').last;
    expect(tester.widget<FilledButton>(sheetRun).enabled, isFalse);
    await tester.enterText(find.byKey(WriteConfirmationSheet.nameFieldKey), 'Prod Postgres');
    await tester.pump();
    await tester.tap(sheetRun);
    await tester.pumpAndSettle();

    expect(scriptsOf(text), 1);
  });

  group('a selection', () {
    void answerRun(String sql, QueryResult result) => when(
      () => repository.run(
        any(),
        sql,
        queryId: any(named: 'queryId'),
        page: any(named: 'page'),
        cancelSignal: any(named: 'cancelSignal'),
      ),
    ).thenAnswer((_) async => Success(result));

    testWidgets('Run reads Run selection, and sends only the selection, through run', (tester) async {
      const text = 'SELECT 1; SELECT * FROM sales.ledger;';
      answerRun('SELECT * FROM sales.ledger;', QueryResultJson.read(_fixture('query_page_postgres_first')));
      await pump(tester);
      await type(tester, text);
      expect(find.descendant(of: runButton(), matching: find.text('Run')), findsOneWidget);

      final field = tester.widget<TextField>(find.byKey(EditorInput.fieldKey));
      field.controller!.selection = TextSelection(baseOffset: 10, extentOffset: text.length);
      await tester.pump();
      expect(find.descendant(of: runButton(), matching: find.text('Run selection')), findsOneWidget);

      await tester.tap(runButton());
      await tester.pumpAndSettle();

      expect(find.byType(WriteConfirmationSheet), findsNothing);
      expect(find.byKey(const ValueKey('result-load-more')), findsOneWidget);
      verify(
        () => repository.run(
          any(),
          'SELECT * FROM sales.ledger;',
          queryId: any(named: 'queryId'),
          page: QueryPage.first,
          cancelSignal: any(named: 'cancelSignal'),
        ),
      ).called(1);
      verifyNoScript();
    });

    testWidgets('a blank selection runs the whole text', (tester) async {
      const text = 'SELECT 1;   SELECT 2';
      answerScript(text, () => Success(_recordedScript('multi_postgres_rows')));
      await pump(tester);
      await type(tester, text);
      final field = tester.widget<TextField>(find.byKey(EditorInput.fieldKey));
      field.controller!.selection = const TextSelection(baseOffset: 9, extentOffset: 12);
      await tester.pump();
      expect(find.descendant(of: runButton(), matching: find.text('Run')), findsOneWidget);

      await runAndConfirm(tester);

      expect(scriptsOf(text), 1);
    });

    testWidgets("a database error in the selection places the cursor in the field's text", (tester) async {
      const text = 'SELECT 1;\nSELECT 1 FORM t';
      when(
        () => repository.run(
          any(),
          'SELECT 1 FORM t',
          queryId: any(named: 'queryId'),
          page: any(named: 'page'),
          cancelSignal: any(named: 'cancelSignal'),
        ),
      ).thenAnswer(
        (_) async =>
            const Failure(ValidationError('syntax error at or near "FORM"', code: 'studio.query_error', position: 10)),
      );
      await pump(tester);
      await type(tester, text);
      final field = tester.widget<TextField>(find.byKey(EditorInput.fieldKey));
      field.controller!.selection = TextSelection(baseOffset: 10, extentOffset: text.length);
      await tester.pump();

      await tester.tap(runButton());
      await tester.pumpAndSettle();

      expect(field.controller!.selection, const TextSelection.collapsed(offset: 19));
    });
  });

  group('while a script runs', () {
    const text = 'SELECT pg_sleep(40); SELECT pg_sleep(40)';

    /// Holds the script until the returned completer answers, or fails it as cancelled once its request is dropped.
    Completer<Result<ScriptResult>> holdScript() {
      final answer = Completer<Result<ScriptResult>>();
      when(
        () => repository.runScript(
          any(),
          text,
          queryId: any(named: 'queryId'),
          catalog: any(named: 'catalog'),
          page: any(named: 'page'),
          cancelSignal: any(named: 'cancelSignal'),
        ),
      ).thenAnswer((invocation) {
        final signal = invocation.namedArguments[#cancelSignal] as CancelSignal?;
        return Future.any([
          answer.future,
          if (signal != null)
            signal.whenCancelled.then((_) => const Failure<ScriptResult>(RequestCancelledError('Request cancelled'))),
        ]);
      });
      return answer;
    }

    Future<void> start(WidgetTester tester, {Locale? locale, ValueNotifier<bool>? offline}) async {
      await pump(tester, locale: locale, offline: offline);
      await type(tester, text);
      await tester.tap(runButton());
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, locale == null ? 'Run' : 'Çalıştır').last);
      // The run's spinner never settles, so the sheet's exit is pumped.
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
    }

    testWidgets('shows the elapsed time, and the answer after about 80 s', (tester) async {
      final answer = holdScript();
      await start(tester);

      expect(find.byKey(ScriptElapsedTime.textKey), findsOneWidget);
      await tester.pump(const Duration(seconds: 64));
      expect(find.text('Running for 1:05'), findsOneWidget);
      await tester.pump(const Duration(seconds: 15));
      expect(find.text('Running for 1:20'), findsOneWidget);

      answer.complete(Success(_recordedScript('multi_postgres_rows')));
      await tester.pumpAndSettle();

      expect(find.byKey(ScriptElapsedTime.textKey), findsNothing);
      expect(find.byKey(ScriptResultView.cardKey(1)), findsOneWidget);
      expect(scriptsOf(text), 1);
    });

    testWidgets('Cancel stops it and says Cancelled', (tester) async {
      holdScript();
      when(() => repository.cancel(any(), any())).thenAnswer((_) async => const Success(true));
      await start(tester);

      expect(find.descendant(of: runButton(), matching: find.text('Cancel')), findsOneWidget);
      await tester.tap(runButton());
      await tester.pumpAndSettle();

      expect(find.text('Cancelled'), findsOneWidget);
      expect(find.byKey(ScriptElapsedTime.textKey), findsNothing);
      verify(() => repository.cancel(_postgres.id, any())).called(1);
      expect(scriptsOf(text), 1);
    });

    testWidgets('offline, Cancel is disabled with the reason and posts no cancel until the device is back', (
      tester,
    ) async {
      holdScript();
      when(() => repository.cancel(any(), any())).thenAnswer((_) async => const Success(true));
      final offline = ValueNotifier(false);
      addTearDown(offline.dispose);
      await start(tester, offline: offline);
      offline.value = true;
      await tester.pump();

      expect(tester.widget<ButtonStyleButton>(runButton()).enabled, isFalse);
      expect(find.text('Needs an internet connection'), findsOneWidget);
      await tester.tap(runButton(), warnIfMissed: false);
      await tester.pump();
      verifyNever(() => repository.cancel(any(), any()));

      offline.value = false;
      await tester.pump();
      expect(find.text('Needs an internet connection'), findsNothing);
      await tester.tap(runButton());
      await tester.pumpAndSettle();

      expect(find.text('Cancelled'), findsOneWidget);
      verify(() => repository.cancel(_postgres.id, any())).called(1);
    });

    testWidgets('the elapsed time is in Turkish', (tester) async {
      final answer = holdScript();
      await start(tester, locale: const Locale('tr'));

      await tester.pump(const Duration(seconds: 4));
      expect(find.text('0:05 süredir çalışıyor'), findsOneWidget);
      answer.complete(Success(_recordedScript('multi_postgres_rows')));
      await tester.pumpAndSettle();
      expect(find.text('Deyim 1'), findsOneWidget);
      expect(find.text('Başarılı'), findsNWidgets(2));
    });
  });
}
