import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/features/platform_grants/data/models/directory_page_json.dart';
import 'package:libredb_mobile/features/platform_grants/domain/entities/directory_page.dart';
import 'package:libredb_mobile/features/platform_grants/domain/entities/directory_user.dart';

Map<String, Object?> _user() => {
  'id': 'kc-1',
  'username': 'bob',
  'email': 'bob@example.com',
  'firstName': 'Bob',
  'lastName': 'Stone',
  'enabled': true,
  'studioRole': 'user',
  'needsSeat': false,
};

String _body({List<Object?>? users, Object? page = 1, Object? total = 1, Set<String> omit = const {}}) => jsonEncode({
  if (!omit.contains('users')) 'users': users ?? [_user()],
  if (!omit.contains('page')) 'page': page,
  if (!omit.contains('total')) 'total': total,
});

void main() {
  test('reads every field of a page and its users', () {
    expect(
      DirectoryPageJson.read(_body(total: 41)),
      const DirectoryPage(
        users: [
          DirectoryUser(
            id: 'kc-1',
            username: 'bob',
            email: 'bob@example.com',
            firstName: 'Bob',
            lastName: 'Stone',
            enabled: true,
            studioRole: 'user',
            needsSeat: false,
          ),
        ],
        page: 1,
        total: 41,
      ),
    );
  });

  for (final field in ['users', 'page', 'total']) {
    test('throws a FormatException when $field is missing', () {
      expect(() => DirectoryPageJson.read(_body(omit: {field})), throwsFormatException);
    });
  }

  test('throws a FormatException when page or total is not an integer', () {
    expect(() => DirectoryPageJson.read(_body(page: '1')), throwsFormatException);
    expect(() => DirectoryPageJson.read(_body(total: 1.5)), throwsFormatException);
  });

  test('throws a FormatException when the body is not an object or a user is not one', () {
    expect(() => DirectoryPageJson.read('[]'), throwsFormatException);
    expect(() => DirectoryPageJson.read(_body(users: ['bob'])), throwsFormatException);
  });

  for (final (field, value) in [('id', 7), ('username', null), ('enabled', 'true'), ('needsSeat', 1)]) {
    test('throws a FormatException when a user has no valid $field', () {
      expect(() => DirectoryPageJson.read(_body(users: [_user()..remove(field)])), throwsFormatException);
      expect(() => DirectoryPageJson.read(_body(users: [_user()..[field] = value])), throwsFormatException);
    });
  }

  test('reads null, absent or mistyped email, firstName, lastName and studioRole as null', () {
    final nulls = {..._user(), 'email': null, 'firstName': null, 'lastName': null, 'studioRole': null};
    final absent = _user()
      ..remove('email')
      ..remove('firstName')
      ..remove('lastName')
      ..remove('studioRole');
    final mistyped = {..._user(), 'email': 1, 'firstName': true, 'lastName': [], 'studioRole': 3};

    final users = DirectoryPageJson.read(_body(users: [nulls, absent, mistyped], total: 3)).users;

    for (final user in users) {
      expect(user.email, isNull);
      expect(user.firstName, isNull);
      expect(user.lastName, isNull);
      expect(user.studioRole, isNull);
    }
  });

  test('keeps an unknown studioRole as Platform sent it', () {
    final user = DirectoryPageJson.read(_body(users: [_user()..['studioRole'] = 'auditor'])).users.single;

    expect(user.studioRole, 'auditor');
  });

  test('names the field and never a value in its message', () {
    final secret = _user()..['id'] = 42;
    expect(
      () => DirectoryPageJson.read(_body(users: [secret..['username'] = 'alice@example.com'])),
      throwsA(isA<FormatException>().having((e) => e.message, 'message', isNot(contains('alice')))),
    );
  });
}
