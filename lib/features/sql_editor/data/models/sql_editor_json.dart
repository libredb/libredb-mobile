import 'dart:convert';

import 'package:flutter_bloc_advance/features/sql_editor/domain/entities/query_page.dart';
import 'package:flutter_bloc_advance/features/sql_editor/domain/entities/query_result.dart';
import 'package:flutter_bloc_advance/features/sql_editor/domain/entities/script_result.dart';
import 'package:flutter_bloc_advance/features/sql_editor/domain/entities/transaction_state.dart';

/// Reads the answers of Studio's statement routes (`src/lib/types.ts` and `src/app/api/db/*` in Studio).
///
/// Every reader throws a [FormatException] when a required field is missing or has the wrong type; optional fields
/// of an unexpected type are left out.
final class SqlEditorJson {
  const SqlEditorJson._();

  /// `POST /api/db/query`, and a single statement of `POST /api/db/transaction`.
  static QueryResult queryResult(String body) => _queryResult(_object(body));

  /// `POST /api/db/multi-query`, which answers 200 even when a statement failed.
  static ScriptResult scriptResult(String body) => _scriptResult(_object(body));

  /// `POST /api/db/cancel`: `{cancelled}`.
  static bool cancelled(String body) {
    final cancelled = _object(body)['cancelled'];
    return cancelled is bool ? cancelled : throw const FormatException('The cancel answer has no cancelled flag');
  }

  /// `begin` of `POST /api/db/transaction`: `{status, message, stateReported: bool | null}`.
  static bool? transactionBegun(String body) {
    final stateReported = _object(body)['stateReported'];
    return stateReported is bool ? stateReported : null;
  }

  /// `query` of `POST /api/db/transaction`: a query or script answer plus `inTransaction`.
  static TransactionRun transactionRun(String body) {
    final json = _object(body);
    final inTransaction = json['inTransaction'];
    if (inTransaction is! bool) throw const FormatException('The transaction answer has no inTransaction flag');
    return json['multiStatement'] == true
        ? TransactionRun(inTransaction: inTransaction, script: _scriptResult(json))
        : TransactionRun(inTransaction: inTransaction, result: _queryResult(json));
  }

  /// `status` of `POST /api/db/transaction`.
  static TransactionStatus transactionStatus(String body) {
    final json = _object(body);
    final startedAt = json['startedAt'];
    return TransactionStatus(
      inTransaction: _bool(json['inTransaction'], 'inTransaction'),
      ownedByYou: _bool(json['ownedByYou'], 'ownedByYou'),
      heldByAnotherSession: _bool(json['heldByAnotherSession'], 'heldByAnotherSession'),
      startedAt: startedAt is String ? DateTime.tryParse(startedAt) : null,
    );
  }

  static QueryResult _queryResult(Map<String, dynamic> json) {
    final pagination = json['pagination'];
    return QueryResult(
      fields: _strings(json['fields'], 'fields'),
      rows: _rows(json['rows']),
      rowCount: _int(json['rowCount'], 'rowCount'),
      executionTime: _duration(json['executionTime'], 'executionTime'),
      columnTypes: _columnTypes(json['columnTypes']),
      warnings: _warnings(json['warnings']),
      pagination: pagination is Map<String, dynamic>
          ? QueryPagination(
              limit: _int(pagination['limit'], 'limit'),
              offset: _int(pagination['offset'], 'offset'),
              hasMore: _bool(pagination['hasMore'], 'hasMore'),
              totalReturned: _int(pagination['totalReturned'], 'totalReturned'),
              wasLimited: pagination['wasLimited'] == true,
            )
          : null,
      openTransactionRolledBack: json['openTransaction'] == 'rolled-back',
    );
  }

  static ScriptResult _scriptResult(Map<String, dynamic> json) {
    return ScriptResult(
      statements: [for (final item in _list(json['statements'], 'statements')) _statement(_map(item, 'statement'))],
      statementCount: _int(json['statementCount'], 'statementCount'),
      executedCount: _int(json['executedCount'], 'executedCount'),
      executionTime: _duration(json['executionTime'], 'executionTime'),
      openTransactionRolledBack: json['openTransaction'] == 'rolled-back',
    );
  }

  static StatementResult _statement(Map<String, dynamic> json) {
    final failed = json['status'] == 'error';
    final error = json['error'];
    return StatementResult(
      index: _int(json['index'], 'index'),
      sql: _string(json['sql'], 'sql'),
      startLine: _int(json['startLine'], 'startLine'),
      executionTime: _duration(json['executionTime'], 'executionTime'),
      error: failed ? (error is String ? error : 'The statement failed') : null,
      result: !failed && json['fields'] is List
          ? QueryResult(
              fields: _strings(json['fields'], 'fields'),
              rows: _rows(json['rows'] ?? const []),
              rowCount: json['rowCount'] is int ? json['rowCount'] as int : 0,
              executionTime: _duration(json['executionTime'], 'executionTime'),
              columnTypes: _columnTypes(json['columnTypes']),
              warnings: _warnings(json['warnings']),
            )
          : null,
    );
  }

  static List<Map<String, Object?>> _rows(Object? value) => [
    for (final row in _list(value, 'rows')) Map<String, Object?>.from(_map(row, 'row')),
  ];

  static Map<String, String> _columnTypes(Object? value) => {
    if (value is Map)
      for (final MapEntry(:key, :value) in value.entries)
        if (key is String && value is String) key: value,
  };

  static List<QueryWarning> _warnings(Object? value) => [
    if (value is List)
      for (final item in value)
        if (item is Map && item['message'] is String)
          QueryWarning(
            message: item['message'] as String,
            code: item['code'] == null ? null : '${item['code']}',
            severity: item['severity'] is String ? item['severity'] as String : null,
          ),
  ];

  static Map<String, dynamic> _object(String body) => _map(jsonDecode(body), 'answer');

  static Map<String, dynamic> _map(Object? value, String what) =>
      value is Map<String, dynamic> ? value : throw FormatException('The $what is not an object');

  static List<dynamic> _list(Object? value, String what) =>
      value is List ? value : throw FormatException('The $what is not a list');

  static String _string(Object? value, String what) =>
      value is String ? value : throw FormatException('The $what is not a string');

  static int _int(Object? value, String what) =>
      value is int ? value : throw FormatException('The $what is not a whole number');

  static bool _bool(Object? value, String what) =>
      value is bool ? value : throw FormatException('The $what is not a boolean');

  static Duration _duration(Object? value, String what) => value is num
      ? Duration(microseconds: (value * 1000).round())
      : throw FormatException('The $what is not a number');

  static List<String> _strings(Object? value, String what) => [
    for (final item in _list(value, what)) _string(item, what),
  ];
}
