import 'package:equatable/equatable.dart';

/// What Studio allows for connections: `GET /api/connections/policy`.
class ConnectionPolicy extends Equatable {
  const ConnectionPolicy({required this.customConnections, required this.governance, this.statementCapture});

  /// Whether a request may carry a connection of the user's own instead of naming a managed one. Always false under
  /// governance; the app sends managed connections only either way.
  final bool customConnections;

  /// Whether Platform governs this Studio: the connections are the user's grants, and statements are recorded.
  final bool governance;

  /// The [statementCapture] of a governance that records each statement in full, which the app tells the user.
  static const statementCaptureFull = 'full';

  /// How much of each statement governance records (`none`, `redacted` or `full`), shown to the user; Studio's other
  /// values pass through unread.
  final String? statementCapture;

  @override
  List<Object?> get props => [customConnections, governance, statementCapture];

  /// The flags only: a field named for a statement stays out of every text that can reach a log.
  @override
  String toString() => 'ConnectionPolicy(customConnections: $customConnections, governance: $governance)';
}
