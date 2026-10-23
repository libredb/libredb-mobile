import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/shared/models/query_page.dart';
import 'package:libredb_mobile/shared/models/query_result.dart';

/// Runs one statement on a managed connection, named by its id (`seed:<id>`), for every feature that shows a result:
/// the object browser's previews, counts and key reads, and the SQL editor.
///
/// Each call spends a slot of the user's Studio request budget, and none is ever retried on its own: a statement may
/// have changed data. The statement text and the database's error text are never logged.
abstract class IStatementRepository {
  /// Runs [sql]. [queryId], from `newQueryId()`, lets the run be cancelled; [page] is the rows of a SELECT to fetch;
  /// [params] are positional bind values (strings, numbers, booleans or null); [catalog] is the database to run in on
  /// a server-level connection; [database] is the numbered database a key was walked in, which Studio takes only for
  /// a key read on an engine that scans keys (Redis). A negative [database], which Studio refuses with a 400, throws an
  /// [ArgumentError] before anything is sent.
  Future<Result<QueryResult>> run(
    String connectionId,
    String sql, {
    String? queryId,
    QueryPage page = QueryPage.first,
    List<Object?>? params,
    String? catalog,
    int? database,
  });
}
