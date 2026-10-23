import 'package:equatable/equatable.dart';
import 'package:libredb_mobile/shared/models/query_page.dart';
import 'package:libredb_mobile/shared/models/vector_column.dart';

/// The answer to one statement.
class QueryResult extends Equatable {
  const QueryResult({
    required this.fields,
    required this.rows,
    required this.rowCount,
    required this.executionTime,
    this.columnTypes = const {},
    this.warnings = const [],
    this.pagination,
    this.openTransactionRolledBack = false,
    this.vectorColumns = const {},
  });

  /// The column names, unique and in order.
  final List<String> fields;

  /// The rows, keyed by column name, with the values as JSON gave them.
  final List<Map<String, Object?>> rows;

  /// The rows on this page, or the rows a data change affected.
  final int rowCount;
  final Duration executionTime;

  /// The engine's type of each column, when it reported them.
  final Map<String, String> columnTypes;

  /// The engine's notices and warnings.
  final List<QueryWarning> warnings;

  /// Absent inside a multi-statement script.
  final QueryPagination? pagination;

  /// The statement left a transaction open, and Studio rolled it back.
  final bool openTransactionRolledBack;

  /// The columns that hold vectors, keyed by their names in [fields]; empty when there is none.
  final Map<String, VectorColumn> vectorColumns;

  @override
  List<Object?> get props => [
    fields,
    rows,
    rowCount,
    executionTime,
    columnTypes,
    warnings,
    pagination,
    openTransactionRolledBack,
    vectorColumns,
  ];
}

class QueryWarning extends Equatable {
  const QueryWarning({required this.message, this.code, this.severity});

  final String message;
  final String? code;
  final String? severity;

  @override
  List<Object?> get props => [message, code, severity];
}

/// The result that Load more leaves once [page] is appended to the rows [shown] on screen, by Studio's rule
/// (`appendResultPage` in `src/lib/results/append-page.ts`): the rows concatenated, the fields kept from [shown] when
/// the page names none (SQLite answers `fields: []` on a page past the last row of a table whose size is an exact
/// multiple of the page), the vector columns from the page or else from [shown], the row count the merged count, and
/// everything else, the warnings, the column types and the paging included, from the page. Neither input is changed.
QueryResult appendResultPage(QueryResult shown, QueryResult page) {
  final rows = [...shown.rows, ...page.rows];
  return QueryResult(
    fields: page.fields.isNotEmpty ? page.fields : shown.fields,
    rows: rows,
    rowCount: rows.length,
    executionTime: page.executionTime,
    columnTypes: page.columnTypes,
    warnings: page.warnings,
    pagination: page.pagination,
    openTransactionRolledBack: page.openTransactionRolledBack,
    vectorColumns: page.vectorColumns.isNotEmpty ? page.vectorColumns : shown.vectorColumns,
  );
}
