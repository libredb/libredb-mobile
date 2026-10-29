import 'dart:convert';

import 'package:libredb_mobile/features/access_requests/domain/entities/requestable_connection.dart';

/// Reads LibreDB Platform's `GET /api/v1/requester/connections`: `{"connections": [{id, name, engine,
/// hasWriteCredential, access: {level, expiresAt} | null, pendingRequestId: string | null}]}`, the active connections
/// of the install by name.
final class RequestableConnectionsJson {
  const RequestableConnectionsJson._();

  /// The connections in Platform's order.
  ///
  /// Throws a [FormatException] when the body has no `connections` list, a connection lacks a required field or
  /// carries it with the wrong type, an `access` object lacks its `level`, or a date cannot be read. `access` and
  /// `pendingRequestId` may be null, and one of an unexpected type is left out. The messages name the field, never a
  /// value.
  static List<RequestableConnection> read(String body) {
    final decoded = jsonDecode(body);
    final connections = decoded is Map<String, dynamic> ? decoded['connections'] : null;
    if (connections is! List) throw const FormatException('The Platform requester connections body has no list');
    return List.unmodifiable([for (final item in connections) _connection(item)]);
  }

  static RequestableConnection _connection(Object? item) {
    if (item is! Map<String, dynamic>) throw const FormatException('A requestable connection is not an object');
    final hasWriteCredential = item['hasWriteCredential'];
    if (hasWriteCredential is! bool) {
      throw const FormatException('A requestable connection has no boolean hasWriteCredential');
    }
    final pendingRequestId = item['pendingRequestId'];
    return RequestableConnection(
      id: _string(item, 'id'),
      name: _string(item, 'name'),
      engine: _string(item, 'engine'),
      hasWriteCredential: hasWriteCredential,
      access: _access(item['access']),
      pendingRequestId: pendingRequestId is String ? pendingRequestId : null,
    );
  }

  /// The access object, or null when it is absent, JSON null or of another type.
  static ConnectionAccess? _access(Object? value) {
    if (value is! Map<String, dynamic>) return null;
    final expiresAt = value['expiresAt'];
    return ConnectionAccess(
      level: _string(value, 'level', owner: 'requestable connection access'),
      expiresAt: expiresAt is String ? _date(expiresAt, 'expiresAt') : null,
    );
  }

  static String _string(Map<String, dynamic> item, String field, {String owner = 'requestable connection'}) {
    final value = item[field];
    if (value is! String) throw FormatException('A $owner has no string $field');
    return value;
  }

  static DateTime _date(String value, String field) =>
      DateTime.tryParse(value) ?? (throw FormatException('A requestable connection has an unreadable $field'));
}
