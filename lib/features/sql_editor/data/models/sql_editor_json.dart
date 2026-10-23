import 'dart:convert';

import 'package:libredb_mobile/infrastructure/studio/query_result_json.dart';
import 'package:libredb_mobile/features/sql_editor/domain/entities/script_result.dart';
import 'package:libredb_mobile/features/sql_editor/domain/entities/transaction_state.dart';

/// Reads the answers of Studio's statement routes (`src/lib/types.ts` and `src/app/api/db/*` in Studio).
///
/// Every reader throws a [FormatException] when a required field is missing or has the wrong type; optional fields
/// of an unexpected type are left out. Each result of a statement is read by [QueryResultJson], which reads the loss
/// notices strictly, and so is the script's `openTransaction`. `POST /api/db/query` itself is read by the shared
/// statement repository.
final class SqlEditorJson {
  const SqlEditorJson._();

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

  /// `commit` of `POST /api/db/transaction`: `{status: "committed", message}`; any other status is refused.
  static void transactionCommitted(String body) => _transactionEnded(body, 'committed');

  /// `rollback` of `POST /api/db/transaction`: `{status: "rolled_back", message}`; any other status is refused.
  static void transactionRolledBack(String body) => _transactionEnded(body, 'rolled_back');

  static void _transactionEnded(String body, String status) {
    if (_string(_object(body)['status'], 'status') != status) {
      throw FormatException('The transaction answer does not say $status');
    }
  }

  /// `query` of `POST /api/db/transaction`: a query or script answer plus `inTransaction`.
  static TransactionRun transactionRun(String body) {
    final json = _object(body);
    final inTransaction = json['inTransaction'];
    if (inTransaction is! bool) throw const FormatException('The transaction answer has no inTransaction flag');
    return json['multiStatement'] == true
        ? TransactionRun(inTransaction: inTransaction, script: _scriptResult(json))
        : TransactionRun(inTransaction: inTransaction, result: QueryResultJson.fromJson(json));
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

  static ScriptResult _scriptResult(Map<String, dynamic> json) {
    return ScriptResult(
      statements: [for (final item in _list(json['statements'], 'statements')) _statement(_map(item, 'statement'))],
      statementCount: _int(json['statementCount'], 'statementCount'),
      executedCount: _int(json['executedCount'], 'executedCount'),
      executionTime: _duration(json['executionTime'], 'executionTime'),
      openTransactionRolledBack: QueryResultJson.openTransactionRolledBack(json),
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
          ? QueryResultJson.fromJson({
              ...json,
              'rows': json['rows'] ?? const <Object?>[],
              'rowCount': json['rowCount'] is int ? json['rowCount'] : 0,
            })
          : null,
    );
  }

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
}
