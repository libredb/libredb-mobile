import 'package:equatable/equatable.dart';

/// A connection a Studio user may ask for, as LibreDB Platform's `GET /api/v1/requester/connections` lists it: an
/// active connection of the install, with what the caller already holds on it.
///
/// [engine] is opaque: `postgres`, `mysql` and the rest are known, and an unknown value is kept as Platform sent it.
/// [access] is null when the caller holds no grant on the connection, and [pendingRequestId] is null when the caller
/// has no open request for it.
final class RequestableConnection extends Equatable {
  const RequestableConnection({
    required this.id,
    required this.name,
    required this.engine,
    required this.hasWriteCredential,
    required this.access,
    required this.pendingRequestId,
  });

  /// The connection id, which a request names.
  final String id;

  final String name;

  /// The engine, kept as Platform sent it.
  final String engine;

  /// Whether the install holds a write credential for the connection; without one, write cannot be asked for.
  final bool hasWriteCredential;

  /// The access the caller already holds, or null when they hold none.
  final ConnectionAccess? access;

  /// The id of the caller's open request for this connection, or null when there is none.
  final String? pendingRequestId;

  @override
  List<Object?> get props => [id, name, engine, hasWriteCredential, access, pendingRequestId];

  /// No connection name: this text can reach a log.
  @override
  String toString() => 'RequestableConnection(id: $id, level: ${access?.level})';
}

/// The access a requester already holds on a connection: a [level], kept as Platform sent it, until [expiresAt], or
/// without end when it is null.
final class ConnectionAccess extends Equatable {
  const ConnectionAccess({required this.level, required this.expiresAt});

  final String level;

  /// Null for access that does not expire.
  final DateTime? expiresAt;

  @override
  List<Object?> get props => [level, expiresAt];

  @override
  String toString() => 'ConnectionAccess(level: $level, expiresAt: $expiresAt)';
}
