import 'package:equatable/equatable.dart';

/// How a run that reached Studio ended. The database's error text is never kept, since it can echo data.
enum StatementRunStatus { success, failure }

/// One run in the device's statement history.
///
/// [text] is null when the statement was longer than the store keeps for one entry; [textTooLong] then marks the
/// entry.
class StatementHistoryEntry extends Equatable {
  const StatementHistoryEntry({
    required this.id,
    required this.connectionId,
    required this.connectionName,
    required this.text,
    this.textTooLong = false,
    required this.status,
    required this.duration,
    this.rowCount,
    required this.executedAt,
  });

  final String id;
  final String connectionId;
  final String connectionName;
  final String? text;
  final bool textTooLong;
  final StatementRunStatus status;
  final Duration duration;
  final int? rowCount;
  final DateTime executedAt;

  /// This entry without its text, marked as too long to keep.
  StatementHistoryEntry withoutText() => StatementHistoryEntry(
    id: id,
    connectionId: connectionId,
    connectionName: connectionName,
    text: null,
    textTooLong: true,
    status: status,
    duration: duration,
    rowCount: rowCount,
    executedAt: executedAt,
  );

  @override
  List<Object?> get props => [
    id,
    connectionId,
    connectionName,
    text,
    textTooLong,
    status,
    duration,
    rowCount,
    executedAt,
  ];

  /// Prints the length of the text, never the text, which can hold customer data in its literals.
  @override
  String toString() =>
      'StatementHistoryEntry($id, ${text?.length ?? 'no'} characters, ${status.name}, ${duration.inMilliseconds} ms)';
}
