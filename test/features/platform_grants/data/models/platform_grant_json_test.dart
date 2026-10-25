import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/features/platform_grants/data/models/platform_grant_json.dart';
import 'package:libredb_mobile/features/platform_grants/domain/entities/platform_grant.dart';

Map<String, Object?> _grant({String id = 'g1'}) => {
  'id': id,
  'subject': 'kc-user-1',
  'subjectUsername': 'bob',
  'subjectEmail': 'bob@example.org',
  'level': 'read',
  'expiresAt': '2027-02-01T00:00:00.000Z',
  'grantedBy': {'id': 'u1', 'name': 'Alice', 'email': 'alice@example.org'},
  'grantedAt': '2027-01-01T00:00:00.000Z',
};

String _body(List<Object?> grants) => jsonEncode({'grants': grants});

/// [_grant] with [path] (a key, or `grantedBy.<key>`) removed, or set to [value] when given.
Map<String, Object?> _with(String path, {bool remove = false, Object? value}) {
  final grant = _grant();
  final granter = Map<String, Object?>.of(grant['grantedBy']! as Map<String, Object?>);
  final target = path.startsWith('grantedBy.') ? granter : grant;
  final key = path.replaceFirst('grantedBy.', '');
  if (remove) {
    target.remove(key);
  } else {
    target[key] = value;
  }
  return {...grant, if (path.startsWith('grantedBy.')) 'grantedBy': granter};
}

void main() {
  test('reads every field of a grant', () {
    final grants = PlatformGrantJson.read(_body([_grant()]));

    expect(grants, [
      PlatformGrant(
        id: 'g1',
        subject: 'kc-user-1',
        subjectUsername: 'bob',
        subjectEmail: 'bob@example.org',
        level: 'read',
        expiresAt: DateTime.utc(2027, 2),
        grantedBy: const PlatformGrantGranter(id: 'u1', name: 'Alice', email: 'alice@example.org'),
        grantedAt: DateTime.utc(2027),
      ),
    ]);
  });

  test("keeps Platform's order", () {
    final grants = PlatformGrantJson.read(_body([_grant(id: 'z'), _grant(id: 'a'), _grant(id: 'm')]));

    expect(grants.map((grant) => grant.id), ['z', 'a', 'm']);
  });

  test('reads an empty list', () {
    expect(PlatformGrantJson.read(_body([])), isEmpty);
  });

  test('reads a null expiresAt as no expiry, and a null subjectEmail and grantedBy.name as absent', () {
    final grant = {
      ..._grant(),
      'subjectEmail': null,
      'expiresAt': null,
      'grantedBy': {'id': 'u1', 'name': null, 'email': 'alice@example.org'},
    };

    final read = PlatformGrantJson.read(_body([grant])).single;

    expect(read.expiresAt, isNull);
    expect(read.subjectEmail, isNull);
    expect(read.grantedBy.name, isNull);
  });

  test('keeps an unknown level unchanged', () {
    final read = PlatformGrantJson.read(_body([_with('level', value: 'admin')])).single;

    expect(read.level, 'admin');
  });

  group('leaves out an optional field of an unexpected type', () {
    for (final (path, value) in [('subjectEmail', 42), ('expiresAt', false), ('grantedBy.name', 7)]) {
      test(path, () {
        final read = PlatformGrantJson.read(_body([_with(path, value: value)])).single;

        expect(switch (path) {
          'subjectEmail' => read.subjectEmail,
          'expiresAt' => read.expiresAt,
          _ => read.grantedBy.name,
        }, isNull);
      });
    }
  });

  group('throws a FormatException', () {
    final cases = <String, String>{
      'for a body that is no object': '[]',
      'for a body that is no JSON': 'not json',
      'for a body without grants': '{}',
      'for grants that are no list': '{"grants":{}}',
      'for a grant that is no object': _body(['g1']),
      for (final field in [
        'id',
        'subject',
        'subjectUsername',
        'level',
        'grantedBy',
        'grantedBy.id',
        'grantedBy.email',
        'grantedAt',
      ]) ...{
        'for a missing $field': _body([_with(field, remove: true)]),
        'for a $field of the wrong type': _body([_with(field, value: 42)]),
      },
      'for an unparseable grantedAt': _body([_with('grantedAt', value: 'yesterday')]),
      'for an unparseable expiresAt': _body([_with('expiresAt', value: 'next week')]),
    };
    for (final MapEntry(key: name, value: body) in cases.entries) {
      test(name, () => expect(() => PlatformGrantJson.read(body), throwsFormatException));
    }
  });

  test('a FormatException names the field, never a value', () {
    try {
      PlatformGrantJson.read(_body([_with('grantedAt', value: 'bob@example.org')]));
      fail('expected a FormatException');
    } on FormatException catch (e) {
      expect(e.message, contains('grantedAt'));
      expect(e.toString(), isNot(contains('bob@example.org')));
    }
  });
}
