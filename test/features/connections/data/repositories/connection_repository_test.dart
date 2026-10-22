import 'package:flutter_bloc_advance/core/errors/app_error.dart';
import 'package:flutter_bloc_advance/core/result/result.dart';
import 'package:flutter_bloc_advance/features/connections/data/models/managed_connections.dart';
import 'package:flutter_bloc_advance/features/connections/data/repositories/connection_repository.dart';
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
}
