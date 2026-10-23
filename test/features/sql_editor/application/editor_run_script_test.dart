import 'dart:async';
import 'dart:io';
import 'dart:ui' show AppLifecycleState;

import 'package:bloc_test/bloc_test.dart';
import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/sql_editor/application/editor_run_bloc.dart';
import 'package:libredb_mobile/features/sql_editor/domain/entities/script_result.dart';
import 'package:libredb_mobile/features/sql_editor/domain/entities/statement_history_entry.dart';
import 'package:libredb_mobile/features/sql_editor/domain/repositories/statement_history_repository.dart';
import 'package:libredb_mobile/features/sql_editor/domain/interim_write_check.dart';
import 'package:libredb_mobile/infrastructure/studio/provider_meta_json.dart';
import 'package:libredb_mobile/infrastructure/studio/query_result_json.dart';
import 'package:libredb_mobile/shared/models/cancel_signal.dart';
import 'package:libredb_mobile/shared/models/query_page.dart';
import 'package:libredb_mobile/shared/models/query_result.dart';
import 'package:libredb_mobile/shared/models/studio_identity.dart';
import 'package:libredb_mobile/shared/security/result_masking/masking_policy.dart';
import 'package:libredb_mobile/shared/utils/app_lifecycle_source.dart';
import 'package:libredb_mobile/shared/utils/background_run_time.dart';
import 'package:libredb_mobile/shared/utils/schema_change_notifier.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mock_classes.dart';

String _fixture(String name) => File('test/fixtures/studio/$name.json').readAsStringSync();

const _postgres = 'seed:dev-postgres';
const _redis = 'seed:dev-redis';
const _trino = 'seed:dev-trino';
const _user = StudioUserRole();

/// An app that stays on screen; backgrounding is tested in editor_run_background_test.dart.
class _OnScreen implements IAppLifecycleSource {
  const _OnScreen();

  @override
  AppLifecycleState? get current => AppLifecycleState.resumed;

  @override
  Stream<AppLifecycleState> get changes => const Stream.empty();
}

/// A script answer of [statements], of which Studio found [statementCount].
ScriptResult _script(List<StatementResult> statements, {int? statementCount, bool rolledBack = false}) => ScriptResult(
  statements: statements,
  statementCount: statementCount ?? statements.length,
  executedCount: statements.length,
  executionTime: const Duration(milliseconds: 5),
  openTransactionRolledBack: rolledBack,
);

StatementResult _success(int index, String sql, QueryResult result) => StatementResult(
  index: index,
  sql: sql,
  startLine: index,
  executionTime: const Duration(milliseconds: 2),
  rowCount: result.rowCount,
  result: result,
);

const _noRows = QueryResult(fields: ['n'], rows: [], rowCount: 0, executionTime: Duration(milliseconds: 1));

StatementResult _failure(int index, String sql) => StatementResult(
  index: index,
  sql: sql,
  startLine: index,
  executionTime: const Duration(milliseconds: 1),
  error: 'relation "nope" does not exist',
);

/// The script run (#117): a SQL text the check reads as several statements goes to `runScript`, after the
/// confirmation every script asks; anything else goes to `run`, a non-SQL text whole.
void main() {
  late MockISqlEditorRepository repository;
  late MockIProviderMetaRepository providerMeta;
  late SchemaChangeNotifier schemaChanges;
  late List<String> changedStatements;
  late MockIStatementHistoryRepository history;
  final customers = QueryResultJson.read(_fixture('query_preview_postgres_customers'));
  final postgresMeta = ProviderMetaJson.read(_fixture('meta_postgres'));
  // A SQL engine whose grammar takes no terminator, as Trino declares.
  final noTerminatorMeta = ProviderMetaJson.read(
    _fixture('meta_postgres').replaceFirst('"capabilities":{', '"capabilities":{"statementTerminator":"none",'),
  );
  var ids = 0;

  setUp(() {
    ids = 0;
    repository = MockISqlEditorRepository();
    providerMeta = MockIProviderMetaRepository();
    when(() => providerMeta.providerMeta(_postgres)).thenAnswer((_) async => Success(postgresMeta));
    when(() => providerMeta.providerMeta(_trino)).thenAnswer((_) async => Success(noTerminatorMeta));
    when(() => providerMeta.providerMeta(_redis))
        .thenAnswer((_) async => Success(ProviderMetaJson.read(_fixture('meta_redis'))));
    changedStatements = [];
    history = MockIStatementHistoryRepository();
    when(() => history.record(any(), any())).thenAnswer(
      (_) async => Success(
        StatementHistoryEntry(
          id: 'entry',
          connectionId: _postgres,
          connectionName: 'Dev Postgres',
          text: 'x',
          status: StatementRunStatus.success,
          duration: Duration.zero,
          executedAt: DateTime.utc(2026, 10, 23),
        ),
      ),
    );
    schemaChanges = _RecordingSchemaChanges(providerMeta, changedStatements);
  });

  tearDown(() => schemaChanges.dispose());

  EditorRunBloc build({String connectionId = _postgres}) => EditorRunBloc(
    repository: repository,
    providerMeta: providerMeta,
    schemaChanges: schemaChanges,
    history: history,
    onHistoryNotKept: (_) {},
    lifecycle: const _OnScreen(),
    backgroundRunTime: const NoBackgroundRunTime(),
    connectionId: connectionId,
    newRunId: () => 'run-${++ids}',
  );

  void answerRun(Result<QueryResult> Function() answer) => when(
    () => repository.run(
      any(),
      any(),
      queryId: any(named: 'queryId'),
      page: any(named: 'page'),
      cancelSignal: any(named: 'cancelSignal'),
    ),
  ).thenAnswer((_) async => answer());

  void answerScript(Result<ScriptResult> Function() answer) => when(
    () => repository.runScript(
      any(),
      any(),
      queryId: any(named: 'queryId'),
      catalog: any(named: 'catalog'),
      page: any(named: 'page'),
      cancelSignal: any(named: 'cancelSignal'),
    ),
  ).thenAnswer((_) async => answer());

  List<String> sentRuns() => verify(
    () => repository.run(
      any(),
      captureAny(),
      queryId: any(named: 'queryId'),
      page: any(named: 'page'),
      cancelSignal: any(named: 'cancelSignal'),
    ),
  ).captured.cast<String>();

  List<String> sentScripts() => verify(
    () => repository.runScript(
      any(),
      captureAny(),
      queryId: any(named: 'queryId'),
      catalog: any(named: 'catalog'),
      page: any(named: 'page'),
      cancelSignal: any(named: 'cancelSignal'),
    ),
  ).captured.cast<String>();

  void verifyNoRun() => verifyNever(
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

  const target = EditorHistoryTarget(subjectHash: 'account-hash', connectionName: 'Dev Postgres');

  /// Runs [text] and answers the confirmation it asks with yes.
  Future<void> runConfirmed(EditorRunBloc bloc, String text, {bool isSelection = false}) async {
    bloc.add(EditorRunRequested(text: text, role: _user, isSelection: isSelection, history: target));
    await Future<void>.delayed(Duration.zero);
    bloc.add(const EditorConfirmationAnswered(confirmed: true));
  }

  group('routing', () {
    blocTest<EditorRunBloc, EditorRunState>(
      'a SQL text of several statements asks, as a script, and sends nothing first',
      build: build,
      act: (bloc) => bloc.add(const EditorRunRequested(text: 'SELECT 1; SELECT 2', role: _user)),
      expect: () => [
        isA<EditorAwaitingConfirmation>()
            .having((s) => s.statement.text, 'text', 'SELECT 1; SELECT 2')
            .having((s) => s.statement.isScript, 'script', isTrue)
            .having((s) => s.asks.reasons, 'reasons', {WriteCheckReason.severalStatements}),
      ],
      verify: (_) {
        verifyNoRun();
        verifyNoScript();
      },
    );

    blocTest<EditorRunBloc, EditorRunState>(
      'a confirmed script goes to runScript once, with the first page, the run id and a cancel signal',
      setUp: () => answerScript(() => Success(_script([_success(0, 'SELECT 1', customers)]))),
      build: build,
      act: (bloc) => runConfirmed(bloc, 'SELECT 1; SELECT 2'),
      expect: () => [
        isA<EditorAwaitingConfirmation>(),
        const EditorRunning(queryId: 'run-1', supportsCancel: true),
        isA<EditorScriptAnswered>()
            .having((s) => s.statement.text, 'text', 'SELECT 1; SELECT 2')
            .having((s) => s.statement.isScript, 'script', isTrue)
            .having((s) => s.run, 'run', 1),
      ],
      verify: (_) {
        final call = verify(
          () => repository.runScript(
            _postgres,
            'SELECT 1; SELECT 2',
            queryId: 'run-1',
            page: QueryPage.first,
            cancelSignal: captureAny(named: 'cancelSignal'),
          ),
        );
        call.called(1);
        expect(call.captured.single, isA<CancelSignal>());
        verifyNoRun();
      },
    );

    blocTest<EditorRunBloc, EditorRunState>(
      'a script runs in the database Run named',
      setUp: () => answerScript(() => Success(_script([_success(0, 'SELECT 1', customers)]))),
      build: build,
      act: (bloc) async {
        bloc.add(const EditorRunRequested(text: 'SELECT 1; SELECT 2', role: _user, catalog: 'archive'));
        await Future<void>.delayed(Duration.zero);
        bloc.add(const EditorConfirmationAnswered(confirmed: true));
      },
      skip: 2,
      expect: () => [isA<EditorScriptAnswered>().having((s) => s.statement.catalog, 'catalog', 'archive')],
      verify: (_) => verify(
        () => repository.runScript(
          _postgres,
          'SELECT 1; SELECT 2',
          queryId: 'run-1',
          catalog: 'archive',
          page: QueryPage.first,
          cancelSignal: any(named: 'cancelSignal'),
        ),
      ).called(1),
    );

    blocTest<EditorRunBloc, EditorRunState>(
      'a line holding only GO makes a script',
      setUp: () => answerScript(() => Success(_script([_success(0, 'SELECT 1', customers)]))),
      build: build,
      act: (bloc) => runConfirmed(bloc, 'SELECT 1\nGO\nSELECT 2'),
      skip: 2,
      expect: () => [isA<EditorScriptAnswered>()],
      verify: (_) => expect(sentScripts(), ['SELECT 1\nGO\nSELECT 2']),
    );

    blocTest<EditorRunBloc, EditorRunState>(
      'a dollar-quoted function body with a ; inside asks, then runs through the script route',
      setUp: () => answerScript(() => Success(_script([_success(0, 'CREATE FUNCTION', customers)]))),
      build: build,
      act: (bloc) =>
          runConfirmed(bloc, r'CREATE FUNCTION one() RETURNS int AS $$ BEGIN RETURN 1; END $$ LANGUAGE plpgsql'),
      expect: () => [
        isA<EditorAwaitingConfirmation>().having((s) => s.asks.reasons, 'reasons', {
          WriteCheckReason.mayWrite,
          WriteCheckReason.severalStatements,
        }),
        isA<EditorRunning>(),
        isA<EditorScriptAnswered>(),
      ],
      verify: (_) => verifyNoRun(),
    );

    blocTest<EditorRunBloc, EditorRunState>(
      'a text the check reads as one statement goes to run',
      setUp: () => answerRun(() => Success(customers)),
      build: build,
      act: (bloc) => bloc.add(const EditorRunRequested(text: 'SELECT 1;', role: _user)),
      expect: () => [isA<EditorRunning>(), isA<EditorSucceeded>()],
      verify: (_) {
        expect(sentRuns(), ['SELECT 1;']);
        verifyNoScript();
      },
    );

    blocTest<EditorRunBloc, EditorRunState>(
      'a Redis text with ; asks as not SQL and is sent whole through run, never split',
      setUp: () => answerRun(() => Success(customers)),
      build: () => build(connectionId: _redis),
      act: (bloc) => runConfirmed(bloc, 'SET a 1; GET a'),
      expect: () => [
        isA<EditorAwaitingConfirmation>().having((s) => s.statement.isScript, 'script', isFalse).having(
          (s) => s.asks.reasons,
          'reasons',
          {WriteCheckReason.notSql},
        ),
        isA<EditorRunning>(),
        isA<EditorSucceeded>(),
      ],
      verify: (_) {
        expect(sentRuns(), ['SET a 1; GET a']);
        verifyNoScript();
      },
    );
  });

  group('a selection', () {
    blocTest<EditorRunBloc, EditorRunState>(
      'of one statement is sent alone through run',
      setUp: () => answerRun(() => Success(customers)),
      build: build,
      act: (bloc) => bloc.add(const EditorRunRequested(text: 'SELECT 2', role: _user, isSelection: true)),
      expect: () => [isA<EditorRunning>(), isA<EditorSucceeded>().having((s) => s.statement.text, 'text', 'SELECT 2')],
      verify: (_) {
        expect(sentRuns(), ['SELECT 2']);
        verifyNoScript();
      },
    );

    blocTest<EditorRunBloc, EditorRunState>(
      'of several statements is a script',
      setUp: () => answerScript(() => Success(_script([_success(0, 'SELECT 2', customers)]))),
      build: build,
      act: (bloc) => runConfirmed(bloc, 'SELECT 2; SELECT 3', isSelection: true),
      skip: 2,
      expect: () => [isA<EditorScriptAnswered>()],
      verify: (_) => expect(sentScripts(), ['SELECT 2; SELECT 3']),
    );

    blocTest<EditorRunBloc, EditorRunState>(
      'of one statement on an engine whose terminator is none is sent without its trailing ;',
      setUp: () => answerRun(() => Success(customers)),
      build: () => build(connectionId: _trino),
      act: (bloc) => bloc.add(const EditorRunRequested(text: 'SELECT 2 ;  \n', role: _user, isSelection: true)),
      expect: () => [isA<EditorRunning>(), isA<EditorSucceeded>().having((s) => s.statement.text, 'text', 'SELECT 2')],
      verify: (_) => expect(sentRuns(), ['SELECT 2']),
    );

    blocTest<EditorRunBloc, EditorRunState>(
      'on an engine whose terminator is none keeps its ; when it is the whole text',
      setUp: () => answerRun(() => Success(customers)),
      build: () => build(connectionId: _trino),
      act: (bloc) => bloc.add(const EditorRunRequested(text: 'SELECT 2;', role: _user)),
      skip: 1,
      expect: () => [isA<EditorSucceeded>()],
      verify: (_) => expect(sentRuns(), ['SELECT 2;']),
    );

    blocTest<EditorRunBloc, EditorRunState>(
      'of one statement on an engine with a terminator keeps its ;',
      setUp: () => answerRun(() => Success(customers)),
      build: build,
      act: (bloc) => bloc.add(const EditorRunRequested(text: 'SELECT 2;', role: _user, isSelection: true)),
      skip: 1,
      expect: () => [isA<EditorSucceeded>()],
      verify: (_) => expect(sentRuns(), ['SELECT 2;']),
    );

    blocTest<EditorRunBloc, EditorRunState>(
      'of several statements on an engine whose terminator is none is sent as selected',
      setUp: () => answerScript(() => Success(_script([_success(0, 'SELECT 2', customers)]))),
      build: () => build(connectionId: _trino),
      act: (bloc) => runConfirmed(bloc, 'SELECT 2; SELECT 3;', isSelection: true),
      skip: 2,
      expect: () => [isA<EditorScriptAnswered>()],
      verify: (_) => expect(sentScripts(), ['SELECT 2; SELECT 3;']),
    );
  });

  group('the confirmation of a script', () {
    const script = 'SELECT 1;\nSELECT 2;\nDELETE FROM orders WHERE false';

    blocTest<EditorRunBloc, EditorRunState>(
      'names DELETE on line 3 with both reasons',
      build: build,
      act: (bloc) => bloc.add(const EditorRunRequested(text: script, role: _user)),
      expect: () => [
        isA<EditorAwaitingConfirmation>()
            .having((s) => s.asks.reasons, 'reasons', {WriteCheckReason.mayWrite, WriteCheckReason.severalStatements})
            .having((s) => s.asks.flaggedWord, 'word', const FlaggedWord(word: 'DELETE', line: 3)),
      ],
    );

    blocTest<EditorRunBloc, EditorRunState>(
      'declined sends nothing and restores what was on screen',
      build: build,
      act: (bloc) async {
        bloc.add(const EditorRunRequested(text: script, role: _user));
        await Future<void>.delayed(Duration.zero);
        bloc.add(const EditorConfirmationAnswered(confirmed: false));
      },
      expect: () => [isA<EditorAwaitingConfirmation>(), const EditorIdle()],
      verify: (_) {
        verifyNoRun();
        verifyNoScript();
      },
    );

    blocTest<EditorRunBloc, EditorRunState>(
      'sends the confirmed text, whatever is asked for while the sheet is open',
      setUp: () => answerScript(() => Success(_script([_success(0, 'SELECT 1', customers)]))),
      build: build,
      act: (bloc) async {
        bloc.add(const EditorRunRequested(text: script, role: _user));
        await Future<void>.delayed(Duration.zero);
        bloc.add(const EditorRunRequested(text: 'DROP TABLE orders; SELECT 1', role: _user));
        await Future<void>.delayed(Duration.zero);
        bloc.add(const EditorConfirmationAnswered(confirmed: true));
      },
      skip: 2,
      expect: () => [isA<EditorScriptAnswered>().having((s) => s.statement.text, 'text', script)],
      verify: (_) {
        expect(sentScripts(), [script]);
        verifyNoRun();
      },
    );
  });

  group('the answer of a script', () {
    blocTest<EditorRunBloc, EditorRunState>(
      'masks every statement with the policy of the run and keeps the counts and the failure',
      setUp: () => answerScript(
        () => Success(
          _script(
            [_success(0, 'SELECT * FROM customers', customers), _failure(1, 'SELECT * FROM nope')],
            statementCount: 3,
            rolledBack: true,
          ),
        ),
      ),
      build: build,
      act: (bloc) => runConfirmed(bloc, 'SELECT * FROM customers; SELECT * FROM nope; SELECT 3'),
      skip: 2,
      expect: () => [
        isA<EditorScriptAnswered>()
            .having((s) => s.policy, 'policy', MaskingPolicy.forRole(_user))
            .having((s) => s.statementCount, 'statement count', 3)
            .having((s) => s.executedCount, 'executed count', 2)
            .having((s) => s.notRun, 'not run', 1)
            .having((s) => s.hasError, 'has error', isTrue)
            .having((s) => s.openTransactionRolledBack, 'rolled back', isTrue)
            .having((s) => s.commitKeyword, 'commit keyword', 'COMMIT')
            .having((s) => s.statements.first.masked?.maskedColumns, 'masked columns', contains('email'))
            .having(
              (s) => s.statements.first.masked?.result.rows.first['email'],
              'masked email',
              isNot('ada@example.com'),
            )
            .having((s) => s.statements.first.rowCount, 'row count', customers.rowCount)
            .having((s) => s.statements.last.masked, 'failed rows', isNull)
            .having((s) => s.statements.last.error, 'error', 'relation "nope" does not exist')
            .having((s) => s.statements.last.index, 'index', 1)
            .having((s) => s.statements.last.sql, 'sql', 'SELECT * FROM nope'),
      ],
    );

    blocTest<EditorRunBloc, EditorRunState>(
      'tells the schema notifier each successful statement, and no failed one',
      setUp: () => answerScript(
        () => Success(
          _script([
            _success(0, 'CREATE TABLE a (n int)', customers),
            _success(1, 'SELECT 1', customers),
            _failure(2, 'SELECT * FROM nope'),
          ]),
        ),
      ),
      build: build,
      act: (bloc) => runConfirmed(bloc, 'CREATE TABLE a (n int); SELECT 1; SELECT * FROM nope'),
      skip: 3,
      verify: (_) => expect(changedStatements, ['CREATE TABLE a (n int)', 'SELECT 1']),
    );

    blocTest<EditorRunBloc, EditorRunState>(
      'a script whose first statement failed tells the notifier nothing',
      setUp: () => answerScript(() => Success(_script([_failure(0, 'SELECT * FROM nope')], statementCount: 2))),
      build: build,
      act: (bloc) => runConfirmed(bloc, 'SELECT * FROM nope; SELECT 1'),
      skip: 3,
      verify: (_) => expect(changedStatements, isEmpty),
    );

    blocTest<EditorRunBloc, EditorRunState>(
      'a failed request is shown and never sent again',
      setUp: () => answerScript(() => const Failure(ServerError('down', code: 'studio.database_unreachable'))),
      build: build,
      act: (bloc) => runConfirmed(bloc, 'SELECT 1; SELECT 2'),
      skip: 2,
      expect: () => [isA<EditorFailed>().having((s) => s.error.code, 'code', 'studio.database_unreachable')],
      verify: (_) {
        expect(sentScripts(), hasLength(1));
        expect(changedStatements, isEmpty);
      },
    );
  });

  group('the history', () {
    List<FinishedRun> recorded() =>
        verify(() => history.record('account-hash', captureAny())).captured.cast<FinishedRun>();

    blocTest<EditorRunBloc, EditorRunState>(
      'a script that ran clean is one Succeeded entry for its whole text, with the row count Studio shows',
      setUp: () => answerScript(
        () => Success(_script([_success(0, 'SELECT * FROM customers', customers), _success(1, 'SELECT 2', _noRows)])),
      ),
      build: build,
      act: (bloc) => runConfirmed(bloc, 'SELECT * FROM customers; SELECT 2'),
      skip: 2,
      verify: (_) => expect(recorded(), [
        FinishedRun(
          connectionId: _postgres,
          connectionName: 'Dev Postgres',
          text: 'SELECT * FROM customers; SELECT 2',
          status: StatementRunStatus.success,
          duration: const Duration(milliseconds: 5),
          rowCount: customers.rowCount,
        ),
      ]),
    );

    blocTest<EditorRunBloc, EditorRunState>(
      'a script with a failed statement is one Failed entry without the error text',
      setUp: () =>
          answerScript(() => Success(_script([_success(0, 'SELECT 1', customers), _failure(1, 'SELECT * FROM nope')]))),
      build: build,
      act: (bloc) => runConfirmed(bloc, 'SELECT 1; SELECT * FROM nope'),
      skip: 2,
      verify: (_) {
        final [entry] = recorded();
        expect(entry.status, StatementRunStatus.failure);
        expect(entry.text, 'SELECT 1; SELECT * FROM nope');
        expect(entry.rowCount, isNull);
        expect(entry.toString(), isNot(contains('nope')));
      },
    );

    blocTest<EditorRunBloc, EditorRunState>(
      'a script that never reached Studio writes nothing',
      setUp: () => answerScript(() => const Failure(NetworkError('offline'))),
      build: build,
      act: (bloc) => runConfirmed(bloc, 'SELECT 1; SELECT 2'),
      skip: 2,
      verify: (_) => verifyNever(() => history.record(any(), any())),
    );

    blocTest<EditorRunBloc, EditorRunState>(
      'a script Studio refused is one Failed entry',
      setUp: () => answerScript(() => const Failure(ServerError('down', code: 'studio.database_unreachable'))),
      build: build,
      act: (bloc) => runConfirmed(bloc, 'SELECT 1; SELECT 2'),
      skip: 2,
      verify: (_) => expect(recorded().single.status, StatementRunStatus.failure),
    );
  });

  group('while a script runs', () {
    late Completer<Result<ScriptResult>> scriptAnswer;
    late List<CancelSignal?> signals;

    setUp(() {
      scriptAnswer = Completer();
      signals = [];
      when(
        () => repository.runScript(
          any(),
          any(),
          queryId: any(named: 'queryId'),
          catalog: any(named: 'catalog'),
          page: any(named: 'page'),
          cancelSignal: any(named: 'cancelSignal'),
        ),
      ).thenAnswer((invocation) {
        final signal = invocation.namedArguments[#cancelSignal] as CancelSignal?;
        signals.add(signal);
        return Future.any([
          scriptAnswer.future,
          if (signal != null)
            signal.whenCancelled.then((_) => const Failure<ScriptResult>(RequestCancelledError('Request cancelled'))),
        ]);
      });
    });

    test('the bloc holds when it started, for the elapsed time, until it answers', () async {
      final started = DateTime.utc(2026, 10, 23, 12);
      final bloc = withClock(Clock.fixed(started), build);
      addTearDown(bloc.close);

      expect(bloc.scriptStartedAt, isNull);
      await withClock(Clock.fixed(started), () async {
        await runConfirmed(bloc, 'SELECT pg_sleep(40); SELECT pg_sleep(40)');
        await pumpEventQueue();
      });
      expect(bloc.state, isA<EditorRunning>());
      expect(bloc.scriptStartedAt, started);

      scriptAnswer.complete(Success(_script([_success(0, 'SELECT pg_sleep(40)', customers)])));
      await pumpEventQueue();
      expect(bloc.state, isA<EditorScriptAnswered>());
      expect(bloc.scriptStartedAt, isNull);
    });

    test('a one-statement run holds no start', () async {
      final runAnswer = Completer<Result<QueryResult>>();
      when(
        () => repository.run(
          any(),
          any(),
          queryId: any(named: 'queryId'),
          page: any(named: 'page'),
          cancelSignal: any(named: 'cancelSignal'),
        ),
      ).thenAnswer((_) => runAnswer.future);
      final bloc = build();
      addTearDown(bloc.close);

      bloc.add(const EditorRunRequested(text: 'SELECT pg_sleep(40)', role: _user));
      await pumpEventQueue();
      expect(bloc.state, isA<EditorRunning>());
      expect(bloc.scriptStartedAt, isNull);
      runAnswer.complete(Success(customers));
    });

    for (final stopWaiting in [true, false]) {
      test(
        '${stopWaiting ? 'Stop waiting' : 'an answered Cancel'} clears the start as the script is shown cancelled',
        () async {
          when(() => repository.cancel(any(), any())).thenAnswer((_) async => const Success(true));
          final bloc = build();
          addTearDown(bloc.close);
          DateTime? startWhenCancelled = DateTime(1);
          final seen = bloc.stream.firstWhere((s) => s is EditorCancelled).then((_) {
            startWhenCancelled = bloc.scriptStartedAt;
          });

          await runConfirmed(bloc, 'SELECT pg_sleep(40); SELECT pg_sleep(40)');
          await pumpEventQueue();
          expect(bloc.scriptStartedAt, isNotNull);
          bloc.add(EditorCancelRequested(stopWaiting: stopWaiting));
          await seen;

          expect(startWhenCancelled, isNull);
        },
      );
    }

    blocTest<EditorRunBloc, EditorRunState>(
      'Cancel posts the script run id while its request is open, then drops it',
      setUp: () => when(() => repository.cancel(any(), any())).thenAnswer((_) async {
        expect(signals.single?.isCancelled, isFalse);
        return const Success(true);
      }),
      build: build,
      act: (bloc) async {
        await runConfirmed(bloc, 'SELECT pg_sleep(40); SELECT pg_sleep(40)');
        await pumpEventQueue();
        bloc.add(const EditorCancelRequested());
      },
      expect: () => [
        isA<EditorAwaitingConfirmation>(),
        const EditorRunning(queryId: 'run-1', supportsCancel: true),
        const EditorCancelling(queryId: 'run-1'),
        const EditorCancelled(outcome: EditorCancelOutcome.confirmed),
      ],
      verify: (bloc) {
        verify(() => repository.cancel(_postgres, 'run-1')).called(1);
        expect(signals.single?.isCancelled, isTrue);
        expect(bloc.scriptStartedAt, isNull);
        expect(sentScripts(), hasLength(1));
      },
    );

    blocTest<EditorRunBloc, EditorRunState>(
      'a script that answers before the cancel shows its answer',
      setUp: () => when(() => repository.cancel(any(), any())).thenAnswer((_) async {
        scriptAnswer.complete(Success(_script([_success(0, 'SELECT 1', customers)])));
        await pumpEventQueue();
        return const Success(false);
      }),
      build: build,
      act: (bloc) async {
        await runConfirmed(bloc, 'SELECT 1; SELECT 2');
        await pumpEventQueue();
        bloc.add(const EditorCancelRequested());
        await pumpEventQueue();
      },
      skip: 3,
      expect: () => [isA<EditorScriptAnswered>()],
    );
  });
}

/// Records each statement it is told succeeded, and tells no browser.
class _RecordingSchemaChanges extends SchemaChangeNotifier {
  _RecordingSchemaChanges(MockIProviderMetaRepository providerMeta, this._told)
    : super(providerMeta: providerMeta, invalidateConnection: (_) {});

  final List<String> _told;

  @override
  Future<Result<bool>> statementSucceeded(String connectionId, String statement) async {
    _told.add(statement);
    return const Success(false);
  }
}
