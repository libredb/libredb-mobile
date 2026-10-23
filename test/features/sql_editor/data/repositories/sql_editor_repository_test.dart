import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/sql_editor/data/repositories/sql_editor_repository.dart';
import 'package:libredb_mobile/features/sql_editor/domain/entities/transaction_state.dart';
import 'package:libredb_mobile/shared/models/cancel_signal.dart';
import 'package:libredb_mobile/shared/models/query_page.dart';
import 'package:libredb_mobile/shared/models/query_result.dart';
import 'package:libredb_mobile/infrastructure/config/environment.dart';
import 'package:libredb_mobile/infrastructure/http/api_client.dart';
import 'package:libredb_mobile/infrastructure/http/token_rotation.dart';
import 'package:libredb_mobile/infrastructure/studio/statement_repository.dart';
import 'package:libredb_mobile/infrastructure/studio/studio_timeouts.dart';
import 'package:libredb_mobile/shared/models/studio_connection.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../mocks/mock_classes.dart';
import '../../../../support/test_env.dart';

void main() {
  const connection = 'seed:sales-db';

  T data<T>(Result<T> result) => (result as Success<T>).data;

  group('against the recorded answers', () {
    late SqlEditorRepository repository;

    setUp(() {
      TestEnv.authenticate();
      final client = TestEnv.apiClient();
      final queryTimeouts = ConnectionQueryTimeouts();
      repository = SqlEditorRepository(client, StatementRepository(client, queryTimeouts), queryTimeouts);
    });

    test('run reads rows, types and paging', () async {
      final result = data(await repository.run(connection, 'select * from orders', queryId: 'q-1'));

      expect(result.fields, ['id', 'status', 'total', 'note']);
      expect(result.rows.first, {'id': 1, 'status': 'paid', 'total': 12.5, 'note': null});
      expect(result.executionTime, const Duration(milliseconds: 14));
      expect(result.columnTypes['total'], 'numeric');
      expect(result.pagination?.hasMore, isFalse);
    });

    test('runScript keeps the failed statement in the result', () async {
      final script = data(await repository.runScript(connection, 'update ...; select ...; select * form orders'));

      expect(script.statementCount, 3);
      expect(script.hasError, isTrue);
      expect(script.statements[1].result?.rows, [
        {'count': 2},
      ]);
      expect(script.statements[2].error, 'syntax error at or near "FORM"');
      expect(script.statements[2].startLine, 3);
    });

    test('cancel reads whether the engine stopped the run', () async {
      expect(data(await repository.cancel(connection, 'q-1')), isTrue);
    });

    test('the transaction actions read their answers', () async {
      expect(data(await repository.beginTransaction(connection)), isTrue);
      expect(data(await repository.runInTransaction(connection, 'update orders set status = 1')).inTransaction, isTrue);
      expect(await repository.commit(connection), const Success(TransactionEnd.confirmed));
      expect(await repository.rollback(connection), const Success(TransactionEnd.confirmed));
      final status = data(await repository.transactionStatus(connection));
      expect(status.ownedByYou, isTrue);
      expect(status.startedAt, DateTime.utc(2026, 10, 22, 9));
    });

    test('each transaction action gets the status Studio answers for it', () async {
      Future<Object?> status(String action) async {
        final response = await TestEnv.apiClient().post('/db/transaction', {
          'connectionId': connection,
          'action': action,
        });
        return (jsonDecode(response.data!) as Map<String, dynamic>)['status'];
      }

      expect(await status('begin'), 'active');
      expect(await status('commit'), 'committed');
      expect(await status('rollback'), 'rolled_back');
    });
  });

  test('run is the shared statement runner, so the app has one /db/query call', () async {
    final statements = MockIStatementRepository();
    const answer = QueryResult(fields: ['n'], rows: [], rowCount: 0, executionTime: Duration.zero);
    when(
      () => statements.run(
        any(),
        any(),
        queryId: any(named: 'queryId'),
        page: any(named: 'page'),
        params: any(named: 'params'),
        catalog: any(named: 'catalog'),
        cancelSignal: any(named: 'cancelSignal'),
      ),
    ).thenAnswer((_) async => const Success(answer));
    final repository = SqlEditorRepository(TestEnv.apiClient(), statements, ConnectionQueryTimeouts());
    final signal = CancelSignal();

    final result = await repository.run(
      connection,
      'select n from t',
      queryId: 'q-3',
      page: const QueryPage(limit: 10),
      params: [1],
      catalog: 'app',
      cancelSignal: signal,
    );

    expect(data(result), answer);
    verify(
      () => statements.run(
        connection,
        'select n from t',
        queryId: 'q-3',
        page: const QueryPage(limit: 10),
        params: [1],
        catalog: 'app',
        cancelSignal: signal,
      ),
    ).called(1);
  });

  test('cancel is the shared one, so the app posts /db/cancel from one place', () async {
    final statements = MockIStatementRepository();
    when(() => statements.cancel(any(), any())).thenAnswer((_) async => const Success(true));
    final repository = SqlEditorRepository(TestEnv.apiClient(), statements, ConnectionQueryTimeouts());

    expect(await repository.cancel(connection, 'q-4'), const Success(true));
    verify(() => statements.cancel(connection, 'q-4')).called(1);
  });

  group('what it sends', () {
    late _RecordingAdapter adapter;
    late ConnectionQueryTimeouts queryTimeouts;
    late SqlEditorRepository repository;

    setUp(() {
      adapter = _RecordingAdapter();
      final client = ApiClient(tokenRotation: const RefusingTokenRotation(), appConfig: _prodConfig);
      client.instance.httpClientAdapter = adapter;
      queryTimeouts = ConnectionQueryTimeouts();
      repository = SqlEditorRepository(client, StatementRepository(client, queryTimeouts), queryTimeouts);
    });

    test('run sends the connection id, the statement, the page, the run id and the bind values as JSON', () async {
      adapter.answer = (200, _queryAnswer);

      await repository.run(
        connection,
        r'select * from orders where id = $1',
        queryId: 'q-7',
        page: const QueryPage(limit: 100, offset: 200),
        params: [7],
      );

      expect(adapter.lastPath, '/db/query');
      expect(adapter.lastContentType, startsWith('application/json'));
      expect(adapter.lastBody, {
        'connectionId': connection,
        'sql': r'select * from orders where id = $1',
        'options': {'limit': 100, 'offset': 200},
        'queryId': 'q-7',
        'params': [7],
      });
    });

    test('runScript sends the page for the last SELECT as options', () async {
      adapter.answer = (200, _scriptAnswer);

      await repository.runScript(connection, 'select 1; select * from orders', page: const QueryPage(limit: 50));

      expect(adapter.lastPath, '/db/multi-query');
      expect(adapter.lastContentType, startsWith('application/json'));
      expect(adapter.lastBody, {
        'connectionId': connection,
        'sql': 'select 1; select * from orders',
        'options': {'limit': 50, 'offset': 0},
      });
    });

    test('a script dropped through its cancel signal fails as cancelled, after one request', () async {
      final signal = CancelSignal();
      adapter.hold = Completer<void>();

      final sent = repository.runScript(
        connection,
        'select pg_sleep(40); select pg_sleep(40)',
        queryId: 'q-8',
        cancelSignal: signal,
      );
      await pumpEventQueue();
      signal.cancel();

      expect((await sent as Failure<Object>).error, isA<RequestCancelledError>());
      expect(adapter.requests, 1);
    });

    test('runScript without a page sends no options', () async {
      adapter.answer = (200, _scriptAnswer);

      await repository.runScript(connection, 'select 1; select 2', queryId: 'q-2', catalog: 'app');

      expect(adapter.lastBody, {
        'connectionId': connection,
        'sql': 'select 1; select 2',
        'queryId': 'q-2',
        'catalog': 'app',
      });
    });

    test('a transaction action names the action and nothing it does not need', () async {
      adapter.answer = (200, '{"status":"committed","message":"Transaction committed"}');

      await repository.commit(connection);

      expect(adapter.lastPath, '/db/transaction');
      expect(adapter.lastBody, {'connectionId': connection, 'action': 'commit'});
    });

    group('names the database of a server-level connection', () {
      // Studio keys a transaction by connection and catalog, so an action without the catalog its begin named finds no
      // transaction: commit and rollback answer 400 "No active transaction", status says none is open.
      final endingActions = <String, Future<Object?> Function({String? catalog})>{
        'commit': ({catalog}) => repository.commit(connection, catalog: catalog),
        'rollback': ({catalog}) => repository.rollback(connection, catalog: catalog),
      };
      for (final MapEntry(key: action, value: call) in endingActions.entries) {
        test('$action sends the catalog when given', () async {
          adapter.answer = (200, '{"status":"x","message":"x"}');

          await call(catalog: 'app');

          expect(adapter.lastContentType, startsWith('application/json'));
          expect(adapter.lastBody, {'connectionId': connection, 'action': action, 'catalog': 'app'});
        });

        test('$action leaves the catalog out when not given', () async {
          adapter.answer = (200, '{"status":"x","message":"x"}');

          await call();

          expect(adapter.lastBody, {'connectionId': connection, 'action': action});
        });
      }

      const statusAnswer = '{"inTransaction":true,"ownedByYou":true,"heldByAnotherSession":false,"startedAt":null}';

      test('transactionStatus sends the catalog when given', () async {
        adapter.answer = (200, statusAnswer);

        await repository.transactionStatus(connection, catalog: 'app');

        expect(adapter.lastContentType, startsWith('application/json'));
        expect(adapter.lastBody, {'connectionId': connection, 'action': 'status', 'catalog': 'app'});
      });

      test('transactionStatus leaves the catalog out when not given', () async {
        adapter.answer = (200, statusAnswer);

        await repository.transactionStatus(connection);

        expect(adapter.lastBody, {'connectionId': connection, 'action': 'status'});
      });
    });

    group('ends a transaction', () {
      // Studio answers 2xx to commit and rollback only after the engine ended the transaction
      // (src/app/api/db/transaction/route.ts), so a 2xx it cannot read still means the transaction is over.
      final endingActions = <String, (String, Future<Result<TransactionEnd>> Function())>{
        'commit': ('committed', () => repository.commit(connection)),
        'rollback': ('rolled_back', () => repository.rollback(connection)),
      };
      for (final MapEntry(key: action, value: (status, call)) in endingActions.entries) {
        test('$action is confirmed by the status Studio sends for it', () async {
          adapter.answer = (200, '{"status":"$status","message":"Transaction ended"}');

          expect(await call(), const Success(TransactionEnd.confirmed));
        });

        test('$action answered 2xx without a status ended the transaction, unconfirmed', () async {
          adapter.answer = (200, '{"message":"Transaction ended"}');

          expect(await call(), const Success(TransactionEnd.unreadableAnswer));
          expect(adapter.requests, 1, reason: 'never sent again');
        });

        test('$action answered 2xx with a body that is not its status ended the transaction, unconfirmed', () async {
          for (final body in ['{"status":1}', '{"status":"active"}', '<html>OK</html>', '', '[]']) {
            adapter.answer = (200, body);

            expect(await call(), const Success(TransactionEnd.unreadableAnswer), reason: body);
          }
        });

        test('$action refused by Studio is a failure', () async {
          adapter.answer = (400, '{"error":"No active transaction","statusCode":400}');

          expect(await call(), isA<Failure<TransactionEnd>>());
          expect(adapter.requests, 1, reason: 'never sent again');
        });
      }

      test('the other action\'s status does not confirm an end', () async {
        adapter.answer = (200, '{"status":"rolled_back","message":"Transaction rolled back"}');
        expect(await repository.commit(connection), const Success(TransactionEnd.unreadableAnswer));

        adapter.answer = (200, '{"status":"committed","message":"Transaction committed"}');
        expect(await repository.rollback(connection), const Success(TransactionEnd.unreadableAnswer));
      });
    });

    test("a database error keeps the database's words and the query error code", () async {
      adapter.answer = (400, '{"error":"relation \\"ordrs\\" does not exist","code":"QUERY_ERROR","statusCode":400}');

      final result = await repository.run(connection, 'select * from ordrs');

      expect(
        result,
        isA<Failure<QueryResult>>().having(
          (f) => f.error,
          'error',
          isA<ValidationError>()
              .having((e) => e.code, 'code', AppErrorCode.studioQueryError.key)
              .having((e) => e.message, 'message', 'relation "ordrs" does not exist'),
        ),
      );
    });

    group('waits for the answer', () {
      final statementCalls = <String, Future<Object?> Function()>{
        'run': () => repository.run(connection, 'select pg_sleep(40)'),
        'beginTransaction': () => repository.beginTransaction(connection),
        'runInTransaction': () => repository.runInTransaction(connection, 'update orders set status = 1'),
        'commit': () => repository.commit(connection),
        'rollback': () => repository.rollback(connection),
        'transactionStatus': () => repository.transactionStatus(connection),
      };

      for (final MapEntry(key: name, value: call) in statementCalls.entries) {
        test("Studio's default statement timeout plus the margin, for $name on a connection without its own", () async {
          await call();

          expect(adapter.lastReceiveTimeout, studioStatementReceiveTimeout);
        });

        test("the connection's own query timeout plus the margin, for $name", () async {
          queryTimeouts.replaceAll([
            const StudioConnection(id: connection, name: 'Sales', type: 'postgres', queryTimeout: Duration(minutes: 2)),
          ]);

          await call();

          expect(adapter.lastReceiveTimeout, const Duration(seconds: 135));
        });
      }

      group('without a limit for runScript, since Studio gives each statement of a script its own timeout', () {
        test('on a connection without its own query timeout', () async {
          adapter.answer = (200, _scriptAnswer);

          await repository.runScript(connection, 'select pg_sleep(40); select pg_sleep(40)');

          expect(adapter.lastPath, '/db/multi-query');
          expect(adapter.lastReceiveTimeout, Duration.zero, reason: 'Dio reads zero as no receive timeout');
        });

        test('on a connection with its own query timeout', () async {
          queryTimeouts.replaceAll([
            const StudioConnection(id: connection, name: 'Sales', type: 'postgres', queryTimeout: Duration(minutes: 2)),
          ]);
          adapter.answer = (200, _scriptAnswer);

          await repository.runScript(connection, 'select pg_sleep(100); select pg_sleep(100)');

          expect(adapter.lastReceiveTimeout, Duration.zero);
        });
      });

      test('the default 30 seconds for cancel, which runs no statement', () async {
        adapter.answer = (200, '{"cancelled":true}');

        await repository.cancel(connection, 'q-1');

        expect(adapter.lastPath, '/db/cancel');
        expect(adapter.lastReceiveTimeout, const Duration(seconds: 30));
      });
    });

    test('a cancelled run is reported as cancelled', () async {
      adapter.answer = (499, '{"error":"Query cancelled","code":"QUERY_CANCELLED","statusCode":499}');

      final result = await repository.run(connection, 'select pg_sleep(60)', queryId: 'q-8');

      expect((result as Failure).error.code, AppErrorCode.studioQueryCancelled.key);
    });
  });
}

const _scriptAnswer = '{"statements":[],"statementCount":0,"executedCount":0,"executionTime":0}';

const _queryAnswer =
    '{"rows":[],"fields":["id"],"rowCount":0,"executionTime":1,'
    '"pagination":{"limit":100,"offset":200,"hasMore":false,"totalReturned":0,"wasLimited":true}}';

/// The production chain, without a stored token and on a status the refresh leaves alone.
const _prodConfig = AppConfig(
  environment: Environment.prod,
  apiBaseUrl: 'https://studio.example.test/api',
  certificatePins: [],
  idleTimeout: null,
);

/// Answers every request with [answer] and records the last one.
class _RecordingAdapter implements HttpClientAdapter {
  (int, String) answer = (200, '{}');
  int requests = 0;
  String? lastPath;
  String? lastContentType;
  Object? lastBody;
  Duration? lastReceiveTimeout;

  /// Holds the answer until it completes, so a request can be dropped while it is open.
  Completer<void>? hold;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests++;
    lastPath = options.path;
    lastReceiveTimeout = options.receiveTimeout;
    lastContentType = options.contentType ?? '${options.headers[Headers.contentTypeHeader]}';
    final data = options.data;
    lastBody = data is String ? jsonDecode(data) : data;
    if (hold case final hold?) await Future.any([hold.future, ?cancelFuture]);
    final (status, body) = answer;
    return ResponseBody.fromString(
      body,
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
