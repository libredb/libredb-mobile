import 'package:equatable/equatable.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/sql_editor/domain/entities/statement_history_entry.dart';

/// A run that reached Studio, as the history keeps it: never the database's error text, only whether it failed, since
/// that text can echo data.
class FinishedRun extends Equatable {
  const FinishedRun({
    required this.connectionId,
    required this.connectionName,
    required this.text,
    required this.status,
    required this.duration,
    this.rowCount,
  });

  final String connectionId;
  final String connectionName;

  /// The text that was sent, whole; a script's whole text.
  final String text;
  final StatementRunStatus status;
  final Duration duration;

  /// The rows the answer counted, when it counted any.
  final int? rowCount;

  @override
  List<Object?> get props => [connectionId, connectionName, text, status, duration, rowCount];

  /// Prints the length of the text, never the text, which can hold customer data in its literals.
  @override
  String toString() => 'FinishedRun(${text.length} characters, ${status.name}, ${duration.inMilliseconds} ms)';
}

/// The statements each account ran from this phone, newest first, kept only on the phone.
///
/// Every call names the account by `subjectHash(StudioIdentity.subject)` (`lib/shared/utils/subject_hash.dart`), taken
/// when Run was tapped, so another account on the same phone never sees it and a plain sign-out keeps it for the same
/// account. The bounds are those of the statement text store's history (`IStatementTextStore.appendHistory`): 500
/// entries, 1,000,000 characters of text in all and 100,000 for one entry, the oldest dropped first and a longer entry
/// kept without its text. A history the store cannot read answers `editor.saved_text_unreadable` until [clear] removes
/// it. 'Remove my data' removes it through the store's `clearSubject` and `clearAll`.
abstract interface class IStatementHistoryRepository {
  /// The history of [subjectHash], newest first.
  Future<Result<List<StatementHistoryEntry>>> read(String subjectHash);

  /// Adds [run] as the newest entry of [subjectHash], with a fresh id and the time now, and answers it as stored.
  Future<Result<StatementHistoryEntry>> record(String subjectHash, FinishedRun run);

  /// Removes the entry [entryId].
  Future<Result<void>> delete(String subjectHash, String entryId);

  /// Removes the whole history of [subjectHash], readable or not.
  Future<Result<void>> clear(String subjectHash);
}
