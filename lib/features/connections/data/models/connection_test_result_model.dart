import 'dart:convert';

import 'package:libredb_mobile/features/connections/domain/entities/connection_test_result.dart';

/// Reads a successful `POST /api/db/test-connection`: `{success: true, message, latency}` or `{success: true, degraded:
/// true, message}`. Studio reports a failed connect as an error status, never as `success: false` with a 2xx.
final class ConnectionTestResultModel {
  const ConnectionTestResultModel._();

  /// Throws a [FormatException] for an answer without `success: true` or a message.
  static ConnectionTestResult fromJsonString(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic> || decoded['success'] != true || decoded['message'] is! String) {
      throw const FormatException('The connection test answer is not a success');
    }
    final latency = decoded['latency'];
    return ConnectionTestResult(
      message: decoded['message'] as String,
      latency: latency is num ? Duration(milliseconds: latency.round()) : null,
      degraded: decoded['degraded'] == true,
    );
  }
}
