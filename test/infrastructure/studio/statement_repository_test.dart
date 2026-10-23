import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/core/logging/app_logger.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/infrastructure/config/environment.dart';
import 'package:libredb_mobile/infrastructure/http/api_client.dart';
import 'package:libredb_mobile/infrastructure/http/token_rotation.dart';
import 'package:libredb_mobile/infrastructure/studio/statement_repository.dart';
import 'package:libredb_mobile/infrastructure/studio/studio_timeouts.dart';
import 'package:libredb_mobile/shared/models/query_page.dart';
import 'package:libredb_mobile/shared/models/query_result.dart';
import 'package:libredb_mobile/shared/models/statement_repository.dart';
import 'package:libredb_mobile/shared/models/studio_connection.dart';
import 'package:logger/logger.dart' show Logger, OutputEvent;

import '../../support/test_env.dart';

void main() {
  const connection = 'seed:sales-db';

  test('is the shared statement runner', () {
    expect(StatementRepository(TestEnv.apiClient(), ConnectionQueryTimeouts()), isA<IStatementRepository>());
  });

  test('run reads the recorded answer', () async {
    TestEnv.authenticate();

    final result = await StatementRepository(
      TestEnv.apiClient(),
      ConnectionQueryTimeouts(),
    ).run(connection, 'select * from orders');

    final data = (result as Success<QueryResult>).data;
    expect(data.fields, ['id', 'status', 'total', 'note']);
    expect(data.pagination?.wasLimited, isTrue);
  });

  group('what it sends', () {
    late _RecordingAdapter adapter;
    late ConnectionQueryTimeouts queryTimeouts;
    late StatementRepository repository;

    setUp(() {
      adapter = _RecordingAdapter();
      final client = ApiClient(tokenRotation: const RefusingTokenRotation(), appConfig: _prodConfig);
      client.instance.httpClientAdapter = adapter;
      queryTimeouts = ConnectionQueryTimeouts();
      repository = StatementRepository(client, queryTimeouts);
    });

    test('the connection id, the statement, the page, the run id, the bind values and the catalog as JSON', () async {
      await repository.run(
        connection,
        r'select * from orders where id = $1',
        queryId: 'q-7',
        page: const QueryPage(limit: 100, offset: 200),
        params: [7],
        catalog: 'app',
      );

      expect(adapter.requests, 1);
      expect(adapter.lastMethod, 'POST');
      expect(adapter.lastPath, '/db/query');
      expect(adapter.lastContentType, startsWith('application/json'));
      expect(adapter.lastBody, {
        'connectionId': connection,
        'sql': r'select * from orders where id = $1',
        'options': {'limit': 100, 'offset': 200},
        'queryId': 'q-7',
        'params': [7],
        'catalog': 'app',
      });
    });

    test('the numbered database a key was walked in, as a JSON number', () async {
      await repository.run('seed:cache', 'GET "user:1"', database: 1);

      expect(adapter.lastBody, {
        'connectionId': 'seed:cache',
        'sql': 'GET "user:1"',
        'options': {'offset': 0},
        'database': 1,
      });
      expect(adapter.lastRawBody, contains('"database":1'));
    });

    test('database 0 is sent too', () async {
      await repository.run('seed:cache', 'GET "user:1"', database: 0);

      expect((adapter.lastBody! as Map)['database'], 0);
    });

    test('a negative database is refused before anything is sent, as Studio refuses it with a 400', () async {
      expect(() => repository.run('seed:cache', 'GET "user:1"', database: -1), throwsArgumentError);
      expect(adapter.requests, 0);
    });

    test('no database key without a database', () async {
      await repository.run(connection, 'select 1');

      expect(adapter.lastBody, {
        'connectionId': connection,
        'sql': 'select 1',
        'options': {'offset': 0},
      });
    });

    test("waits Studio's default statement timeout plus the margin on a connection without its own", () async {
      await repository.run(connection, 'select pg_sleep(40)');

      expect(adapter.lastReceiveTimeout, studioStatementReceiveTimeout);
    });

    test("waits the connection's own query timeout plus the margin, as the managed list sent it", () async {
      queryTimeouts.replaceAll([
        const StudioConnection(id: connection, name: 'Sales', type: 'postgres', queryTimeout: Duration(minutes: 2)),
      ]);

      await repository.run(connection, 'select pg_sleep(100)');

      expect(adapter.lastReceiveTimeout, const Duration(seconds: 135));
    });

    test('a Studio outage without a code is not sent again: a statement may have changed data', () async {
      adapter.answer = (503, '<html>Service Unavailable</html>');

      final result = await repository.run(connection, 'update orders set status = 1');

      expect(result, isA<Failure<QueryResult>>());
      expect(adapter.requests, 1);
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

    test('an answer with a malformed loss notice is a failure', () async {
      adapter.answer = (
        200,
        '{"rows":[],"fields":["id"],"rowCount":0,"executionTime":1,'
            '"pagination":{"limit":1,"offset":0,"hasMore":false,"totalReturned":0,"wasLimited":"yes"}}',
      );

      final result = await repository.run(connection, 'select id from orders');

      expect(result, isA<Failure<QueryResult>>());
    });

    group('logs', () {
      late List<String> lines;

      setUp(() {
        lines = [];
        void collect(OutputEvent event) => lines.addAll(event.lines);
        Logger.addOutputListener(collect);
        addTearDown(() => Logger.removeOutputListener(collect));
        AppLogger.configure(isProduction: false);
      });

      test('neither the statement nor the database error text', () async {
        adapter.answer = (400, '{"error":"secret_table_name is missing","code":"QUERY_ERROR","statusCode":400}');

        await repository.run(connection, 'select secret_column from secret_table_name');

        expect(lines, isNotEmpty);
        expect(lines.join('\n'), allOf(isNot(contains('secret_column')), isNot(contains('secret_table_name'))));
      });
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
  (int, String) answer = (200, _queryAnswer);
  int requests = 0;
  String? lastMethod;
  String? lastPath;
  String? lastContentType;
  String? lastRawBody;
  Object? lastBody;
  Duration? lastReceiveTimeout;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests++;
    lastMethod = options.method;
    lastPath = options.path;
    lastReceiveTimeout = options.receiveTimeout;
    lastContentType = options.contentType ?? '${options.headers[Headers.contentTypeHeader]}';
    final data = options.data;
    lastRawBody = data is String ? data : jsonEncode(data);
    lastBody = jsonDecode(lastRawBody!);
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
