import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/sql_editor/domain/entities/statement_history_entry.dart';
import 'package:libredb_mobile/features/sql_editor/domain/repositories/statement_history_repository.dart';
import 'package:libredb_mobile/features/sql_editor/domain/repositories/statement_text_store.dart';
import 'package:libredb_mobile/shared/models/query_id.dart';

/// The history in the history namespace of [IStatementTextStore], which applies its bounds on every append.
class StatementHistoryRepository implements IStatementHistoryRepository {
  StatementHistoryRepository(this._store, {this._newId = newQueryId, DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final IStatementTextStore _store;
  final String Function() _newId;
  final DateTime Function() _now;

  @override
  Future<Result<List<StatementHistoryEntry>>> read(String subjectHash) => _store.readHistory(subjectHash);

  @override
  Future<Result<StatementHistoryEntry>> record(String subjectHash, FinishedRun run) => _store.appendHistory(
    subjectHash,
    StatementHistoryEntry(
      id: _newId(),
      connectionId: run.connectionId,
      connectionName: run.connectionName,
      text: run.text,
      status: run.status,
      duration: run.duration,
      rowCount: run.rowCount,
      executedAt: _now(),
    ),
  );

  @override
  Future<Result<void>> delete(String subjectHash, String entryId) => _store.deleteHistoryEntry(subjectHash, entryId);

  @override
  Future<Result<void>> clear(String subjectHash) => _store.discardHistory(subjectHash);
}
