import 'dart:convert';

import 'package:libredb_mobile/features/connections/domain/entities/studio_connection.dart';

/// Reads the body of Studio's `GET /api/connections/managed`: `{"connections": [...], "cacheHint": ..., ...}`.
final class ManagedConnections {
  const ManagedConnections._();

  /// Throws a [FormatException] when the body has no `connections` list, or a connection lacks its id, name or type.
  static List<StudioConnection> fromJsonString(String body) {
    final decoded = jsonDecode(body);
    final connections = decoded is Map<String, dynamic> ? decoded['connections'] : null;
    if (connections is! List) throw const FormatException('The managed connections body has no connections list');
    return [for (final item in connections) _connection(item)];
  }

  static StudioConnection _connection(Object? item) {
    if (item is! Map<String, dynamic>) throw const FormatException('A managed connection is not an object');
    final id = item['id'];
    final name = item['name'];
    final type = item['type'];
    if (id is! String || name is! String || type is! String) {
      throw const FormatException('A managed connection lacks its id, name or type');
    }
    return StudioConnection(
      id: id,
      name: name,
      type: type,
      host: _string(item['host']),
      port: item['port'] is int ? item['port'] as int : null,
      database: _string(item['database']),
      environment: _string(item['environment']),
      group: _string(item['group']),
    );
  }

  static String? _string(Object? value) => value is String && value.isNotEmpty ? value : null;
}
