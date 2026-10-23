import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/shared/models/cancel_signal.dart';
import 'package:libredb_mobile/shared/models/query_page.dart';
import 'package:libredb_mobile/shared/models/query_result.dart';
import 'package:libredb_mobile/features/sql_editor/domain/entities/script_result.dart';
import 'package:libredb_mobile/features/sql_editor/domain/entities/transaction_state.dart';

/// Runs statements on a managed connection, named by its id (`seed:<id>`). Each call spends a slot of the user's
/// Studio request budget, and none is ever retried on its own: a statement may have changed data.
abstract class ISqlEditorRepository {
  /// Runs one statement through the shared `IStatementRepository`. [queryId], from `newQueryId()`, lets [cancel] stop
  /// it; [params] are positional bind values (strings, numbers, booleans or null); [catalog] is the database to run in
  /// on a server-level connection; [cancelSignal] drops the request, which then answers `RequestCancelledError`.
  Future<Result<QueryResult>> run(
    String connectionId,
    String sql, {
    String? queryId,
    QueryPage page = QueryPage.first,
    List<Object?>? params,
    String? catalog,
    CancelSignal? cancelSignal,
  });

  /// Runs a text of several statements in order. It takes no bind values. [page] bounds the last statement when it is
  /// a SELECT; Studio answers no paging for a script, so there is no next page to ask for.
  Future<Result<ScriptResult>> runScript(
    String connectionId,
    String sql, {
    String? queryId,
    String? catalog,
    QueryPage? page,
  });

  /// Asks Studio to stop the run [queryId], through the shared `IStatementRepository.cancel`. True when the engine stopped it; false when it had already finished or the
  /// engine did not stop it. The stopped run itself fails with `studio.query_cancelled`.
  Future<Result<bool>> cancel(String connectionId, String queryId);

  /// Opens a transaction. The answer says whether the engine reports its transaction state, or null when unknown.
  Future<Result<bool?>> beginTransaction(String connectionId, {String? catalog});

  /// Runs statements inside the open transaction. They cannot be cancelled.
  Future<Result<TransactionRun>> runInTransaction(
    String connectionId,
    String sql, {
    List<Object?>? params,
    QueryPage page = QueryPage.first,
    String? catalog,
  });

  /// Commits the open transaction. On a server-level connection Studio keeps one transaction per database, so
  /// [catalog] must name the database the transaction was begun in, or Studio finds none open.
  ///
  /// A success ended the transaction, even as [TransactionEnd.unreadableAnswer]; only a `Failure` leaves it open.
  Future<Result<TransactionEnd>> commit(String connectionId, {String? catalog});

  /// Rolls the open transaction back; [catalog] and the answer as for [commit].
  Future<Result<TransactionEnd>> rollback(String connectionId, {String? catalog});

  /// Whether a transaction is open, and whose it is; [catalog] as for [commit].
  Future<Result<TransactionStatus>> transactionStatus(String connectionId, {String? catalog});
}
