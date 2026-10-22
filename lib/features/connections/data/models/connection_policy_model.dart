import 'dart:convert';

import 'package:flutter_bloc_advance/features/connections/domain/entities/connection_policy.dart';

/// Reads `GET /api/connections/policy`: `{customConnections, governance?: true, statementCapture?}`.
final class ConnectionPolicyModel {
  const ConnectionPolicyModel._();

  /// Throws a [FormatException] when `customConnections` is not a boolean.
  static ConnectionPolicy fromJsonString(String body) {
    final decoded = jsonDecode(body);
    final custom = decoded is Map<String, dynamic> ? decoded['customConnections'] : null;
    if (custom is! bool) throw const FormatException('The connection policy has no customConnections flag');
    final capture = (decoded as Map<String, dynamic>)['statementCapture'];
    return ConnectionPolicy(
      customConnections: custom,
      governance: decoded['governance'] == true,
      statementCapture: capture is String ? capture : null,
    );
  }
}
