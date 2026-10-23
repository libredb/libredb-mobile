import 'package:libredb_mobile/core/logging/app_logger.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/infrastructure/http/api_client.dart';
import 'package:libredb_mobile/infrastructure/studio/cancel_answer_json.dart';
import 'package:libredb_mobile/infrastructure/studio/query_result_json.dart';
import 'package:libredb_mobile/infrastructure/studio/studio_errors.dart';
import 'package:libredb_mobile/infrastructure/studio/studio_timeouts.dart';
import 'package:libredb_mobile/shared/models/cancel_signal.dart';
import 'package:libredb_mobile/shared/models/query_page.dart';
import 'package:libredb_mobile/shared/models/query_result.dart';
import 'package:libredb_mobile/shared/models/statement_repository.dart';

/// `POST /db/query` and `POST /db/cancel` with the connection named in the body, relative to `PROD_API_URL`, which
/// ends in Studio's `/api`. A run waits the connection's query timeout plus a margin for the answer
/// ([ConnectionQueryTimeouts]). Only the error code is logged, never the statement or the database's words, and
/// `ApiClient` never sends a POST twice.
///
/// It tells no `SchemaChangeNotifier`: a preview, a count and a key read change no schema, and the SQL editor's run,
/// which runs what the user typed, does that itself.
class StatementRepository implements IStatementRepository {
  StatementRepository(this._apiClient, this._queryTimeouts);

  final ApiClient _apiClient;
  final ConnectionQueryTimeouts _queryTimeouts;

  static final _log = AppLogger.getLogger('StatementRepository');

  @override
  Future<Result<QueryResult>> run(
    String connectionId,
    String sql, {
    String? queryId,
    QueryPage page = QueryPage.first,
    List<Object?>? params,
    String? catalog,
    int? database,
    CancelSignal? cancelSignal,
  }) async {
    if (database != null && database < 0) {
      throw ArgumentError.value(database, 'database', 'must not be negative');
    }
    try {
      final response = await _apiClient.post(
        '/db/query',
        {
          'connectionId': connectionId,
          'sql': sql,
          'options': page.toJson(),
          'queryId': ?queryId,
          'params': ?params,
          'catalog': ?catalog,
          'database': ?database,
        },
        receiveTimeout: _queryTimeouts.statementReceiveTimeout(connectionId),
        cancelSignal: cancelSignal,
      );
      return Success(QueryResultJson.read(ApiClient.decodeUTF8(response.data!)));
    } catch (e) {
      final error = studioError(e);
      _log.warn('run failed: {}', [error.code ?? error.runtimeType]);
      return Failure(error);
    }
  }

  @override
  Future<Result<bool>> cancel(String connectionId, String queryId) async {
    try {
      // Runs no statement, so it keeps the client's default timeout.
      final response = await _apiClient.post('/db/cancel', {'connectionId': connectionId, 'queryId': queryId});
      return Success(CancelAnswerJson.cancelled(ApiClient.decodeUTF8(response.data!)));
    } catch (e) {
      final error = studioError(e);
      _log.warn('cancel failed: {}', [error.code ?? error.runtimeType]);
      return Failure(error);
    }
  }
}
