import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/connections/data/models/connection_policy_model.dart';
import 'package:libredb_mobile/features/connections/data/models/connection_test_result_model.dart';
import 'package:libredb_mobile/features/connections/data/models/managed_connections.dart';
import 'package:libredb_mobile/features/connections/data/repositories/connection_repository.dart';
import 'package:libredb_mobile/features/connections/domain/entities/connection_policy.dart';
import 'package:libredb_mobile/features/connections/domain/entities/connection_test_result.dart';
import 'package:libredb_mobile/features/connections/domain/entities/studio_connection.dart';
import 'package:libredb_mobile/infrastructure/config/environment.dart';
import 'package:libredb_mobile/infrastructure/http/api_client.dart';
import 'package:libredb_mobile/infrastructure/studio/studio_timeouts.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/test_env.dart';

void main() {
  late ConnectionRepository repository;

  setUp(() {
    repository = ConnectionRepository(TestEnv.apiClient());
  });

  group('ConnectionRepository.listManaged', () {
    test('reads the connections of GET /connections/managed', () async {
      TestEnv.authenticate();

      final result = await repository.listManaged();

      expect(result, isA<Success<List<StudioConnection>>>());
      final connections = (result as Success<List<StudioConnection>>).data;
      expect(connections, const [
        StudioConnection(
          id: 'seed:sales-postgres',
          name: 'Sales (PostgreSQL)',
          type: 'postgres',
          host: 'pg.sales.internal',
          port: 5432,
          database: 'sales',
          environment: 'production',
          group: 'Sales',
        ),
        StudioConnection(
          id: 'seed:catalog-mongo',
          name: 'Product Catalog (MongoDB)',
          type: 'mongodb',
          host: 'mongo.catalog.internal',
          port: 27017,
          database: 'catalog',
          environment: 'staging',
          group: 'Catalog',
        ),
        StudioConnection(
          id: 'seed:billing-mysql',
          name: 'Billing (MySQL)',
          type: 'mysql',
          host: 'mysql.billing.internal',
          port: 3306,
          database: 'billing',
          environment: 'production',
          group: 'Finance',
        ),
        // Oracle names a service, not a database.
        StudioConnection(
          id: 'seed:erp-oracle',
          name: 'ERP (Oracle)',
          type: 'oracle',
          host: 'oracle.erp.internal',
          port: 1521,
          environment: 'production',
          group: 'Finance',
        ),
        StudioConnection(
          id: 'seed:reporting-mssql',
          name: 'Reporting (SQL Server)',
          type: 'mssql',
          host: 'mssql.reporting.internal',
          port: 1433,
          database: 'reporting',
          environment: 'development',
          group: 'Analytics',
        ),
      ]);
    });

    test('fails with an AuthError without a session', () async {
      final result = await repository.listManaged();

      expect(result, isA<Failure<List<StudioConnection>>>().having((f) => f.error, 'error', isA<AuthError>()));
    });
  });

  group('ManagedConnections.fromJsonString', () {
    test('refuses a body without a connections list', () {
      expect(() => ManagedConnections.fromJsonString('{"error":"x"}'), throwsFormatException);
    });

    test('refuses a connection without an id, a name or a type', () {
      expect(
        () => ManagedConnections.fromJsonString('{"connections":[{"id":"seed:a","name":"A"}]}'),
        throwsFormatException,
      );
    });
  });

  group('ConnectionRepository.fetchPolicy', () {
    test('reads GET /connections/policy', () async {
      TestEnv.authenticate();

      final result = await repository.fetchPolicy();

      expect(
        result,
        isA<Success<ConnectionPolicy>>().having(
          (s) => s.data,
          'data',
          const ConnectionPolicy(customConnections: false, governance: true, statementCapture: 'full'),
        ),
      );
    });

    test('reads a policy without governance', () {
      expect(
        ConnectionPolicyModel.fromJsonString('{"customConnections":true}'),
        const ConnectionPolicy(customConnections: true, governance: false),
      );
    });

    test('refuses a policy without customConnections', () {
      expect(() => ConnectionPolicyModel.fromJsonString('{}'), throwsFormatException);
    });
  });

  group('ConnectionRepository.test', () {
    test('sends the connection id to POST /db/test-connection and reads the latency', () async {
      TestEnv.authenticate();

      final result = await repository.test('seed:sales-db');

      expect(
        result,
        isA<Success<ConnectionTestResult>>().having(
          (s) => s.data,
          'data',
          const ConnectionTestResult(
            message: 'Connection successful',
            latency: Duration(milliseconds: 42),
            degraded: false,
          ),
        ),
      );
    });

    test('reads a degraded answer, connected but without a health reading', () {
      expect(
        ConnectionTestResultModel.fromJsonString('{"success":true,"degraded":true,"message":"health read failed"}'),
        const ConnectionTestResult(message: 'health read failed', degraded: true),
      );
    });

    test('refuses an answer that is not a success', () {
      expect(() => ConnectionTestResultModel.fromJsonString('{"success":false,"error":"x"}'), throwsFormatException);
    });
  });

  group('ConnectionRepository waits for the answer', () {
    late _RecordingAdapter adapter;
    late ConnectionRepository repository;

    setUp(() {
      adapter = _RecordingAdapter();
      final client = ApiClient(appConfig: _prodConfig);
      client.instance.httpClientAdapter = adapter;
      repository = ConnectionRepository(client);
    });

    test('as long as Studio lets a statement run, for test, which may reach a slow database host', () async {
      adapter.answer = '{"success":true,"latency":42,"message":"Connection successful"}';

      await repository.test('seed:sales-db');

      expect(adapter.lastPath, '/db/test-connection');
      expect(adapter.lastReceiveTimeout, studioStatementReceiveTimeout);
    });

    test('the default 30 seconds for listManaged', () async {
      adapter.answer = '[]';

      await repository.listManaged();

      expect(adapter.lastPath, '/connections/managed');
      expect(adapter.lastReceiveTimeout, const Duration(seconds: 30));
    });

    test('the default 30 seconds for fetchPolicy', () async {
      await repository.fetchPolicy();

      expect(adapter.lastPath, '/connections/policy');
      expect(adapter.lastReceiveTimeout, const Duration(seconds: 30));
    });
  });
}

/// The production chain, without a stored token.
const _prodConfig = AppConfig(
  environment: Environment.prod,
  apiBaseUrl: 'https://studio.example.test/api',
  certificatePins: [],
  idleTimeout: null,
);

/// Answers every request with 200 and [answer] and records the last one.
class _RecordingAdapter implements HttpClientAdapter {
  String answer = '{}';
  String? lastPath;
  Duration? lastReceiveTimeout;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastPath = options.path;
    lastReceiveTimeout = options.receiveTimeout;
    return ResponseBody.fromString(
      answer,
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
