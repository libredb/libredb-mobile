import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/features/access_requests/data/models/requestable_connections_json.dart';

String _body(List<Map<String, Object?>> connections) => jsonEncode({'connections': connections});

/// One connection of Platform's `GET /api/v1/requester/connections`, with [overrides] applied to it.
Map<String, Object?> _connection({Map<String, Object?> overrides = const {}}) => {
  'id': 'cm0conn0000000000000000001',
  'name': 'Sales reporting',
  'engine': 'postgres',
  'hasWriteCredential': true,
  'access': {'level': 'read', 'expiresAt': '2027-01-01T00:00:00.000Z'},
  'pendingRequestId': null,
  ...overrides,
};

Map<String, Object?> _without(String field) => _connection()..remove(field);

void main() {
  group('RequestableConnectionsJson.read', () {
    test('reads every field of a full answer and keeps Platform order', () {
      final connections = RequestableConnectionsJson.read(
        _body([
          _connection(overrides: const {'id': 'c1', 'access': null, 'hasWriteCredential': false}),
          _connection(overrides: const {'id': 'c2', 'pendingRequestId': 'r1'}),
        ]),
      );

      expect(connections.map((connection) => connection.id), ['c1', 'c2']);
      expect(connections.first.name, 'Sales reporting');
      expect(connections.first.engine, 'postgres');
      expect(connections.first.hasWriteCredential, isFalse);
      expect(connections.first.access, isNull);
      expect(connections.first.pendingRequestId, isNull);
      expect(connections.last.access?.level, 'read');
      expect(connections.last.access?.expiresAt, DateTime.utc(2027));
      expect(connections.last.pendingRequestId, 'r1');
    });

    test('keeps an unknown engine and an unknown level as Platform sent them', () {
      final connections = RequestableConnectionsJson.read(
        _body([
          _connection(
            overrides: const {
              'engine': 'duckdb',
              'access': {'level': 'owner', 'expiresAt': null},
            },
          ),
        ]),
      );

      expect(connections.single.engine, 'duckdb');
      expect(connections.single.access?.level, 'owner');
      expect(connections.single.access?.expiresAt, isNull);
    });

    for (final MapEntry(key: name, value: body) in <String, String>{
      'no connections list': jsonEncode({'items': <Object?>[]}),
      'a connection that is not an object': jsonEncode({
        'connections': ['c1'],
      }),
      'a missing id': _body([_without('id')]),
      'a name of the wrong type': _body([
        _connection(overrides: const {'name': 7}),
      ]),
      'a missing engine': _body([_without('engine')]),
      'a hasWriteCredential of the wrong type': _body([
        _connection(overrides: const {'hasWriteCredential': 'yes'}),
      ]),
      'a missing hasWriteCredential': _body([_without('hasWriteCredential')]),
      'an access without a level': _body([
        _connection(
          overrides: const {
            'access': {'expiresAt': null},
          },
        ),
      ]),
      'an unreadable expiresAt': _body([
        _connection(
          overrides: const {
            'access': {'level': 'read', 'expiresAt': 'yesterday'},
          },
        ),
      ]),
    }.entries) {
      test('throws a FormatException for $name', () {
        expect(() => RequestableConnectionsJson.read(body), throwsA(isA<FormatException>()));
      });
    }

    test('leaves out an optional field of an unexpected type', () {
      final connections = RequestableConnectionsJson.read(
        _body([
          _connection(overrides: const {'access': 'read', 'pendingRequestId': 12}),
        ]),
      );

      expect(connections.single.access, isNull);
      expect(connections.single.pendingRequestId, isNull);
    });

    test('names the field and never a value in its message', () {
      expect(
        () => RequestableConnectionsJson.read(
          _body([
            _connection(overrides: const {'name': 7}),
          ]),
        ),
        throwsA(
          isA<FormatException>()
              .having((e) => e.message, 'message', contains('name'))
              .having((e) => e.message, 'message', isNot(contains('Sales reporting'))),
        ),
      );
    });
  });
}
