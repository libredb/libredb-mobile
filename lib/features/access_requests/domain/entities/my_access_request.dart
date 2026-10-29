import 'package:equatable/equatable.dart';

/// What became of an access request, as far as this app knows the vocabulary.
///
/// Platform's `status` is an opaque string, so a value this app does not know reads as [unknown] and
/// [MyAccessRequest.rawStatus] keeps what Platform sent, for a screen to show.
enum AccessRequestStatus {
  pending,
  approved,
  refused,
  withdrawn,
  expired,

  /// A status Platform sent that this app does not know; [MyAccessRequest.rawStatus] holds it.
  unknown;

  /// [raw] as one of the known statuses, or [unknown]. The match is exact: Platform sends them lower-cased.
  static AccessRequestStatus of(String raw) => switch (raw) {
    'pending' => AccessRequestStatus.pending,
    'approved' => AccessRequestStatus.approved,
    'refused' => AccessRequestStatus.refused,
    'withdrawn' => AccessRequestStatus.withdrawn,
    'expired' => AccessRequestStatus.expired,
    _ => AccessRequestStatus.unknown,
  };
}

/// One access request of the signed-in Studio user, as LibreDB Platform's requester routes answer it.
///
/// It holds no requester: the requester is the caller, so Platform's `requester` object, which carries a username and
/// an e-mail address, is never read. [level] and [connectionStatus] are opaque strings, kept as Platform sent them.
final class MyAccessRequest extends Equatable {
  const MyAccessRequest({
    required this.id,
    required this.connectionId,
    required this.connectionName,
    required this.connectionEngine,
    required this.connectionStatus,
    required this.level,
    required this.reason,
    required this.status,
    required this.rawStatus,
    required this.createdAt,
    required this.decidedAt,
    required this.decisionReason,
    required this.grantId,
  });

  /// The request id, which a withdrawal names.
  final String id;

  final String connectionId;

  final String connectionName;

  /// The engine, kept as Platform sent it.
  final String connectionEngine;

  /// The connection's status, kept as Platform sent it; `active` and `inactive` are known.
  final String connectionStatus;

  /// The level asked for, kept as Platform sent it; `read` and `write` are known.
  final String level;

  /// The free text the user wrote when asking. It never reaches a log.
  final String reason;

  final AccessRequestStatus status;

  /// Platform's `status` as it was sent, which a screen shows when [status] is [AccessRequestStatus.unknown].
  final String rawStatus;

  final DateTime createdAt;

  /// Null while the request waits for a decision.
  final DateTime? decidedAt;

  /// The text the admin wrote when deciding, or null. It never reaches a log.
  final String? decisionReason;

  /// The grant an approval created, or null.
  final String? grantId;

  @override
  List<Object?> get props => [
    id,
    connectionId,
    connectionName,
    connectionEngine,
    connectionStatus,
    level,
    reason,
    status,
    rawStatus,
    createdAt,
    decidedAt,
    decisionReason,
    grantId,
  ];

  /// No reason, decision reason or connection name: this text can reach a log.
  @override
  String toString() => 'MyAccessRequest(id: $id, status: $rawStatus, level: $level)';
}
