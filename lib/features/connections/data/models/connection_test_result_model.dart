import 'dart:convert';

import 'package:libredb_mobile/features/connections/domain/entities/connection_test_result.dart';
import 'package:libredb_mobile/shared/models/query_result.dart';

/// Reads a successful `POST /api/db/test-connection`: `{success: true, message, latency, warnings?}` or `{success: true,
/// degraded: true, message, warnings?}`. Studio reports a failed connect as an error status, never as `success: false`
/// with a 2xx.
final class ConnectionTestResultModel {
  const ConnectionTestResultModel._();

  /// Throws a [FormatException] for an answer without `success: true` or a message. A `warnings` that is not a list
  /// reads as none, and a warning without a string message is left out, as are a code that is neither a string nor a
  /// number and a severity that is not a string.
  static ConnectionTestResult fromJsonString(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic> || decoded['success'] != true || decoded['message'] is! String) {
      throw const FormatException('The connection test answer is not a success');
    }
    final latency = decoded['latency'];
    final warnings = decoded['warnings'];
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
      // Carried verbatim: some engines number their warnings, others label them.
      code: code is String || code is num ? '$code' : null,
      severity: severity is String ? severity : null,
    );
  }
}
