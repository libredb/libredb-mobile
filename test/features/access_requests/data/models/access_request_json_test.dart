import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/features/access_requests/data/models/access_request_json.dart';
import 'package:libredb_mobile/features/access_requests/domain/entities/my_access_request.dart';

/// One request of Platform's requester routes, with [overrides] applied to it.
Map<String, Object?> _request({Map<String, Object?> overrides = const {}}) => {
  'id': 'cm0req00000000000000000001',
  'connection': {
    'id': 'cm0conn0000000000000000001',
    'name': 'Sales reporting',
    'engine': 'postgres',
    'status': 'active',
  },
  'requester': {'subject': 'kc-1', 'username': 'jane.doe', 'email': 'jane.doe@example.org'},
  'level': 'read',
  'reason': 'I need the order totals for the October report',
  'status': 'pending',
  'createdAt': '2026-10-29T08:00:00.000Z',
  'decidedAt': null,
  'decidedBy': null,
  'decisionReason': null,
  'grantId': null,
  ...overrides,
};

Map<String, Object?> _without(String field) => _request()..remove(field);

String _list(List<Map<String, Object?>> requests) => jsonEncode({'requests': requests});

String _one(Map<String, Object?> request) => jsonEncode({'request': request});

void main() {
  group('AccessRequestJson.readList', () {
    test('reads every field of a full answer and keeps Platform order', () {
      final requests = AccessRequestJson.readList(
        _list([
          _request(overrides: const {'id': 'r1'}),
          _request(
            overrides: const {
              'id': 'r2',
              'status': 'approved',
              'level': 'write',
              'decidedAt': '2026-10-29T09:00:00.000Z',
              'grantId': 'g1',
            },
          ),
          _request(overrides: const {'id': 'r3', 'status': 'refused', 'decisionReason': 'Ask your team lead first'}),
        ]),
      );

      expect(requests.map((request) => request.id), ['r1', 'r2', 'r3']);
      final first = requests.first;
      expect(first.connectionId, 'cm0conn0000000000000000001');
      expect(first.connectionName, 'Sales reporting');
      expect(first.connectionEngine, 'postgres');
      expect(first.connectionStatus, 'active');
      expect(first.level, 'read');
      expect(first.reason, 'I need the order totals for the October report');
      expect(first.status, AccessRequestStatus.pending);
      expect(first.rawStatus, 'pending');
      expect(first.createdAt, DateTime.utc(2026, 10, 29, 8));
      expect(first.decidedAt, isNull);
      expect(first.decisionReason, isNull);
      expect(first.grantId, isNull);
      expect(requests[1].status, AccessRequestStatus.approved);
      expect(requests[1].decidedAt, DateTime.utc(2026, 10, 29, 9));
      expect(requests[1].grantId, 'g1');
      expect(requests[2].status, AccessRequestStatus.refused);
      expect(requests[2].decisionReason, 'Ask your team lead first');
    });

    test('never reads the requester', () {
      final requests = AccessRequestJson.readList(_list([_without('requester')]));

      expect(requests.single.id, 'cm0req00000000000000000001');
    });

    for (final (raw, expected) in const [
      ('pending', AccessRequestStatus.pending),
      ('approved', AccessRequestStatus.approved),
      ('refused', AccessRequestStatus.refused),
      ('withdrawn', AccessRequestStatus.withdrawn),
      ('expired', AccessRequestStatus.expired),
    ]) {
      test('reads the status $raw', () {
        final requests = AccessRequestJson.readList(
          _list([
            _request(overrides: {'status': raw}),
          ]),
        );

        expect(requests.single.status, expected);
        expect(requests.single.rawStatus, raw);
      });
    }

    test('reads an unknown status as unknown and keeps the raw string', () {
      final requests = AccessRequestJson.readList(
        _list([
          _request(overrides: const {'status': 'escalated'}),
        ]),
      );

      expect(requests.single.status, AccessRequestStatus.unknown);
      expect(requests.single.rawStatus, 'escalated');
    });

    for (final MapEntry(key: name, value: body) in <String, String>{
      'no requests list': jsonEncode({'items': <Object?>[]}),
      'a request that is not an object': jsonEncode({
        'requests': ['r1'],
      }),
      'a missing id': _list([_without('id')]),
      'a missing connection': _list([_without('connection')]),
      'a connection without a name': _list([
        _request(
          overrides: const {
            'connection': {'id': 'c1', 'engine': 'postgres', 'status': 'active'},
          },
        ),
      ]),
      'a missing level': _list([_without('level')]),
      'a reason of the wrong type': _list([
        _request(overrides: const {'reason': 7}),
      ]),
      'a missing status': _list([_without('status')]),
      'a missing createdAt': _list([_without('createdAt')]),
      'an unreadable createdAt': _list([
        _request(overrides: const {'createdAt': 'today'}),
      ]),
      'an unreadable decidedAt': _list([
        _request(overrides: const {'decidedAt': 'tomorrow'}),
      ]),
    }.entries) {
      test('throws a FormatException for $name', () {
        expect(() => AccessRequestJson.readList(body), throwsA(isA<FormatException>()));
      });
    }

    test('leaves out an optional field of an unexpected type', () {
      final requests = AccessRequestJson.readList(
        _list([
          _request(overrides: const {'decisionReason': 7, 'grantId': false, 'decidedAt': 12}),
        ]),
      );

      expect(requests.single.decisionReason, isNull);
      expect(requests.single.grantId, isNull);
      expect(requests.single.decidedAt, isNull);
    });

    test('names the field and never a value in its message', () {
      expect(
        () => AccessRequestJson.readList(_list([_without('level')])),
        throwsA(
          isA<FormatException>()
              .having((e) => e.message, 'message', contains('level'))
              .having((e) => e.message, 'message', isNot(contains('October report'))),
        ),
      );
    });
  });

  group('AccessRequestJson.readOne', () {
    test('reads the request of a create or a withdraw answer', () {
      final request = AccessRequestJson.readOne(_one(_request(overrides: const {'id': 'r9', 'status': 'withdrawn'})));

      expect(request.id, 'r9');
      expect(request.status, AccessRequestStatus.withdrawn);
    });

    for (final MapEntry(key: name, value: body) in <String, String>{
      'no request object': jsonEncode({'requests': <Object?>[]}),
      'a request that is not an object': jsonEncode({'request': 'r1'}),
      'a missing status': _one(_without('status')),
    }.entries) {
      test('throws a FormatException for $name', () {
        expect(() => AccessRequestJson.readOne(body), throwsA(isA<FormatException>()));
      });
    }
  });
}
