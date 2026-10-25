import 'dart:convert';

import 'package:libredb_mobile/shared/models/platform_connection.dart';

/// Reads LibreDB Platform's `GET /api/v1/connections`: `{"connections": [{id, name, engine, status,
/// hasWriteCredential}]}`, newest first (libredb-platform `src/features/connections/lib/grant-service.ts`).
final class PlatformConnectionsModel {
  const PlatformConnectionsModel._();

  /// The connections in Platform's order.
  ///
  /// Throws a [FormatException] when the body has no `connections` list, or an item lacks a string `id`, `name`,
  /// `engine` or `status` or a bool `hasWriteCredential`. The messages name the field, never a value.
  static List<PlatformConnection> read(String body) {
    final decoded = jsonDecode(body);
    final connections = decoded is Map<String, dynamic> ? decoded['connections'] : null;
    if (connections is! List) throw const FormatException('The Platform connections body has no connections list');
    return List.unmodifiable([for (final item in connections) _connection(item)]);
  }

  static PlatformConnection _connection(Object? item) {
    if (item is! Map<String, dynamic>) throw const FormatException('A Platform connection is not an object');
    final hasWriteCredential = item['hasWriteCredential'];
    if (hasWriteCredential is! bool) {
      throw const FormatException('A Platform connection has no bool hasWriteCredential');
    }
    return PlatformConnection(
      id: _string(item, 'id'),
      name: _string(item, 'name'),
      engine: _string(item, 'engine'),
      status: _string(item, 'status'),
      hasWriteCredential: hasWriteCredential,
    );
  }

  static String _string(Map<String, dynamic> item, String field) {
    final value = item[field];
    if (value is! String) throw FormatException('A Platform connection has no string $field');
    return value;
  }
}
