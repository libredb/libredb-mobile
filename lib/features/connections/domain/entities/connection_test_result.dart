import 'package:equatable/equatable.dart';

/// A successful connection test: `POST /api/db/test-connection`. A failed test is an error, not a result.
class ConnectionTestResult extends Equatable {
  const ConnectionTestResult({required this.message, this.latency, this.degraded = false});

  final String message;

  /// The round trip Studio measured to the database, absent for a degraded result.
  final Duration? latency;

  /// Studio connected but could not read the server's health.
  final bool degraded;

  @override
  List<Object?> get props => [message, latency, degraded];
}
