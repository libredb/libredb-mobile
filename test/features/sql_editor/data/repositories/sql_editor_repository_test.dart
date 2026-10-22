import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/sql_editor/data/repositories/sql_editor_repository.dart';
import 'package:libredb_mobile/features/sql_editor/domain/entities/query_page.dart';
import 'package:libredb_mobile/features/sql_editor/domain/entities/query_result.dart';
import 'package:libredb_mobile/infrastructure/config/environment.dart';
import 'package:libredb_mobile/infrastructure/http/api_client.dart';
import 'package:libredb_mobile/infrastructure/http/token_rotation.dart';
import 'package:libredb_mobile/infrastructure/studio/studio_timeouts.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/test_env.dart';

void main() {
  const connection = 'seed:sales-db';

  T data<T>(Result<T> result) => (result as Success<T>).data;

  group('against the recorded answers', () {
    late SqlEditorRepository repository;

    setUp(() {
      TestEnv.authenticate();
      repository = SqlEditorRepository(TestEnv.apiClient());
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
      expect(await repository.commit(connection), isA<Success<void>>());
      expect(await repository.rollback(connection), isA<Success<void>>());
      final status = data(await repository.transactionStatus(connection));
      expect(status.ownedByYou, isTrue);
      expect(status.startedAt, DateTime.utc(2026, 10, 22, 9));
    });
  });

  group('what it sends', () {
    late _RecordingAdapter adapter;
    late SqlEditorRepository repository;

    setUp(() {
      adapter = _RecordingAdapter();
      final client = ApiClient(tokenRotation: const RefusingTokenRotation(), appConfig: _prodConfig);
      client.instance.httpClientAdapter = adapter;
      repository = SqlEditorRepository(client);
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

    test('an ending answer without a status is a failure', () async {
      adapter.answer = (200, '{"message":"Transaction committed"}');

      final result = await repository.commit(connection);

      expect(result, isA<Failure<void>>());
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
        'runScript': () => repository.runScript(connection, 'select 1; select pg_sleep(40)'),
        'beginTransaction': () => repository.beginTransaction(connection),
        'runInTransaction': () => repository.runInTransaction(connection, 'update orders set status = 1'),
        'commit': () => repository.commit(connection),
        'rollback': () => repository.rollback(connection),
        'transactionStatus': () => repository.transactionStatus(connection),
      };

      for (final MapEntry(key: name, value: call) in statementCalls.entries) {
        test('as long as Studio lets a statement run, for $name', () async {
          await call();

          expect(adapter.lastReceiveTimeout, studioStatementReceiveTimeout);
        });
      }

      test("Studio's 60 second statement timeout plus a 15 second margin", () {
        expect(studioStatementReceiveTimeout, const Duration(seconds: 75));
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
  String? lastPath;
  String? lastContentType;
  Object? lastBody;
  Duration? lastReceiveTimeout;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastPath = options.path;
    lastReceiveTimeout = options.receiveTimeout;
    lastContentType = options.contentType ?? '${options.headers[Headers.contentTypeHeader]}';
    final data = options.data;
    lastBody = data is String ? jsonDecode(data) : data;
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
