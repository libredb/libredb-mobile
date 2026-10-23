import 'package:equatable/equatable.dart';
import 'package:libredb_mobile/shared/models/query_result.dart';

/// A successful connection test: `POST /api/db/test-connection`. A failed test is an error, not a result.
class ConnectionTestResult extends Equatable {
  const ConnectionTestResult({required this.message, this.latency, this.degraded = false, this.warnings = const []});

  final String message;

  /// The round trip Studio measured to the database, absent for a degraded result.
  final Duration? latency;

  /// Studio connected but could not read the server's health.
  final bool degraded;

  /// What the server cautioned while the connection opened, such as Materialize opening a database that does not exist.
  final List<QueryWarning> warnings;

  @override
  List<Object?> get props => [message, latency, degraded, warnings];
}
