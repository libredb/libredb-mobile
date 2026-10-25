import 'package:equatable/equatable.dart';

/// A connection of the install tenant as LibreDB Platform's `GET /api/v1/connections` lists it (libredb-platform
/// `src/features/connections/lib/grant-service.ts`): no host, credential or sealed value, which Platform never sends.
///
/// It lives in `shared/` because the connection list hands it to the grants page of another feature as route `extra`.
/// [engine] and [status] are opaque strings, kept as Platform sent them, an unknown value included.
final class PlatformConnection extends Equatable {
  const PlatformConnection({
    required this.id,
    required this.name,
    required this.engine,
    required this.status,
    required this.hasWriteCredential,
  });

  final String id;
  final String name;

  /// Platform's engine id, such as `postgres` or `redis`.
  final String engine;

  /// `active` or `inactive` today.
  final String status;

  /// Whether the connection has a write credential, without which Platform grants only `read`.
  final bool hasWriteCredential;

  bool get isActive => status == 'active';

  bool get isInactive => status == 'inactive';

  @override
  List<Object?> get props => [id, name, engine, status, hasWriteCredential];

  /// Not the name: this text can reach a log.
  @override
  String toString() =>
      'PlatformConnection(id: $id, engine: $engine, status: $status, hasWriteCredential: $hasWriteCredential)';
}
