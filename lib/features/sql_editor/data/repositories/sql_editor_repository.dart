import 'package:libredb_mobile/core/logging/app_logger.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/sql_editor/data/models/sql_editor_json.dart';
import 'package:libredb_mobile/shared/models/query_page.dart';
import 'package:libredb_mobile/shared/models/query_result.dart';
import 'package:libredb_mobile/features/sql_editor/domain/entities/script_result.dart';
import 'package:libredb_mobile/features/sql_editor/domain/entities/transaction_state.dart';
import 'package:libredb_mobile/features/sql_editor/domain/repositories/sql_editor_repository.dart';
import 'package:libredb_mobile/infrastructure/http/api_client.dart';
import 'package:libredb_mobile/infrastructure/studio/studio_errors.dart';
import 'package:libredb_mobile/infrastructure/studio/studio_timeouts.dart';
import 'package:libredb_mobile/shared/models/statement_repository.dart';

/// Studio's statement routes, all `POST` with the connection named in the body. The paths are relative to
/// `PROD_API_URL`, which ends in Studio's `/api`. The statement text is never logged, and no request is sent twice.
///
/// `/db/transaction` waits the connection's query timeout plus a margin ([ConnectionQueryTimeouts]). `/db/multi-query`
/// waits without a limit: Studio gives each statement of a script its own query timeout, so any limit the phone set
/// could cancel a script Studio may still finish; Cancel and leaving the app end one the user gives up on. `cancel`
/// runs no statement and keeps the client's default.
///
/// [run] goes through the shared [IStatementRepository], so the app sends `/db/query` from one place.
class SqlEditorRepository implements ISqlEditorRepository {
  SqlEditorRepository(this._apiClient, this._statements, this._queryTimeouts);

  final ApiClient _apiClient;
  final IStatementRepository _statements;
  final ConnectionQueryTimeouts _queryTimeouts;

  /// Dio 5 reads a zero receive timeout as none; null would keep the client's 30 seconds.
  static const _noReceiveTimeout = Duration.zero;

  static final _log = AppLogger.getLogger('SqlEditorRepository');

  @override
  Future<Result<QueryResult>> run(
    String connectionId,
    String sql, {
    String? queryId,
    QueryPage page = QueryPage.first,
    List<Object?>? params,
    String? catalog,
  }) => _statements.run(connectionId, sql, queryId: queryId, page: page, params: params, catalog: catalog);

  @override
  Future<Result<ScriptResult>> runScript(
    String connectionId,
    String sql, {
    String? queryId,
    String? catalog,
    QueryPage? page,
  }) => _post(
    'runScript',
    '/db/multi-query',
    {'connectionId': connectionId, 'sql': sql, 'options': ?page?.toJson(), 'queryId': ?queryId, 'catalog': ?catalog},
    SqlEditorJson.scriptResult,
    receiveTimeout: _noReceiveTimeout,
  );

  @override
  Future<Result<bool>> cancel(String connectionId, String queryId) => _post(
    'cancel',
    '/db/cancel',
    {'connectionId': connectionId, 'queryId': queryId},
    SqlEditorJson.cancelled,
    receiveTimeout: null,
  );

  @override
  Future<Result<bool?>> beginTransaction(String connectionId, {String? catalog}) => _post(
    'beginTransaction',
    '/db/transaction',
    {'connectionId': connectionId, 'action': 'begin', 'catalog': ?catalog},
    SqlEditorJson.transactionBegun,
    receiveTimeout: _queryTimeouts.statementReceiveTimeout(connectionId),
  );

  @override
  Future<Result<TransactionRun>> runInTransaction(
    String connectionId,
    String sql, {
    List<Object?>? params,
    QueryPage page = QueryPage.first,
    String? catalog,
  }) => _post(
    'runInTransaction',
    '/db/transaction',
    {
      'connectionId': connectionId,
      'action': 'query',
      'sql': sql,
      'options': page.toJson(),
      'params': ?params,
      'catalog': ?catalog,
    },
    SqlEditorJson.transactionRun,
    receiveTimeout: _queryTimeouts.statementReceiveTimeout(connectionId),
  );

  @override
  Future<Result<TransactionEnd>> commit(String connectionId, {String? catalog}) =>
      _end('commit', connectionId, catalog, SqlEditorJson.transactionCommitted);

  @override
  Future<Result<TransactionEnd>> rollback(String connectionId, {String? catalog}) =>
      _end('rollback', connectionId, catalog, SqlEditorJson.transactionRolledBack);

  @override
  Future<Result<TransactionStatus>> transactionStatus(String connectionId, {String? catalog}) => _post(
    'transactionStatus',
    '/db/transaction',
    {'connectionId': connectionId, 'action': 'status', 'catalog': ?catalog},
    SqlEditorJson.transactionStatus,
    receiveTimeout: _queryTimeouts.statementReceiveTimeout(connectionId),
  );

  /// Commit or rollback: Studio answers 2xx only once the engine ended the transaction, so a 2xx whose body [read]
  /// refuses still ended it and is [TransactionEnd.unreadableAnswer], never a `Failure` the UI would offer again.
  Future<Result<TransactionEnd>> _end(
    String action,
    String connectionId,
    String? catalog,
    void Function(String body) read,
  ) async {
    final String? answer;
    try {
      answer = (await _apiClient.post('/db/transaction', {
        'connectionId': connectionId,
        'action': action,
        'catalog': ?catalog,
      }, receiveTimeout: _queryTimeouts.statementReceiveTimeout(connectionId))).data;
    } catch (e) {
      return _failure(action, e);
    }
    try {
      read(ApiClient.decodeUTF8(answer!));
      return const Success(TransactionEnd.confirmed);
    } catch (e) {
      _log.warn('{} ended the transaction with an unreadable answer: {}', [action, e.runtimeType]);
      return const Success(TransactionEnd.unreadableAnswer);
    }
  }

  Future<Result<T>> _post<T>(
    String operation,
    String path,
    Map<String, Object?> body,
    T Function(String body) read, {
    required Duration? receiveTimeout,
  }) async {
    try {
      final response = await _apiClient.post(path, body, receiveTimeout: receiveTimeout);
      return Success(read(ApiClient.decodeUTF8(response.data!)));
    } catch (e) {
      return _failure(operation, e);
    }
  }

  static Failure<T> _failure<T>(String operation, Object e) {
    final error = studioError(e);
    _log.warn('{} failed: {}', [operation, error.code ?? error.runtimeType]);
    return Failure(error);
  }
}
