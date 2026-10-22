import 'package:equatable/equatable.dart';
import 'package:flutter_bloc_advance/features/sql_editor/domain/entities/query_page.dart';

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
