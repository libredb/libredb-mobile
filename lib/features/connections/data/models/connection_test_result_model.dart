import 'dart:convert';

import 'package:libredb_mobile/features/connections/domain/entities/connection_test_result.dart';
import 'package:libredb_mobile/shared/models/query_result.dart';

/// Reads a successful `POST /api/db/test-connection`: `{success: true, message, latency, warnings?}` or `{success: true,
/// degraded: true, message, warnings?}`. Studio reports a failed connect as an error status, never as `success: false`
/// with a 2xx.
final class ConnectionTestResultModel {
  const ConnectionTestResultModel._();

  /// Throws a [FormatException] for an answer without `success: true` or a message, and for a `warnings` that is present
  /// but not a list, as `QueryResultJson` does, so a caution is never hidden; absent, it reads as none. A warning without
  /// a string message is left out, a code is carried as its text, and a severity that is not a string is left out.
  static ConnectionTestResult fromJsonString(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic> || decoded['success'] != true || decoded['message'] is! String) {
      throw const FormatException('The connection test answer is not a success');
    }
    final latency = decoded['latency'];
    final warnings = decoded['warnings'];
    if (decoded.containsKey('warnings') && warnings is! List) {
      throw const FormatException('The warnings are not a list');
    }
    return ConnectionTestResult(
      message: decoded['message'] as String,
      latency: latency is num ? Duration(milliseconds: latency.round()) : null,
      degraded: decoded['degraded'] == true,
      warnings: [
        if (warnings is List)
          for (final item in warnings) ?_warning(item),
      ],
    );
  }

  static QueryWarning? _warning(Object? value) {
    if (value is! Map) return null;
    final message = value['message'];
    if (message is! String) return null;
    final code = value['code'];
    final severity = value['severity'];
    return QueryWarning(
      message: message,
      // Carried verbatim, as QueryResultJson does: some engines number their warnings, others label them.
      code: code == null ? null : '$code',
      severity: severity is String ? severity : null,
    );
  }
}
