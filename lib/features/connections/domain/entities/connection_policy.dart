import 'package:equatable/equatable.dart';

/// What Studio allows for connections: `GET /api/connections/policy`.
class ConnectionPolicy extends Equatable {
  const ConnectionPolicy({required this.customConnections, required this.governance, this.statementCapture});

  /// Whether a request may carry a connection of the user's own instead of naming a managed one. Always false under
  /// governance; the app sends managed connections only either way.
  final bool customConnections;

  /// Whether Platform governs this Studio: the connections are the user's grants, and statements are recorded.
  final bool governance;

  /// How much of each statement governance records (`none`, or Platform's capture setting), shown to the user.
  final String? statementCapture;

  @override
  List<Object?> get props => [customConnections, governance, statementCapture];
}
