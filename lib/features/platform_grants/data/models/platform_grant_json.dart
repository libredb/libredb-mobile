import 'dart:convert';

import 'package:libredb_mobile/features/platform_grants/domain/entities/platform_grant.dart';

/// Reads LibreDB Platform's `GET /api/v1/connections/{id}/grants`: `{"grants": [{id, subject, subjectUsername,
/// subjectEmail, level, expiresAt, grantedBy {id, name, email}, grantedAt}]}`, by username (libredb-platform
/// `src/features/connections/lib/grant-service.ts`, `docs/api/v1.md`).
final class PlatformGrantJson {
  const PlatformGrantJson._();

  /// The grants in Platform's order.
  ///
  /// Throws a [FormatException] when the body has no `grants` list, or a grant lacks a required field or carries it
  /// with the wrong type, or a date cannot be read. `subjectEmail`, `expiresAt` and `grantedBy.name` may be null, and
  /// one of an unexpected type is left out. The messages name the field, never a value.
  static List<PlatformGrant> read(String body) {
    final decoded = jsonDecode(body);
    final grants = decoded is Map<String, dynamic> ? decoded['grants'] : null;
    if (grants is! List) throw const FormatException('The Platform grants body has no grants list');
    return List.unmodifiable([for (final item in grants) _grant(item)]);
  }

  static PlatformGrant _grant(Object? item) {
    if (item is! Map<String, dynamic>) throw const FormatException('A Platform grant is not an object');
    final granter = item['grantedBy'];
    if (granter is! Map<String, dynamic>) throw const FormatException('A Platform grant has no object grantedBy');
    final expiresAt = item['expiresAt'];
    return PlatformGrant(
      id: _string(item, 'id'),
      subject: _string(item, 'subject'),
      subjectUsername: _string(item, 'subjectUsername'),
      subjectEmail: _optionalString(item, 'subjectEmail'),
      level: _string(item, 'level'),
      expiresAt: expiresAt is String ? _date(expiresAt, 'expiresAt') : null,
      grantedBy: PlatformGrantGranter(
        id: _string(granter, 'id', owner: 'grantedBy'),
        name: _optionalString(granter, 'name'),
        email: _string(granter, 'email', owner: 'grantedBy'),
      ),
      grantedAt: _date(_string(item, 'grantedAt'), 'grantedAt'),
    );
  }

  static String _string(Map<String, dynamic> item, String field, {String owner = 'grant'}) {
    final value = item[field];
    if (value is! String) throw FormatException('A Platform $owner has no string $field');
    return value;
  }

  static String? _optionalString(Map<String, dynamic> item, String field) {
    final value = item[field];
    return value is String ? value : null;
  }

  static DateTime _date(String value, String field) =>
      DateTime.tryParse(value) ?? (throw FormatException('A Platform grant has an unreadable $field'));
}
