import 'dart:convert';

import 'package:libredb_mobile/features/platform_grants/domain/entities/directory_page.dart';
import 'package:libredb_mobile/features/platform_grants/domain/entities/directory_user.dart';

/// Reads LibreDB Platform's `GET /api/v1/directory/users`: `{"users": [{id, username, email, firstName, lastName,
/// enabled, studioRole, needsSeat}], "page", "total"}` (libredb-platform
/// `src/features/connections/lib/grant.schema.ts`, `docs/api/v1.md`).
final class DirectoryPageJson {
  const DirectoryPageJson._();

  /// The page Platform answered, its users in Platform's order.
  ///
  /// Throws a [FormatException] when the body lacks a `users` list or an integer `page` or `total`, or a user lacks a
  /// string `id` or `username` or a bool `enabled` or `needsSeat`. `email`, `firstName`, `lastName` and `studioRole`
  /// read as null when absent or of another type. The messages name the field, never a value.
  static DirectoryPage read(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) throw const FormatException('The Platform directory body is not an object');
    final users = decoded['users'];
    if (users is! List) throw const FormatException('The Platform directory body has no users list');
    return DirectoryPage(
      users: List.unmodifiable([for (final item in users) _user(item)]),
      page: _int(decoded, 'page'),
      total: _int(decoded, 'total'),
    );
  }

  static DirectoryUser _user(Object? item) {
    if (item is! Map<String, dynamic>) throw const FormatException('A Platform directory user is not an object');
    return DirectoryUser(
      id: _string(item, 'id'),
      username: _string(item, 'username'),
      email: _optionalString(item, 'email'),
      firstName: _optionalString(item, 'firstName'),
      lastName: _optionalString(item, 'lastName'),
      enabled: _bool(item, 'enabled'),
      studioRole: _optionalString(item, 'studioRole'),
      needsSeat: _bool(item, 'needsSeat'),
    );
  }

  static int _int(Map<String, dynamic> body, String field) {
    final value = body[field];
    if (value is! int) throw FormatException('The Platform directory body has no integer $field');
    return value;
  }

  static String _string(Map<String, dynamic> item, String field) {
    final value = item[field];
    if (value is! String) throw FormatException('A Platform directory user has no string $field');
    return value;
  }

  static bool _bool(Map<String, dynamic> item, String field) {
    final value = item[field];
    if (value is! bool) throw FormatException('A Platform directory user has no bool $field');
    return value;
  }

  static String? _optionalString(Map<String, dynamic> item, String field) {
    final value = item[field];
    return value is String ? value : null;
  }
}
