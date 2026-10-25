import 'package:equatable/equatable.dart';

/// The connection a grant is set on, as the grant editor needs it: built by the grants page from the connection it
/// shows, so this feature never reads another feature's model.
///
/// [active] is false only for a connection whose status is exactly `inactive`, because Platform gates every other
/// status as active (libredb-platform `src/shared/lib/license/seats.ts`).
final class GrantTarget extends Equatable {
  const GrantTarget({
    required this.connectionId,
    required this.connectionName,
    required this.hasWriteCredential,
    required this.active,
  });

  /// The target of a connection with Platform's [status], an opaque string.
  factory GrantTarget.fromStatus({
    required String connectionId,
    required String connectionName,
    required bool hasWriteCredential,
    required String status,
  }) => GrantTarget(
    connectionId: connectionId,
    connectionName: connectionName,
    hasWriteCredential: hasWriteCredential,
    active: status != 'inactive',
  );

  final String connectionId;
  final String connectionName;

  /// Whether the connection has a write credential, without which Platform refuses a `write` grant.
  final bool hasWriteCredential;

  final bool active;

  @override
  List<Object?> get props => [connectionId, connectionName, hasWriteCredential, active];

  /// Not the name: this text can reach a log.
  @override
  String toString() =>
      'GrantTarget(connectionId: $connectionId, hasWriteCredential: $hasWriteCredential, '
      'active: $active)';
}
