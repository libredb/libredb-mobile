import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/sql_editor/domain/entities/statement_draft.dart';
import 'package:libredb_mobile/features/sql_editor/domain/entities/statement_history_entry.dart';

/// The statement text the device keeps for each signed-in account: one draft per connection and the history of runs,
/// encrypted at rest.
///
/// Every call names the account by `subjectHash(StudioIdentity.subject)` (`lib/shared/utils/subject_hash.dart`),
/// captured when the text was typed, so a save that lands after a sign-out goes to the account that typed it. Call
/// nothing while Studio has named no subject. A plain sign-out keeps the text for the same account's next sign-in;
/// another account never reads it.
///
/// A saved text the store cannot read answers a `Failure` with `editor.saved_text_unreadable`; it is never read as
/// empty, and no save replaces it until [discardDraft] or [discardHistory] removes it, which the screen offers behind
/// a confirmation. A write the device refuses answers `editor.saved_text_not_stored`.
abstract interface class IStatementTextStore {
  /// The most characters a draft or one history entry keeps, counted as `String.length`.
  static const maxTextLength = 100000;

  /// The most entries the history keeps, Studio's `MAX_HISTORY_ITEMS`.
  static const maxHistoryEntries = 500;

  /// The most characters of statement text the whole history keeps.
  static const maxHistoryTextLength = 1000000;

  /// The saved draft of [connectionId], or null when there is none.
  Future<Result<StatementDraft?>> readDraft(String subjectHash, String connectionId);

  /// Saves [draft] for [connectionId]. A text longer than [maxTextLength] is not saved: the connection's saved draft is
  /// removed and the answer is [DraftSaveOutcome.notKept].
  Future<Result<DraftSaveOutcome>> saveDraft(String subjectHash, String connectionId, StatementDraft draft);

  /// Removes the saved draft of [connectionId], readable or not.
  Future<Result<void>> discardDraft(String subjectHash, String connectionId);

  /// The history, newest first.
  Future<Result<List<StatementHistoryEntry>>> readHistory(String subjectHash);

  /// Adds [entry] as the newest, and answers it as stored. An entry whose text is longer than [maxTextLength] is kept
  /// without its text and marked; then the oldest entries are dropped until at most [maxHistoryEntries] are left and
  /// their texts hold at most [maxHistoryTextLength] characters.
  Future<Result<StatementHistoryEntry>> appendHistory(String subjectHash, StatementHistoryEntry entry);

  /// Removes the entry [entryId] from the history.
  Future<Result<void>> deleteHistoryEntry(String subjectHash, String entryId);

  /// Removes the whole history, readable or not.
  Future<Result<void>> discardHistory(String subjectHash);

  /// Removes everything kept for [subjectHash], its key first and its files after it, for 'Remove my data'.
  Future<Result<void>> clearSubject(String subjectHash);

  /// [clearSubject] for every account on the device.
  Future<Result<void>> clearAll();
}
