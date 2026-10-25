import 'dart:convert';

import 'package:libredb_mobile/features/platform_audit/domain/entities/audit_event.dart';
import 'package:libredb_mobile/features/platform_audit/domain/entities/audit_page.dart';

/// Reads LibreDB Platform's `GET /api/v1/audit`: `{"events": [...], "total"}`, each event as libredb-platform
/// `src/shared/lib/bridge/query-events.ts` builds it, its times as ISO strings (`docs/api/v1.md`).
final class AuditPageJson {
  const AuditPageJson._();

  /// The page Platform answered for a request from [offset], its events in Platform's order.
  ///
  /// Throws a [FormatException] when the body lacks an `events` list or an integer `total`, or an event lacks a string
  /// `eventId`, `subject`, `connectionId`, `connectionName`, `source`, `statementType`, `status` or
  /// `statementCapture`, an ISO time `startedAt`, a bool `statementTruncated` or an integer `durationMs`. Every other
  /// field reads as null when absent or of another type. The messages name the field, never a value, since an event
  /// holds statements and names people.
  static AuditPage read(String body, {required int offset}) {
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) throw const FormatException('The Platform audit body is not an object');
    final events = decoded['events'];
    if (events is! List) throw const FormatException('The Platform audit body has no events list');
    final total = decoded['total'];
    if (total is! int) throw const FormatException('The Platform audit body has no integer total');
    return AuditPage(
      events: List.unmodifiable([for (final item in events) _event(item)]),
      total: total,
      offset: offset,
    );
  }

  static AuditEvent _event(Object? item) {
    if (item is! Map<String, dynamic>) throw const FormatException('A Platform audit event is not an object');
    final startedAt = _time(item['startedAt']);
    if (startedAt == null) throw const FormatException('A Platform audit event has no ISO time startedAt');
    return AuditEvent(
      eventId: _string(item, 'eventId'),
      startedAt: startedAt,
      finishedAt: _time(item['finishedAt']),
      subject: _string(item, 'subject'),
      username: _optional<String>(item, 'username'),
      sessionRole: _optional<String>(item, 'sessionRole'),
      connectionId: _string(item, 'connectionId'),
      connectionKnown: _optional<bool>(item, 'connectionKnown'),
      connectionName: _string(item, 'connectionName'),
      engine: _optional<String>(item, 'engine'),
      accessLevel: _optional<String>(item, 'accessLevel'),
      source: _string(item, 'source'),
      statementType: _string(item, 'statementType'),
      explain: _optional<String>(item, 'explain'),
      statementCapture: _string(item, 'statementCapture'),
      statement: _optional<String>(item, 'statement'),
      statementTruncated: _bool(item, 'statementTruncated'),
      rowCount: _optional<int>(item, 'rowCount'),
      durationMs: _int(item, 'durationMs'),
      status: _string(item, 'status'),
      errorCode: _optional<String>(item, 'errorCode'),
      errorMessage: _optional<String>(item, 'errorMessage'),
      transactionOutcome: _optional<String>(item, 'transactionOutcome'),
    );
  }

  static String _string(Map<String, dynamic> item, String field) {
    final value = item[field];
    if (value is! String) throw FormatException('A Platform audit event has no string $field');
    return value;
  }

  static bool _bool(Map<String, dynamic> item, String field) {
    final value = item[field];
    if (value is! bool) throw FormatException('A Platform audit event has no bool $field');
    return value;
  }

  static int _int(Map<String, dynamic> item, String field) {
    final value = item[field];
    if (value is! int) throw FormatException('A Platform audit event has no integer $field');
    return value;
  }

  static T? _optional<T>(Map<String, dynamic> item, String field) {
    final value = item[field];
    return value is T ? value : null;
  }

  /// [value] as a UTC time when it is an ISO 8601 string, otherwise null.
  static DateTime? _time(Object? value) => value is String ? DateTime.tryParse(value)?.toUtc() : null;
}
