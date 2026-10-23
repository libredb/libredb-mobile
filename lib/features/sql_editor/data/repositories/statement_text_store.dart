import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/core/logging/app_logger.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/sql_editor/data/models/statement_text_json.dart';
import 'package:libredb_mobile/features/sql_editor/domain/entities/statement_draft.dart';
import 'package:libredb_mobile/features/sql_editor/domain/entities/statement_history_entry.dart';
import 'package:libredb_mobile/features/sql_editor/domain/repositories/statement_text_store.dart';
import 'package:libredb_mobile/infrastructure/storage/encrypted_text_file_store.dart';
import 'package:libredb_mobile/shared/utils/subject_hash.dart';

/// Keeps the drafts and the history in [EncryptedTextFileStore]: one file per connection's draft, named by the
/// SHA-256 hex of the connection id, and one `history` file.
class StatementTextStore implements IStatementTextStore {
  StatementTextStore(this._files);

  static final _log = AppLogger.getLogger('StatementTextStore');

  static const _history = 'history';

  final EncryptedTextFileStore _files;

  @override
  Future<Result<StatementDraft?>> readDraft(String subjectHash, String connectionId) =>
      _run('read a draft', write: false, () async {
        final json = await _files.read(subjectHash, _draftName(connectionId));
        return json == null ? null : StatementTextJson.draft(json);
      });

  @override
  Future<Result<DraftSaveOutcome>> saveDraft(String subjectHash, String connectionId, StatementDraft draft) => _run(
    'save a draft',
    write: true,
    () => _files.update(subjectHash, _draftName(connectionId), (_) {
      if (draft.text.length > IStatementTextStore.maxTextLength) return const DeleteFile(DraftSaveOutcome.notKept);
      return WriteFile(StatementTextJson.draftToJson(draft), DraftSaveOutcome.kept);
    }),
  );

  @override
  Future<Result<void>> discardDraft(String subjectHash, String connectionId) =>
      _run('discard a draft', write: true, () => _files.delete(subjectHash, _draftName(connectionId)));

  @override
  Future<Result<List<StatementHistoryEntry>>> readHistory(String subjectHash) =>
      _run('read the history', write: false, () async {
        final json = await _files.read(subjectHash, _history);
        return json == null ? const <StatementHistoryEntry>[] : StatementTextJson.history(json);
      });

  @override
  Future<Result<StatementHistoryEntry>> appendHistory(String subjectHash, StatementHistoryEntry entry) => _run(
    'add to the history',
    write: true,
    () => _files.update(subjectHash, _history, (current) {
      final stored = (entry.text?.length ?? 0) > IStatementTextStore.maxTextLength ? entry.withoutText() : entry;
      final entries = [
        stored,
        ...current == null ? const <StatementHistoryEntry>[] : StatementTextJson.history(current),
      ];
      var total = entries.fold(0, (sum, kept) => sum + (kept.text?.length ?? 0));
      while (entries.length > IStatementTextStore.maxHistoryEntries ||
          total > IStatementTextStore.maxHistoryTextLength) {
        total -= entries.removeLast().text?.length ?? 0;
      }
      return WriteFile(StatementTextJson.historyToJson(entries), stored);
    }),
  );

  @override
  Future<Result<void>> deleteHistoryEntry(String subjectHash, String entryId) => _run(
    'delete a history entry',
    write: true,
    () => _files.update<void>(subjectHash, _history, (current) {
      if (current == null) return const KeepFile(null);
      final entries = StatementTextJson.history(current)..removeWhere((kept) => kept.id == entryId);
      return entries.isEmpty ? const DeleteFile(null) : WriteFile(StatementTextJson.historyToJson(entries), null);
    }),
  );

  @override
  Future<Result<void>> discardHistory(String subjectHash) =>
      _run('discard the history', write: true, () => _files.delete(subjectHash, _history));

  @override
  Future<Result<void>> clearSubject(String subjectHash) =>
      _run('clear an account', write: true, () => _files.clearSubject(subjectHash));

  @override
  Future<Result<void>> clearAll() => _run('clear every account', write: true, _files.clearAll);

  static String _draftName(String connectionId) => subjectHash(connectionId);

  /// Runs [operation] and answers its value, or a [Failure] whose message names only [action] and the kind of failure:
  /// never the text, the subject hash or a path.
  static Future<Result<T>> _run<T>(String action, Future<T> Function() operation, {required bool write}) async {
    try {
      return Success(await operation());
    } on StoredTextUnreadableException catch (e, stack) {
      _log.warn('Could not {}: the saved text cannot be read ({})', [action, e.reason.name]);
      return Failure(
        UnknownError('Could not $action: ${e.reason.name}', code: AppErrorCode.editorSavedTextUnreadable.key),
        stackTrace: stack,
      );
    } on FormatException catch (_, stack) {
      // The saved content decrypted, but not into this shape; the exception is not printed, as a value could be in it.
      _log.warn('Could not {}: the saved text is not of the stored shape', [action]);
      return Failure(
        UnknownError('Could not $action: format', code: AppErrorCode.editorSavedTextUnreadable.key),
        stackTrace: stack,
      );
    } on StoredTextStorageException catch (e, stack) {
      _log.warn('Could not {}: {}', [action, e.cause]);
      final code = write ? AppErrorCode.editorSavedTextNotStored : AppErrorCode.generic;
      return Failure(UnknownError('Could not $action: ${e.cause}', code: code.key), stackTrace: stack);
    } catch (e, stack) {
      _log.error('Could not {}: {}', [action, e.runtimeType]);
      return Failure(
        UnknownError('Could not $action: ${e.runtimeType}', code: AppErrorCode.generic.key),
        stackTrace: stack,
      );
    }
  }
}
