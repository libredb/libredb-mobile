import 'package:equatable/equatable.dart';

/// One governed query event of LibreDB Platform's audit log (`GET /api/v1/audit`, libredb-platform
/// `src/shared/lib/bridge/query-events.ts`): a statement a Studio governed by Platform ran, refused or cancelled.
///
/// [status], [statementType], [source], [statementCapture], [sessionRole], [accessLevel], [engine] and
/// [transactionOutcome] are opaque strings: an unknown value is kept as Platform sent it, and a screen that branches on
/// one matches its known values explicitly.
///
/// [statement] and [errorMessage] can hold a database's data, and [subject], [username] and [connectionName] name a
/// person or a database, so they are held in memory only and never reach a log line.
final class AuditEvent extends Equatable {
  const AuditEvent({
    required this.eventId,
    required this.startedAt,
    required this.finishedAt,
    required this.subject,
    required this.username,
    required this.sessionRole,
    required this.connectionId,
    required this.connectionKnown,
    required this.connectionName,
    required this.engine,
    required this.accessLevel,
    required this.source,
    required this.statementType,
    required this.explain,
    required this.statementCapture,
    required this.statement,
    required this.statementTruncated,
    required this.rowCount,
    required this.durationMs,
    required this.status,
    required this.errorCode,
    required this.errorMessage,
    required this.transactionOutcome,
  });

  /// Platform's id of the event, unique in the audit log.
  final String eventId;

  /// When the statement started, in UTC.
  final DateTime startedAt;

  /// When the statement finished, in UTC.
  final DateTime? finishedAt;

  /// The Keycloak `sub` of the user who ran the statement.
  final String subject;

  /// The Keycloak username Studio recorded, when it recorded one.
  final String? username;

  /// The Studio role of the session, such as `admin` or `user`.
  final String? sessionRole;

  /// The Platform connection id the statement ran on.
  final String connectionId;

  /// False when [connectionId] names no Platform connection; [connectionName] is then `unknown connection`.
  final bool? connectionKnown;

  final String connectionName;

  /// The engine of the connection, such as `postgres`.
  final String? engine;

  /// The grant level the statement ran under, such as `read` or `write`.
  final String? accessLevel;

  /// What sent the statement, such as `studio`; the vocabulary is open.
  final String source;

  /// `SELECT`, `INSERT`, `UPDATE`, `DELETE`, `DDL` or `OTHER`.
  final String statementType;

  /// The explain mode of the statement, when it was one.
  final String? explain;

  /// How much of the statement Platform recorded: `none`, `redacted` or `full`.
  final String statementCapture;

  /// The recorded statement, null when [statementCapture] is `none`.
  final String? statement;

  /// Whether Platform cut [statement] to its stored length.
  final bool statementTruncated;

  final int? rowCount;
  final int durationMs;

  /// `success`, `error`, `cancelled` or `refused`.
  final String status;

  final String? errorCode;

  /// The database's error text, which can quote the statement.
  final String? errorMessage;

  /// How the transaction of the statement ended, when it ran in one.
  final String? transactionOutcome;

  @override
  List<Object?> get props => [
    eventId,
    startedAt,
    finishedAt,
    subject,
    username,
    sessionRole,
    connectionId,
    connectionKnown,
    connectionName,
    engine,
    accessLevel,
    source,
    statementType,
    explain,
    statementCapture,
    statement,
    statementTruncated,
    rowCount,
    durationMs,
    status,
    errorCode,
    errorMessage,
    transactionOutcome,
  ];

  /// Only the id and the status: this text can reach a log.
  @override
  String toString() => 'AuditEvent(eventId: $eventId, status: $status)';
}
