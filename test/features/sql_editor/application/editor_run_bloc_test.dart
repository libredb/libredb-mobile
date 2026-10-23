import 'dart:async';
import 'dart:io';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/sql_editor/application/editor_run_bloc.dart';
import 'package:libredb_mobile/features/sql_editor/domain/entities/statement_history_entry.dart';
import 'package:libredb_mobile/features/sql_editor/domain/repositories/statement_history_repository.dart';
import 'package:libredb_mobile/features/sql_editor/domain/interim_write_check.dart';
import 'package:libredb_mobile/infrastructure/studio/provider_meta_json.dart';
import 'package:libredb_mobile/infrastructure/studio/query_result_json.dart';
import 'package:libredb_mobile/shared/models/provider_meta.dart';
import 'package:libredb_mobile/shared/models/query_page.dart';
import 'package:libredb_mobile/shared/models/query_result.dart';
import 'package:libredb_mobile/shared/models/studio_identity.dart';
import 'package:libredb_mobile/shared/security/result_masking/masking_policy.dart';
import 'package:libredb_mobile/shared/utils/schema_change_notifier.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mock_classes.dart';

String _fixture(String name) => File('test/fixtures/studio/$name.json').readAsStringSync();

QueryResult _recorded(String name) => QueryResultJson.read(_fixture(name));

ProviderMeta _meta(String name) => ProviderMetaJson.read(_fixture(name));

const _postgres = 'seed:dev-postgres';
const _redis = 'seed:dev-redis';
const _server = 'seed:dev-postgres-server';

void main() {
  late MockISqlEditorRepository repository;
  late MockIProviderMetaRepository providerMeta;
  late MockIStatementHistoryRepository history;
  late SchemaChangeNotifier schemaChanges;
  late List<String> invalidated;
  late List<String> changed;
  final customers = _recorded('query_preview_postgres_customers');
  final firstPage = _recorded('query_page_postgres_first');
  final secondPage = _recorded('query_page_postgres_second');
  const user = StudioUserRole();

  var ids = 0;
  late List<AppErrorCode> notKept;

  setUp(() {
    ids = 0;
    notKept = [];
    repository = MockISqlEditorRepository();
    providerMeta = MockIProviderMetaRepository();
    when(() => providerMeta.providerMeta(_postgres)).thenAnswer((_) async => Success(_meta('meta_postgres')));
    when(() => providerMeta.providerMeta(_redis)).thenAnswer((_) async => Success(_meta('meta_redis')));
    when(() => providerMeta.providerMeta(_server)).thenAnswer((_) async => Success(_meta('meta_postgres_server')));
    invalidated = [];
    changed = [];
    schemaChanges = SchemaChangeNotifier(providerMeta: providerMeta, invalidateConnection: invalidated.add);
    schemaChanges.changes.listen(changed.add);
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
          rowCount: run.rowCount,
          executedAt: DateTime.utc(2026, 10, 23),
        ),
      );
    });
  });

  tearDown(() => schemaChanges.dispose());

  EditorRunBloc build({String connectionId = _postgres}) => EditorRunBloc(
    repository: repository,
    providerMeta: providerMeta,
    schemaChanges: schemaChanges,
    history: history,
    onHistoryNotKept: notKept.add,
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

  List<String> sentTexts() => verify(
    () => repository.run(
      any(),
      captureAny(),
      queryId: any(named: 'queryId'),
      page: any(named: 'page'),
      cancelSignal: any(named: 'cancelSignal'),
    ),
  ).captured.cast<String>();

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

  group('a text the check clears', () {
    blocTest<EditorRunBloc, EditorRunState>(
      'runs at once with a fresh run id, masks the answer for the role and keeps the policy',
      setUp: () => answerRun(() => Success(customers)),
      build: build,
      act: (bloc) => bloc.add(const EditorRunRequested(text: 'SELECT * FROM customers', role: user)),
      expect: () => [
        const EditorRunning(queryId: 'run-1', supportsCancel: true),
        isA<EditorSucceeded>()
            .having((s) => s.masked.maskedColumns, 'masked columns', contains('email'))
            .having((s) => s.masked.result.rows.first['email'], 'masked email', isNot('ada@example.com'))
            .having((s) => s.policy, 'policy', MaskingPolicy.forRole(user))
            .having((s) => s.statement.text, 'text', 'SELECT * FROM customers')
            .having((s) => s.statement.asks, 'asks', isNull)
            .having((s) => s.supportsResultPagination, 'pagination', isTrue)
            .having((s) => s.commitKeyword, 'commit keyword', 'COMMIT'),
      ],
      verify: (_) {
        final call = verify(
          () => repository.run(
            _postgres,
            'SELECT * FROM customers',
            queryId: captureAny(named: 'queryId'),
            cancelSignal: any(named: 'cancelSignal'),
          ),
        );
        call.called(1);
        expect(call.captured, ['run-1']);
        verifyNever(
          () => repository.runScript(
            any(),
            any(),
            queryId: any(named: 'queryId'),
            catalog: any(named: 'catalog'),
            page: any(named: 'page'),
          ),
        );
      },
    );

    blocTest<EditorRunBloc, EditorRunState>(
      'a Run while one is in flight is dropped',
      setUp: () => answerRun(() => Success(customers)),
      build: build,
      act: (bloc) => bloc
        ..add(const EditorRunRequested(text: 'SELECT 1', role: user))
        ..add(const EditorRunRequested(text: 'SELECT 2', role: user)),
      skip: 2,
      verify: (_) => expect(sentTexts(), ['SELECT 1']),
    );

    blocTest<EditorRunBloc, EditorRunState>(
      'each success is a run of its own',
      setUp: () => answerRun(() => Success(customers)),
      build: build,
      act: (bloc) async {
        bloc.add(const EditorRunRequested(text: 'SELECT 1', role: user));
        await Future<void>.delayed(Duration.zero);
        bloc.add(const EditorRunRequested(text: 'SELECT 1', role: user));
      },
      expect: () => [
        const EditorRunning(queryId: 'run-1', supportsCancel: true),
        isA<EditorSucceeded>().having((s) => s.run, 'run', 1),
        const EditorRunning(queryId: 'run-2', supportsCancel: true),
        isA<EditorSucceeded>().having((s) => s.run, 'run', 2),
      ],
    );

    blocTest<EditorRunBloc, EditorRunState>(
      'an empty text sends nothing',
      build: build,
      act: (bloc) => bloc.add(const EditorRunRequested(text: '  \n ', role: user)),
      expect: () => const <EditorRunState>[],
      verify: (_) => verifyNothingSent(),
    );
  });

  group('refused locally, before anything is sent', () {
    blocTest<EditorRunBloc, EditorRunState>(
      'a text of several statements, with the one-statement message',
      build: build,
      act: (bloc) => bloc.add(const EditorRunRequested(text: 'SELECT 1; SELECT 2', role: user)),
      expect: () => [
        isA<EditorFailed>()
            .having((s) => s.error.code, 'code', AppErrorCode.editorSeveralStatements.key)
            .having((s) => s.waitingForRetry, 'waiting', isFalse),
      ],
      verify: (_) => verifyNothingSent(),
    );

    blocTest<EditorRunBloc, EditorRunState>(
      'a text over 1,000,000 characters, with the too-large message',
      build: build,
      act: (bloc) => bloc.add(EditorRunRequested(text: 'SELECT 1 ${'x' * EditorRunBloc.maxTextLength}', role: user)),
      expect: () => [isA<EditorFailed>().having((s) => s.error.code, 'code', AppErrorCode.studioStatementTooLarge.key)],
      verify: (_) {
        verifyNothingSent();
        verifyNever(() => providerMeta.providerMeta(any()));
      },
    );

    blocTest<EditorRunBloc, EditorRunState>(
      'a text of exactly 1,000,000 characters is sent',
      setUp: () => answerRun(() => Success(customers)),
      build: build,
      act: (bloc) =>
          bloc.add(EditorRunRequested(text: 'SELECT 1 '.padRight(EditorRunBloc.maxTextLength, ' '), role: user)),
      skip: 1,
      expect: () => [isA<EditorSucceeded>()],
    );

    blocTest<EditorRunBloc, EditorRunState>(
      'a provider-meta failure is a failure, and nothing is sent',
      setUp: () =>
          when(() => providerMeta.providerMeta(_postgres))
              .thenAnswer((_) async => const Failure(ServerError('down', code: 'studio.database_unreachable'))),
      build: build,
      act: (bloc) => bloc.add(const EditorRunRequested(text: 'SELECT 1', role: user)),
      expect: () => [isA<EditorFailed>().having((s) => s.error.code, 'code', 'studio.database_unreachable')],
      verify: (_) => verifyNothingSent(),
    );
  });

  group('a text the check flags', () {
    const delete = 'DELETE FROM orders WHERE false';

    blocTest<EditorRunBloc, EditorRunState>(
      'waits for the confirmation with the text, the reasons and the previous state, and sends nothing',
      build: build,
      act: (bloc) => bloc.add(const EditorRunRequested(text: delete, role: user)),
      expect: () => [
        isA<EditorAwaitingConfirmation>()
            .having((s) => s.statement.text, 'text', delete)
            .having((s) => s.statement.asks?.reasons, 'reasons', {WriteCheckReason.mayWrite})
            .having((s) => s.statement.asks?.flaggedWord, 'word', const FlaggedWord(word: 'DELETE', line: 1))
            .having((s) => s.previous, 'previous', const EditorIdle()),
      ],
      verify: (_) => verifyNothingSent(),
    );

    blocTest<EditorRunBloc, EditorRunState>(
      'a confirmation sends the confirmed text once',
      setUp: () => answerRun(() => Success(_recorded('query'))),
      build: build,
      act: (bloc) async {
        bloc.add(const EditorRunRequested(text: delete, role: user));
        await Future<void>.delayed(Duration.zero);
        bloc.add(const EditorConfirmationAnswered(confirmed: true));
      },
      expect: () => [
        isA<EditorAwaitingConfirmation>(),
        const EditorRunning(queryId: 'run-1', supportsCancel: true),
        isA<EditorSucceeded>()
            .having((s) => s.statement.text, 'text', delete)
            .having((s) => s.statement.asks, 'asks', isNotNull),
      ],
      verify: (_) => expect(sentTexts(), [delete]),
    );

    blocTest<EditorRunBloc, EditorRunState>(
      'the text sent is the one confirmed, whatever is asked for while the sheet is open',
      setUp: () => answerRun(() => Success(_recorded('query'))),
      build: build,
      act: (bloc) async {
        bloc.add(const EditorRunRequested(text: delete, role: user));
        await Future<void>.delayed(Duration.zero);
        bloc.add(const EditorRunRequested(text: 'DROP TABLE orders', role: user));
        await Future<void>.delayed(Duration.zero);
        bloc.add(const EditorConfirmationAnswered(confirmed: true));
      },
      verify: (_) => expect(sentTexts(), [delete]),
    );

    blocTest<EditorRunBloc, EditorRunState>(
      'a cancelled confirmation returns to what was on screen and sends nothing',
      setUp: () => answerRun(() => Success(customers)),
      build: build,
      act: (bloc) async {
        bloc.add(const EditorRunRequested(text: 'SELECT * FROM customers', role: user));
        await Future<void>.delayed(Duration.zero);
        bloc.add(const EditorRunRequested(text: delete, role: user));
        await Future<void>.delayed(Duration.zero);
        bloc.add(const EditorConfirmationAnswered(confirmed: false));
      },
      skip: 1,
      expect: () => [
        isA<EditorSucceeded>().having((s) => s.run, 'run', 1),
        isA<EditorAwaitingConfirmation>().having((s) => s.previous, 'previous', isA<EditorSucceeded>()),
        isA<EditorSucceeded>().having((s) => s.run, 'run', 1),
      ],
      verify: (_) => expect(sentTexts(), ['SELECT * FROM customers']),
    );

    blocTest<EditorRunBloc, EditorRunState>(
      'an answer without a confirmation open is ignored',
      build: build,
      act: (bloc) => bloc.add(const EditorConfirmationAnswered(confirmed: true)),
      expect: () => const <EditorRunState>[],
      verify: (_) => verifyNothingSent(),
    );

    blocTest<EditorRunBloc, EditorRunState>(
      'every text of an engine that does not speak SQL asks, and its commit keyword is EXEC',
      setUp: () => answerRun(() => Success(_recorded('query_redis_string'))),
      build: () => build(connectionId: _redis),
      act: (bloc) async {
        bloc.add(const EditorRunRequested(text: 'GET greeting', role: user));
        await Future<void>.delayed(Duration.zero);
        bloc.add(const EditorConfirmationAnswered(confirmed: true));
      },
      expect: () => [
        isA<EditorAwaitingConfirmation>().having((s) => s.statement.asks?.reasons, 'reasons', {
          WriteCheckReason.notSql,
        }),
        const EditorRunning(queryId: 'run-1', supportsCancel: false),
        isA<EditorSucceeded>()
            .having((s) => s.commitKeyword, 'commit keyword', 'EXEC')
            .having((s) => s.supportsResultPagination, 'pagination', isFalse),
      ],
    );
  });

  group('failures', () {
    blocTest<EditorRunBloc, EditorRunState>(
      "a database error of a confirmed text keeps the error and the cursor offset of the database's position",
      setUp: () => answerRun(
        () =>
            const Failure(ValidationError('syntax error at or near "SELEC"', code: 'studio.query_error', position: 1)),
      ),
      build: build,
      act: (bloc) async {
        bloc.add(const EditorRunRequested(text: 'SELEC 1', role: user));
        await Future<void>.delayed(Duration.zero);
        bloc.add(const EditorConfirmationAnswered(confirmed: true));
      },
      expect: () => [
        isA<EditorAwaitingConfirmation>(),
        isA<EditorRunning>(),
        isA<EditorStatementFailed>()
            .having((s) => s.error.message, 'message', 'syntax error at or near "SELEC"')
            .having((s) => s.position, 'position', 0),
      ],
    );

    blocTest<EditorRunBloc, EditorRunState>(
      'a position counted in characters lands after a character outside the basic plane',
      setUp: () =>
          answerRun(() => const Failure(ValidationError('syntax error', code: 'studio.query_error', position: 13))),
      build: build,
      act: (bloc) => bloc.add(const EditorRunRequested(text: "SELECT '😀', FORM t", role: user)),
      skip: 1,
      expect: () => [isA<EditorStatementFailed>().having((s) => s.position, 'position', 13)],
    );

    blocTest<EditorRunBloc, EditorRunState>(
      'a database error without a position places no cursor',
      setUp: () => answerRun(() => const Failure(ValidationError('no such table: t', code: 'studio.query_error'))),
      build: build,
      act: (bloc) => bloc.add(const EditorRunRequested(text: 'SELECT * FROM t', role: user)),
      skip: 1,
      expect: () => [isA<EditorStatementFailed>().having((s) => s.position, 'position', isNull)],
    );

    blocTest<EditorRunBloc, EditorRunState>(
      'a rate limit waits for its delay, a Run meanwhile sends nothing, and nothing is retried',
      setUp: () => answerRun(
        () =>
            const Failure(RateLimitedError('slow down', code: 'studio.rate_limited', retryAfter: Duration(seconds: 3))),
      ),
      build: build,
      act: (bloc) async {
        bloc.add(const EditorRunRequested(text: 'SELECT 1', role: user));
        await Future<void>.delayed(Duration.zero);
        bloc.add(const EditorRunRequested(text: 'SELECT 1', role: user));
        await Future<void>.delayed(Duration.zero);
        bloc.add(const EditorRateLimitElapsed());
      },
      expect: () => [
        isA<EditorRunning>(),
        isA<EditorFailed>()
            .having((s) => s.error, 'error', isA<RateLimitedError>())
            .having((s) => s.waitingForRetry, 'waiting', isTrue),
        isA<EditorFailed>().having((s) => s.waitingForRetry, 'waiting', isFalse),
      ],
      verify: (_) => expect(sentTexts(), ['SELECT 1']),
    );

    blocTest<EditorRunBloc, EditorRunState>(
      'a failure is never run again by itself; only the next Run sends',
      setUp: () => answerRun(() => const Failure(TimeoutError('slow', code: 'studio.timeout'))),
      build: build,
      act: (bloc) async {
        bloc.add(const EditorRunRequested(text: 'SELECT pg_sleep(90)', role: user));
        await Future<void>.delayed(const Duration(milliseconds: 20));
      },
      expect: () => [
        isA<EditorRunning>(),
        isA<EditorFailed>()
            .having((s) => s.error.code, 'code', 'studio.timeout')
            .having((s) => s.waitingForRetry, 'waiting', isFalse),
      ],
      verify: (_) => expect(sentTexts(), ['SELECT pg_sleep(90)']),
    );
  });

  group('Load more', () {
    Future<EditorSucceeded> runToSuccess(EditorRunBloc bloc, String text, {bool confirm = false}) async {
      bloc.add(EditorRunRequested(text: text, role: user));
      if (confirm) {
        await bloc.stream.firstWhere((s) => s is EditorAwaitingConfirmation);
        bloc.add(const EditorConfirmationAnswered(confirmed: true));
      }
      return await bloc.stream.firstWhere((s) => s is EditorSucceeded) as EditorSucceeded;
    }

    test('a text that ran without asking pages without asking, with the same text and a fresh run id', () async {
      answerRun(() => Success(firstPage));
      final bloc = build();
      addTearDown(bloc.close);
      final succeeded = await runToSuccess(bloc, 'SELECT * FROM sales.ledger');
      answerRun(() => Success(secondPage));
      var asked = 0;

      final answer = await bloc.loadPage(
        succeeded.statement,
        QueryPage.after(firstPage.pagination!),
        confirm: () async {
          asked++;
          return true;
        },
      );

      expect(answer, Success(secondPage));
      expect(asked, 0);
      final call = verify(
        () => repository.run(
          _postgres,
          'SELECT * FROM sales.ledger',
          queryId: captureAny(named: 'queryId'),
          page: captureAny(named: 'page'),
          cancelSignal: any(named: 'cancelSignal'),
        ),
      );
      expect(call.captured, [QueryPage.first, 'run-1', QueryPage.after(firstPage.pagination!), 'run-2']);
    });

    test('a flagged text asks again before the page, and sends the page only on confirm', () async {
      const text = 'SELECT * FROM sales.ledger -- note: update';
      answerRun(() => Success(firstPage));
      final bloc = build();
      addTearDown(bloc.close);
      final succeeded = await runToSuccess(bloc, text, confirm: true);
      answerRun(() => Success(secondPage));
      var asked = 0;

      final declined = await bloc.loadPage(
        succeeded.statement,
        QueryPage.after(firstPage.pagination!),
        confirm: () async {
          asked++;
          return false;
        },
      );
      expect(declined, isNull);
      expect(asked, 1);
      expect(sentTexts(), [text]);

      final confirmed = await bloc.loadPage(
        succeeded.statement,
        QueryPage.after(firstPage.pagination!),
        confirm: () async {
          asked++;
          return true;
        },
      );
      expect(confirmed, Success(secondPage));
      expect(asked, 2);
      expect(sentTexts(), [text]);
    });

    test('a failed page is answered and never sent again by itself', () async {
      answerRun(() => Success(firstPage));
      final bloc = build();
      addTearDown(bloc.close);
      final succeeded = await runToSuccess(bloc, 'SELECT * FROM sales.ledger');
      answerRun(() => const Failure(RateLimitedError('slow down', code: 'studio.rate_limited')));

      final answer = await bloc.loadPage(
        succeeded.statement,
        QueryPage.after(firstPage.pagination!),
        confirm: () async => true,
      );

      expect(answer, isA<Failure<QueryResult>>());
      expect(sentTexts(), ['SELECT * FROM sales.ledger', 'SELECT * FROM sales.ledger']);
    });
  });

  group('the database of a server-level connection', () {
    final archive = _recorded('query_catalog_postgres_server');

    void answerCatalogRun(Result<QueryResult> Function() answer) => when(
      () => repository.run(
        any(),
        any(),
        queryId: any(named: 'queryId'),
        page: any(named: 'page'),
        cancelSignal: any(named: 'cancelSignal'),
        catalog: any(named: 'catalog'),
      ),
    ).thenAnswer((_) async => answer());

    List<Object?> sentCatalogs() => verify(
      () => repository.run(
        any(),
        any(),
        queryId: any(named: 'queryId'),
        page: any(named: 'page'),
        cancelSignal: any(named: 'cancelSignal'),
        catalog: captureAny(named: 'catalog'),
      ),
    ).captured;

    blocTest<EditorRunBloc, EditorRunState>(
      'Run sends the database the user picked, and the result keeps it',
      setUp: () => answerCatalogRun(() => Success(archive)),
      build: () => build(connectionId: _server),
      act: (bloc) =>
          bloc.add(const EditorRunRequested(text: 'SELECT current_database()', role: user, catalog: 'archive')),
      expect: () => [
        const EditorRunning(queryId: 'run-1', supportsCancel: true),
        isA<EditorSucceeded>()
            .having((s) => s.masked.result.rows.single['current_database'], 'database', 'archive')
            .having((s) => s.statement.catalog, 'catalog', 'archive'),
      ],
      verify: (_) {
        verify(
          () => repository.run(
            _server,
            'SELECT current_database()',
            queryId: 'run-1',
            catalog: 'archive',
            cancelSignal: any(named: 'cancelSignal'),
          ),
        ).called(1);
      },
    );

    blocTest<EditorRunBloc, EditorRunState>(
      'a confirmed text runs in the database picked when Run was tapped',
      setUp: () => answerCatalogRun(() => Success(_recorded('query'))),
      build: () => build(connectionId: _server),
      act: (bloc) async {
        bloc.add(const EditorRunRequested(text: 'DELETE FROM orders WHERE false', role: user, catalog: 'app'));
        await bloc.stream.firstWhere((s) => s is EditorAwaitingConfirmation);
        bloc.add(const EditorConfirmationAnswered(confirmed: true));
      },
      skip: 2,
      expect: () => [isA<EditorSucceeded>().having((s) => s.statement.catalog, 'catalog', 'app')],
      verify: (_) => expect(sentCatalogs(), ['app']),
    );

    test('Load more sends the same database as the first page', () async {
      answerCatalogRun(() => Success(firstPage));
      final bloc = build(connectionId: _server);
      addTearDown(bloc.close);
      bloc.add(const EditorRunRequested(text: 'SELECT * FROM public.orders', role: user, catalog: 'archive'));
      final succeeded = await bloc.stream.firstWhere((s) => s is EditorSucceeded) as EditorSucceeded;
      answerCatalogRun(() => Success(secondPage));

      final answer = await bloc.loadPage(
        succeeded.statement,
        QueryPage.after(firstPage.pagination!),
        confirm: () async => true,
      );

      expect(answer, Success(secondPage));
      expect(sentCatalogs(), ['archive', 'archive']);
    });

    blocTest<EditorRunBloc, EditorRunState>(
      'a connection without catalogSessions sends no database',
      setUp: () => answerCatalogRun(() => Success(customers)),
      build: build,
      act: (bloc) => bloc.add(const EditorRunRequested(text: 'SELECT * FROM customers', role: user)),
      skip: 2,
      verify: (_) => expect(sentCatalogs(), [null]),
    );
  });

  group('the schema notifier', () {
    blocTest<EditorRunBloc, EditorRunState>(
      'a successful statement that changes the schema drops the connection and tells the listeners',
      setUp: () => answerRun(() => Success(_recorded('query'))),
      build: build,
      act: (bloc) async {
        bloc.add(const EditorRunRequested(text: 'CREATE TABLE scratch_m5 (id int)', role: user));
        await bloc.stream.firstWhere((s) => s is EditorAwaitingConfirmation);
        bloc.add(const EditorConfirmationAnswered(confirmed: true));
        await bloc.stream.firstWhere((s) => s is EditorSucceeded);
        await pumpEventQueue();
      },
      skip: 3,
      verify: (_) {
        expect(invalidated, [_postgres]);
        expect(changed, [_postgres]);
      },
    );

    blocTest<EditorRunBloc, EditorRunState>(
      'a provider-meta read that fails after the statement still drops the connection and tells the listeners',
      setUp: () => answerRun(() => Success(_recorded('query'))),
      build: build,
      act: (bloc) async {
        bloc.add(const EditorRunRequested(text: 'CREATE TABLE scratch_m5 (id int)', role: user));
        await bloc.stream.firstWhere((s) => s is EditorAwaitingConfirmation);
        when(() => providerMeta.providerMeta(_postgres)).thenAnswer((_) async => const Failure(ServerError('down')));
        bloc.add(const EditorConfirmationAnswered(confirmed: true));
        await bloc.stream.firstWhere((s) => s is EditorSucceeded);
        await pumpEventQueue();
      },
      skip: 3,
      verify: (_) {
        expect(invalidated, [_postgres]);
        expect(changed, [_postgres]);
      },
    );

    blocTest<EditorRunBloc, EditorRunState>(
      'a read changes nothing, and a failed statement is not reported',
      build: build,
      act: (bloc) async {
        answerRun(() => Success(customers));
        bloc.add(const EditorRunRequested(text: 'SELECT * FROM customers', role: user));
        await bloc.stream.firstWhere((s) => s is EditorSucceeded);
        answerRun(() => const Failure(ValidationError('exists', code: 'studio.query_error')));
        bloc.add(const EditorRunRequested(text: 'CREATE TABLE scratch_m5 (id int)', role: user));
        await bloc.stream.firstWhere((s) => s is EditorAwaitingConfirmation);
        bloc.add(const EditorConfirmationAnswered(confirmed: true));
        await bloc.stream.firstWhere((s) => s is EditorStatementFailed);
        await pumpEventQueue();
      },
      skip: 5,
      verify: (_) {
        expect(invalidated, isEmpty);
        expect(changed, isEmpty);
      },
    );
  });

  group('the history', () {
    const account = 'account-hash';
    const target = EditorHistoryTarget(subjectHash: account, connectionName: 'Dev Postgres');

    List<FinishedRun> recorded() => verify(() => history.record(account, captureAny())).captured.cast<FinishedRun>();

    void verifyNothingRecorded() => verifyNever(() => history.record(any(), any()));

    blocTest<EditorRunBloc, EditorRunState>(
      'a run that succeeds writes one entry with its text, Studio\'s time and the rows it counted',
      setUp: () => answerRun(() => Success(customers)),
      build: build,
      act: (bloc) => bloc.add(const EditorRunRequested(text: 'SELECT * FROM customers', role: user, history: target)),
      skip: 2,
      verify: (_) => expect(recorded(), [
        FinishedRun(
          connectionId: _postgres,
          connectionName: 'Dev Postgres',
          text: 'SELECT * FROM customers',
          status: StatementRunStatus.success,
          duration: customers.executionTime,
          rowCount: customers.rowCount,
        ),
      ]),
    );

    blocTest<EditorRunBloc, EditorRunState>(
      'a statement the database refused writes one Failed entry, which carries no error text',
      setUp: () => answerRun(
        () => const Failure(ValidationError('relation "missing" does not exist', code: 'studio.query_error')),
      ),
      build: build,
      act: (bloc) => bloc.add(const EditorRunRequested(text: 'SELECT * FROM missing', role: user, history: target)),
      skip: 2,
      verify: (_) {
        final run = recorded().single;
        expect(run.status, StatementRunStatus.failure);
        expect(run.text, 'SELECT * FROM missing');
        expect(run.rowCount, isNull);
        expect(run.props, isNot(contains(contains('does not exist'))));
      },
    );

    blocTest<EditorRunBloc, EditorRunState>(
      'a request Studio refused, or that timed out after it was sent, writes a Failed entry',
      build: build,
      act: (bloc) async {
        answerRun(() => const Failure(AuthError('denied', code: 'studio.permission_denied')));
        bloc.add(const EditorRunRequested(text: 'SELECT 1', role: user, history: target));
        await bloc.stream.firstWhere((s) => s is EditorFailed);
        answerRun(() => const Failure(TimeoutError('TimeoutException')));
        bloc.add(const EditorRunRequested(text: 'SELECT 2', role: user, history: target));
        await bloc.stream.firstWhere((s) => s is EditorFailed);
      },
      verify: (_) => expect(recorded().map((run) => (run.text, run.status)), [
        ('SELECT 1', StatementRunStatus.failure),
        ('SELECT 2', StatementRunStatus.failure),
      ]),
    );

    blocTest<EditorRunBloc, EditorRunState>(
      'a request that never reached Studio writes nothing',
      setUp: () => answerRun(() => const Failure(NetworkError('offline', code: 'network.offline'))),
      build: build,
      act: (bloc) => bloc.add(const EditorRunRequested(text: 'SELECT 1', role: user, history: target)),
      skip: 2,
      verify: (_) => verifyNothingRecorded(),
    );

    blocTest<EditorRunBloc, EditorRunState>(
      'a cancelled confirmation writes nothing; a confirmed one writes the confirmed text once',
      setUp: () => answerRun(() => Success(_recorded('query'))),
      build: build,
      act: (bloc) async {
        bloc.add(const EditorRunRequested(text: 'DELETE FROM orders', role: user, history: target));
        await bloc.stream.firstWhere((s) => s is EditorAwaitingConfirmation);
        bloc.add(const EditorConfirmationAnswered(confirmed: false));
        await bloc.stream.firstWhere((s) => s is EditorIdle);
        await pumpEventQueue();
        verifyNothingRecorded();
        bloc.add(const EditorRunRequested(text: 'DELETE FROM orders', role: user, history: target));
        await bloc.stream.firstWhere((s) => s is EditorAwaitingConfirmation);
        bloc.add(const EditorConfirmationAnswered(confirmed: true));
        await bloc.stream.firstWhere((s) => s is EditorSucceeded);
      },
      verify: (_) => expect(recorded().map((run) => run.text), ['DELETE FROM orders']),
    );

    blocTest<EditorRunBloc, EditorRunState>(
      'a text refused before it was sent writes nothing',
      build: build,
      act: (bloc) async {
        bloc.add(const EditorRunRequested(text: 'SELECT 1; SELECT 2', role: user, history: target));
        await bloc.stream.firstWhere((s) => s is EditorFailed);
        bloc.add(EditorRunRequested(text: 'x' * (EditorRunBloc.maxTextLength + 1), role: user, history: target));
        await pumpEventQueue();
      },
      verify: (_) => verifyNothingRecorded(),
    );

    blocTest<EditorRunBloc, EditorRunState>(
      'nothing is written while Studio has named no account',
      setUp: () => answerRun(() => Success(customers)),
      build: build,
      act: (bloc) => bloc.add(const EditorRunRequested(text: 'SELECT 1', role: user)),
      skip: 2,
      verify: (_) => verifyNothingRecorded(),
    );

    test('Load more writes no entry', () async {
      answerRun(() => Success(firstPage));
      final bloc = build();
      addTearDown(bloc.close);
      bloc.add(const EditorRunRequested(text: 'SELECT * FROM sales.ledger', role: user, history: target));
      final succeeded = await bloc.stream.firstWhere((s) => s is EditorSucceeded) as EditorSucceeded;
      answerRun(() => Success(secondPage));

      await bloc.loadPage(succeeded.statement, QueryPage.after(firstPage.pagination!), confirm: () async => true);

      expect(recorded(), hasLength(1));
    });

    test('a run answered after the editor closed still writes its entry, and still tells a refused write', () async {
      when(() => history.record(any(), any()))
          .thenAnswer((_) async => const Failure(UnknownError('Could not add', code: 'editor.saved_text_not_stored')));
      final answer = Completer<Result<QueryResult>>();
      when(
        () => repository.run(
          any(),
          any(),
          queryId: any(named: 'queryId'),
          page: any(named: 'page'),
        ),
      ).thenAnswer((_) => answer.future);
      final bloc = build();
      bloc.add(const EditorRunRequested(text: 'SELECT 1', role: user, history: target));
      await bloc.stream.firstWhere((s) => s is EditorRunning);
      final closing = bloc.close();

      answer.complete(Success(customers));
      await closing;
      await pumpEventQueue();

      expect(recorded().map((run) => run.text), ['SELECT 1']);
      expect(notKept, [AppErrorCode.editorSavedTextNotStored]);
    });

    blocTest<EditorRunBloc, EditorRunState>(
      'a timeout before the request was sent writes nothing',
      setUp: () => answerRun(() => const Failure(TimeoutError('TimeoutException', sent: false))),
      build: build,
      act: (bloc) => bloc.add(const EditorRunRequested(text: 'SELECT 1', role: user, history: target)),
      skip: 2,
      verify: (_) => verifyNothingRecorded(),
    );

    test('a success Studio timed as zero keeps the time the phone measured, as Studio\'s web does', () async {
      when(
        () => repository.run(
          any(),
          any(),
          queryId: any(named: 'queryId'),
          page: any(named: 'page'),
        ),
      ).thenAnswer(
        (_) => Future.delayed(
          const Duration(milliseconds: 20),
          () => const Success(QueryResult(fields: [], rows: [], rowCount: 0, executionTime: Duration.zero)),
        ),
      );
      final bloc = build();
      addTearDown(bloc.close);

      bloc.add(const EditorRunRequested(text: 'SELECT 1', role: user, history: target));
      await bloc.stream.firstWhere((s) => s is EditorSucceeded);
      await pumpEventQueue();

      expect(recorded().single.duration, greaterThanOrEqualTo(const Duration(milliseconds: 20)));
    });

    test('a write the store refused is told, with its code only', () async {
      answerRun(() => Success(customers));
      when(() => history.record(any(), any()))
          .thenAnswer((_) async => const Failure(UnknownError('Could not add', code: 'editor.saved_text_not_stored')));
      final bloc = build();
      addTearDown(bloc.close);

      bloc.add(const EditorRunRequested(text: 'SELECT 1', role: user, history: target));
      await bloc.stream.firstWhere((s) => s is EditorSucceeded);
      await pumpEventQueue();

      expect(notKept, [AppErrorCode.editorSavedTextNotStored]);
    });

    test('the target prints no account', () {
      expect(target.toString(), isNot(contains(account)));
    });
  });

  test('no state or event prints the statement text', () {
    const text = "SELECT * FROM t WHERE email = 'ada@example.com'";
    const statement = EditorStatement(text: text);
    expect(statement.toString(), isNot(contains('ada@example.com')));
    expect(const EditorRunRequested(text: text, role: user).toString(), isNot(contains('ada@example.com')));
    expect(
      EditorAwaitingConfirmation(
        statement: statement,
        previous: const EditorIdle(),
        meta: _meta('meta_postgres'),
        role: user,
      ).toString(),
      isNot(contains('ada@example.com')),
    );
  });
}
