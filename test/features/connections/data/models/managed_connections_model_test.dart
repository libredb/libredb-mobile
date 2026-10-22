import 'dart:convert';
import 'dart:io';

import 'package:libredb_mobile/features/connections/data/models/managed_connections_model.dart';
import 'package:libredb_mobile/features/connections/domain/entities/managed_connections.dart';
import 'package:libredb_mobile/shared/models/studio_connection.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  /// A body of one connection: [fields] over a row that has only the required fields.
  ManagedConnections read(Map<String, Object?> fields, {Object? cacheHint = 60000}) => ManagedConnectionsModel.read(
    jsonEncode({
      'connections': [
        {'id': 'seed:a', 'name': 'A', 'type': 'postgres', ...fields},
      ],
      'cacheHint': ?cacheHint,
      'pendingSeeds': <Object?>[],
    }),
  );

  StudioConnection only(Map<String, Object?> fields) => read(fields).connections.single;

  group('ManagedConnectionsModel.read', () {
    test('refuses a body without a connections list', () {
      expect(() => ManagedConnectionsModel.read('{"error":"x"}'), throwsFormatException);
    });

    test('refuses a connection without an id, a name or a type', () {
      expect(() => ManagedConnectionsModel.read('{"connections":[{"id":"seed:a","name":"A"}]}'), throwsFormatException);
    });

    test('reads a row with only the required fields', () {
      expect(only({}), const StudioConnection(id: 'seed:a', name: 'A', type: 'postgres'));
    });

    group('color', () {
      test('keeps a hex color', () {
        expect(only({'color': '#dc2626'}).color, '#dc2626');
        expect(only({'color': '#16A34A'}).color, '#16A34A');
      });

      test('leaves out a color that is not a six digit hex color', () {
        for (final color in ['red', '#fff', 'dc2626', '#dc26266', '#gggggg', '', 12, true]) {
          expect(only({'color': color}).color, isNull, reason: '$color');
        }
      });
    });

    group('readOnly', () {
      test('reads true', () {
        expect(only({'readOnly': true}).readOnly, isTrue);
      });

      test('is false when absent, false or not a boolean', () {
        expect(only({}).readOnly, isFalse);
        expect(only({'readOnly': false}).readOnly, isFalse);
        expect(only({'readOnly': 'true'}).readOnly, isFalse);
      });
    });

    group('managed', () {
      test('reads true and false', () {
        expect(only({'managed': true}).managed, isTrue);
        expect(only({'managed': false}).managed, isFalse);
      });

      // Studio strips the credentials only of a row whose managed is truthy, so an absent flag is an unmanaged row.
      test('is false when absent or not a boolean', () {
        expect(only({}).managed, isFalse);
        expect(only({'managed': 'true'}).managed, isFalse);
      });
    });

    group('seedId', () {
      test('reads the seed id', () {
        expect(only({'seedId': 'a'}).seedId, 'a');
      });

      test('is null when absent, empty or not a string', () {
        expect(only({}).seedId, isNull);
        expect(only({'seedId': ''}).seedId, isNull);
        expect(only({'seedId': 7}).seedId, isNull);
      });
    });

    group('cacheHint', () {
      test('reads milliseconds as a duration', () {
        expect(read({}, cacheHint: 10000).cacheHint, const Duration(seconds: 10));
        expect(read({}, cacheHint: 1500.4).cacheHint, const Duration(milliseconds: 1500));
      });

      test('is null when absent, negative or not a number', () {
        expect(read({}, cacheHint: null).cacheHint, isNull);
        expect(read({}, cacheHint: -1).cacheHint, isNull);
        expect(read({}, cacheHint: '60000').cacheHint, isNull);
      });
    });

    test('leaves out the other optional fields of an unexpected type', () {
      expect(
        only({'host': 5, 'port': '5432', 'database': false, 'environment': 1, 'group': <Object?>[]}),
        const StudioConnection(id: 'seed:a', name: 'A', type: 'postgres'),
      );
    });

    // Studio sends the credentials of an unmanaged seed to a bearer client (S-12), so the reader keeps none of them.
    test('keeps no credential of an unmanaged row', () {
      const secrets = ['s3cret-password', 'postgres://u:pw@db/x', 'api-key-secret-value', 'reader-user'];
      final connection = only({
        'managed': false,
        'user': secrets[3],
        'password': secrets[0],
        'connectionString': secrets[1],
        'apiKeyId': 'key-id',
        'apiKeySecret': secrets[2],
        'privateKey': '-----BEGIN PRIVATE KEY-----',
        'ssl': {'mode': 'verify-full', 'clientKey': 'client-key'},
      });

      final text = '$connection ${connection.props}';
      for (final secret in [...secrets, 'key-id', 'PRIVATE KEY', 'client-key']) {
        expect(text, isNot(contains(secret)));
      }
    });
  });

  test('no connection model declares a credential field', () {
    final credential = RegExp(
      r'\b(user|password|connectionString|apiKeyId|apiKeySecret|privateKey|privateKeyPassphrase|ssl|secret)\b',
      caseSensitive: false,
    );
    final fields = RegExp(r'^\s*final\s+[\w<>?, ]+\s+(\w+)\s*;', multiLine: true);
    final sources = [
      'lib/shared/models/studio_connection.dart',
      'lib/features/connections/domain/entities/managed_connections.dart',
    ];
    for (final path in sources) {
      final names = fields.allMatches(File(path).readAsStringSync()).map((m) => m[1]!).toList();
      expect(names, isNotEmpty, reason: 'the guard reads no field of $path');
      expect(names.where(credential.hasMatch), isEmpty, reason: path);
    }
  });

  test('reads assets/mock/GET_connections_managed.json', () {
    final managed = ManagedConnectionsModel.read(File('assets/mock/GET_connections_managed.json').readAsStringSync());

    expect(managed.cacheHint, const Duration(minutes: 1));
    final production = managed.connections.firstWhere((c) => c.environment == 'production' && c.color != null);
    expect(production.color, matches(RegExp(r'^#[0-9a-fA-F]{6}$')));
    expect(managed.connections.where((c) => c.readOnly).map((c) => c.seedId), ['billing-mysql']);
    expect(managed.connections.every((c) => c.managed), isTrue);
  });
}
