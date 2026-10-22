import 'package:flutter_bloc_advance/core/errors/app_error.dart';
import 'package:flutter_bloc_advance/core/result/result.dart';
import 'package:flutter_bloc_advance/features/connections/data/models/connection_policy_model.dart';
import 'package:flutter_bloc_advance/features/connections/data/models/connection_test_result_model.dart';
import 'package:flutter_bloc_advance/features/connections/data/models/managed_connections.dart';
import 'package:flutter_bloc_advance/features/connections/data/repositories/connection_repository.dart';
import 'package:flutter_bloc_advance/features/connections/domain/entities/connection_policy.dart';
import 'package:flutter_bloc_advance/features/connections/domain/entities/connection_test_result.dart';
import 'package:flutter_bloc_advance/features/connections/domain/entities/studio_connection.dart';
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
          id: 'seed:libredb-sample',
          name: 'LibreDB Sample (SQLite)',
          type: 'sqlite',
          database: '/app/data/sample.db',
          environment: 'development',
          group: 'Samples',
        ),
        StudioConnection(
          id: 'seed:sales-db',
          name: 'Sales',
          type: 'postgres',
          host: 'db.example.com',
          port: 5432,
          database: 'sales',
          environment: 'production',
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
}
