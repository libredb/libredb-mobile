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
/// `PROD_API_URL`, which ends in Studio's `/api`. The statement text is never logged. A request that runs a statement
/// waits [studioStatementReceiveTimeout] for its answer; `cancel` runs none and keeps the client's default.
///
/// [run] goes through the shared [IStatementRepository], so the app sends `/db/query` from one place.
class SqlEditorRepository implements ISqlEditorRepository {
  SqlEditorRepository(this._apiClient, this._statements);

  final ApiClient _apiClient;
  final IStatementRepository _statements;

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
  }) => _post('runScript', '/db/multi-query', {
    'connectionId': connectionId,
    'sql': sql,
    'options': ?page?.toJson(),
    'queryId': ?queryId,
    'catalog': ?catalog,
  }, SqlEditorJson.scriptResult);

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
  );

  @override
  Future<Result<TransactionRun>> runInTransaction(
    String connectionId,
    String sql, {
    List<Object?>? params,
    QueryPage page = QueryPage.first,
    String? catalog,
  }) => _post('runInTransaction', '/db/transaction', {
    'connectionId': connectionId,
    'action': 'query',
    'sql': sql,
    'options': page.toJson(),
    'params': ?params,
    'catalog': ?catalog,
  }, SqlEditorJson.transactionRun);

  @override
  Future<Result<void>> commit(String connectionId, {String? catalog}) => _post('commit', '/db/transaction', {
    'connectionId': connectionId,
    'action': 'commit',
    'catalog': ?catalog,
  }, SqlEditorJson.transactionEnded);

  @override
  Future<Result<void>> rollback(String connectionId, {String? catalog}) => _post('rollback', '/db/transaction', {
    'connectionId': connectionId,
    'action': 'rollback',
    'catalog': ?catalog,
  }, SqlEditorJson.transactionEnded);

  @override
  Future<Result<TransactionStatus>> transactionStatus(String connectionId, {String? catalog}) => _post(
    'transactionStatus',
    '/db/transaction',
    {'connectionId': connectionId, 'action': 'status', 'catalog': ?catalog},
    SqlEditorJson.transactionStatus,
  );

  Future<Result<T>> _post<T>(
    String operation,
    String path,
    Map<String, Object?> body,
    T Function(String body) read, {
    Duration? receiveTimeout = studioStatementReceiveTimeout,
  }) async {
    try {
      final response = await _apiClient.post(path, body, receiveTimeout: receiveTimeout);
      return Success(read(ApiClient.decodeUTF8(response.data!)));
    } catch (e) {
      final error = studioError(e);
      _log.warn('{} failed: {}', [operation, error.code ?? error.runtimeType]);
      return Failure(error);
    }
  }
}
