import 'package:equatable/equatable.dart';
import 'package:flutter_bloc_advance/features/sql_editor/domain/entities/query_result.dart';

/// The answer to a text of several statements, which Studio splits and runs in order, stopping at the first that
/// fails. A failed statement is part of the result, not an error.
class ScriptResult extends Equatable {
  const ScriptResult({
    required this.statements,
    required this.statementCount,
    required this.executedCount,
    required this.executionTime,
    this.openTransactionRolledBack = false,
  });

  final List<StatementResult> statements;
  final int statementCount;
  final int executedCount;
  final Duration executionTime;

  /// The script left a transaction open, and Studio rolled it back.
  final bool openTransactionRolledBack;

  bool get hasError => statements.any((statement) => statement.error != null);

  @override
  List<Object?> get props => [statements, statementCount, executedCount, executionTime, openTransactionRolledBack];
}

/// One statement of a script: its [result], or the database's [error] text.
class StatementResult extends Equatable {
  const StatementResult({
    required this.index,
    required this.sql,
    required this.startLine,
    required this.executionTime,
    this.result,
    this.error,
  });

  final int index;
  final String sql;

  /// The line of the script the statement starts on, as Studio reports it.
  final int startLine;
  final Duration executionTime;
  final QueryResult? result;
  final String? error;

  @override
  List<Object?> get props => [index, sql, startLine, executionTime, result, error];
}
