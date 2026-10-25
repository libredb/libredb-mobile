import 'dart:convert';

import 'package:libredb_mobile/shared/models/platform_identity.dart';

/// Reads LibreDB Platform's `GET /api/v1/me`: `{id, email, name, roles, permissions, tenant: {id, name, slug}}`
/// (libredb-platform `src/app/api/v1/me/route.ts`).
final class PlatformIdentityModel {
  const PlatformIdentityModel._();

  /// Throws a [FormatException] for a missing or mistyped `id`, `email`, `roles`, `permissions` or `tenant` (or a
  /// tenant's `id`, `name` or `slug`), a non-string role or permission, or a `name` that is neither a string nor null.
  /// The messages name the field, never its value.
  static PlatformIdentity fromJsonString(String body) {
    final json = jsonDecode(body);
    if (json is! Map<String, dynamic>) throw const FormatException('The Platform identity is not an object');
    final tenant = json['tenant'];
    if (tenant is! Map<String, dynamic>) throw const FormatException('The Platform identity has no tenant');
    final name = json['name'];
    if (name != null && name is! String) throw const FormatException('The Platform identity name is not a string');
    return PlatformIdentity(
      id: _string(json, 'id'),
      email: _string(json, 'email'),
      name: name as String?,
      roles: _strings(json, 'roles'),
      permissions: _strings(json, 'permissions'),
      tenant: PlatformTenant(id: _string(tenant, 'id'), name: _string(tenant, 'name'), slug: _string(tenant, 'slug')),
    );
  }

  static String _string(Map<String, dynamic> json, String field) {
    final value = json[field];
    if (value is! String) throw FormatException('The Platform identity has no string $field');
    return value;
  }

  static List<String> _strings(Map<String, dynamic> json, String field) {
    final value = json[field];
    if (value is! List || value.any((element) => element is! String)) {
      throw FormatException('The Platform identity has no list of strings $field');
    }
    return List.unmodifiable(value.cast<String>());
  }
}
