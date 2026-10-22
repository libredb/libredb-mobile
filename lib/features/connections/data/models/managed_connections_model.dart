import 'dart:convert';

import 'package:libredb_mobile/features/connections/domain/entities/managed_connections.dart';
import 'package:libredb_mobile/shared/models/studio_connection.dart';

/// Reads the body of Studio's `GET /api/connections/managed`: `{"connections": [...], "cacheHint": ..., ...}`.
///
/// Studio before libredb-studio#1922 sends the credentials of an unmanaged seed (`managed: false`) to a bearer client,
/// such as `user`, `password`, `connectionString` and `apiKeySecret`. The reader reads only the fields it names, so none
/// of them is ever kept.
final class ManagedConnectionsModel {
  const ManagedConnectionsModel._();

  /// The color format Studio accepts for a seed and a governed connection.
  static final _hexColor = RegExp(r'^#[0-9A-Fa-f]{6}$');

  /// Throws a [FormatException] when the body has no `connections` list, or a connection lacks its id, name or type.
  static ManagedConnections read(String body) {
    final decoded = jsonDecode(body);
    final connections = decoded is Map<String, dynamic> ? decoded['connections'] : null;
    if (connections is! List) throw const FormatException('The managed connections body has no connections list');
    final cacheHint = (decoded as Map<String, dynamic>)['cacheHint'];
    return ManagedConnections(
      connections: [for (final item in connections) _connection(item)],
      cacheHint: cacheHint is num && cacheHint.isFinite && cacheHint >= 0
          ? Duration(milliseconds: cacheHint.round())
          : null,
    );
  }

  static StudioConnection _connection(Object? item) {
    if (item is! Map<String, dynamic>) throw const FormatException('A managed connection is not an object');
    final id = item['id'];
    final name = item['name'];
    final type = item['type'];
    if (id is! String || name is! String || type is! String) {
      throw const FormatException('A managed connection lacks its id, name or type');
    }
    final color = _string(item['color']);
    return StudioConnection(
      id: id,
      name: name,
      type: type,
      host: _string(item['host']),
      port: item['port'] is int ? item['port'] as int : null,
      database: _string(item['database']),
      environment: _string(item['environment']),
      group: _string(item['group']),
      color: color != null && _hexColor.hasMatch(color) ? color : null,
      readOnly: item['readOnly'] == true,
      managed: item['managed'] == true,
      seedId: _string(item['seedId']),
    );
  }

  static String? _string(Object? value) => value is String && value.isNotEmpty ? value : null;
}
