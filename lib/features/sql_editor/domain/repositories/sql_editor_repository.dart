import 'package:flutter_bloc_advance/core/result/result.dart';
import 'package:flutter_bloc_advance/features/sql_editor/domain/entities/query_page.dart';
import 'package:flutter_bloc_advance/features/sql_editor/domain/entities/query_result.dart';
import 'package:flutter_bloc_advance/features/sql_editor/domain/entities/script_result.dart';
import 'package:flutter_bloc_advance/features/sql_editor/domain/entities/transaction_state.dart';

/// Runs statements on a managed connection, named by its id (`seed:<id>`). Each call spends a slot of the user's
/// Studio request budget, and none is ever retried on its own: a statement may have changed data.
abstract class ISqlEditorRepository {
  /// Runs one statement. [queryId], from `newQueryId()`, lets [cancel] stop it; [params] are positional bind values
  /// (strings, numbers, booleans or null); [catalog] is the database to run in on a server-level connection.
  Future<Result<QueryResult>> run(
    String connectionId,
    String sql, {
    String? queryId,
    QueryPage page = QueryPage.first,
    List<Object?>? params,
    String? catalog,
  });

  /// Runs a text of several statements in order. It takes no bind values and has no paging.
  Future<Result<ScriptResult>> runScript(String connectionId, String sql, {String? queryId, String? catalog});

  /// Asks Studio to stop the run [queryId]. True when the engine stopped it; false when it had already finished or the
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

  Future<Result<void>> commit(String connectionId);

  Future<Result<void>> rollback(String connectionId);

  Future<Result<TransactionStatus>> transactionStatus(String connectionId);
}
