import 'dart:convert';

import 'package:libredb_mobile/features/auth/data/models/platform_identity_model.dart';
import 'package:libredb_mobile/shared/models/platform_identity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Map<String, Object?> answer() => {
    'id': 'u1',
    'email': 'admin@example.org',
    'name': 'Admin',
    'roles': ['PLATFORM_ADMIN'],
    'permissions': ['connection.view'],
    'tenant': <String, Object?>{'id': 't1', 'name': 'Example Org', 'slug': 'example-org'},
  };

  PlatformIdentity read(Map<String, Object?> json) => PlatformIdentityModel.fromJsonString(jsonEncode(json));

  test("reads Platform's GET /v1/me answer", () {
    expect(
      read(answer()),
      const PlatformIdentity(
        id: 'u1',
        email: 'admin@example.org',
        name: 'Admin',
        roles: ['PLATFORM_ADMIN'],
        permissions: ['connection.view'],
        tenant: PlatformTenant(id: 't1', name: 'Example Org', slug: 'example-org'),
      ),
    );
  });

  test('keeps a role or a permission this app does not know, as Platform sent it', () {
    final identity = read(answer()..['roles'] = ['PLATFORM_ADMIN', 'SOMETHING_NEW']);

    expect(identity.roles, ['PLATFORM_ADMIN', 'SOMETHING_NEW']);
  });

  test('accepts a null name and an absent name', () {
    expect(read(answer()..['name'] = null).name, isNull);
    expect(read(answer()..remove('name')).name, isNull);
  });

  for (final field in ['id', 'email', 'roles', 'permissions', 'tenant']) {
    test('throws a FormatException for a missing $field', () {
      expect(() => read(answer()..remove(field)), throwsFormatException);
    });

    test('throws a FormatException for a mistyped $field', () {
      expect(() => read(answer()..[field] = 42), throwsFormatException);
    });
  }

  for (final field in ['id', 'name', 'slug']) {
    test('throws a FormatException for a missing or mistyped tenant $field', () {
      final missing = answer();
      (missing['tenant'] as Map<String, Object?>).remove(field);
      expect(() => read(missing), throwsFormatException);

      final mistyped = answer();
      (mistyped['tenant'] as Map<String, Object?>)[field] = 7;
      expect(() => read(mistyped), throwsFormatException);
    });
  }

  test('throws a FormatException for a non-string role or permission', () {
    expect(() => read(answer()..['roles'] = ['PLATFORM_ADMIN', 1]), throwsFormatException);
    expect(() => read(answer()..['permissions'] = [null]), throwsFormatException);
  });

  test('throws a FormatException for a mistyped name and for an answer that is not an object', () {
    expect(() => read(answer()..['name'] = 3), throwsFormatException);
    expect(() => PlatformIdentityModel.fromJsonString('[]'), throwsFormatException);
  });

  test('prints no e-mail or name in its text', () {
    final text = '${read(answer())}';

    expect(text, isNot(contains('admin@example.org')));
    expect(text, isNot(contains('Admin')));
  });
}
