import 'dart:convert';

import 'package:libredb_mobile/features/access_requests/domain/entities/my_access_request.dart';

/// Reads LibreDB Platform's requester answers about an access request: `{"requests": [AccessRequest]}` from
/// `GET /api/v1/requester/access-requests`, and `{"request": AccessRequest}` from the create and the withdrawal.
///
/// Platform's `requester` object carries a username and an e-mail address, and the requester is the caller here, so it
/// is never read; neither is `decidedBy`.
final class AccessRequestJson {
  const AccessRequestJson._();

  /// The caller's requests in Platform's order, newest first.
  ///
  /// Throws a [FormatException] when the body has no `requests` list, a request lacks a required field or carries it
  /// with the wrong type, or a date cannot be read. `decidedAt`, `decisionReason` and `grantId` may be null, and one
  /// of an unexpected type is left out. The messages name the field, never a value.
  static List<MyAccessRequest> readList(String body) {
    final decoded = jsonDecode(body);
    final requests = decoded is Map<String, dynamic> ? decoded['requests'] : null;
    if (requests is! List) throw const FormatException('The Platform access requests body has no requests list');
    return List.unmodifiable([for (final item in requests) _request(item)]);
  }

  /// The one request a create or a withdrawal answers, whatever its 2xx status.
  ///
  /// Throws a [FormatException] under the same rules as [readList].
  static MyAccessRequest readOne(String body) {
    final decoded = jsonDecode(body);
    final request = decoded is Map<String, dynamic> ? decoded['request'] : null;
    if (request == null) throw const FormatException('The Platform access request body has no request object');
    return _request(request);
  }

  static MyAccessRequest _request(Object? item) {
    if (item is! Map<String, dynamic>) throw const FormatException('An access request is not an object');
    final connection = item['connection'];
    if (connection is! Map<String, dynamic>) {
      throw const FormatException('An access request has no object connection');
    }
    final rawStatus = _string(item, 'status');
    final decidedAt = item['decidedAt'];
    final decisionReason = item['decisionReason'];
    final grantId = item['grantId'];
    return MyAccessRequest(
      id: _string(item, 'id'),
      connectionId: _string(connection, 'id', owner: 'access request connection'),
      connectionName: _string(connection, 'name', owner: 'access request connection'),
      connectionEngine: _string(connection, 'engine', owner: 'access request connection'),
      connectionStatus: _string(connection, 'status', owner: 'access request connection'),
      level: _string(item, 'level'),
      reason: _string(item, 'reason'),
      status: AccessRequestStatus.of(rawStatus),
      rawStatus: rawStatus,
      createdAt: _date(_string(item, 'createdAt'), 'createdAt'),
      decidedAt: decidedAt is String ? _date(decidedAt, 'decidedAt') : null,
      decisionReason: decisionReason is String ? decisionReason : null,
      grantId: grantId is String ? grantId : null,
    );
  }

  static String _string(Map<String, dynamic> item, String field, {String owner = 'access request'}) {
    final value = item[field];
    if (value is! String) throw FormatException('An $owner has no string $field');
    return value;
  }

  static DateTime _date(String value, String field) =>
      DateTime.tryParse(value) ?? (throw FormatException('An access request has an unreadable $field'));
}
