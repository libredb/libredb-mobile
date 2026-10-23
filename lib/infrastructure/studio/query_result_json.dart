import 'dart:convert';

import 'package:libredb_mobile/shared/models/query_page.dart';
import 'package:libredb_mobile/shared/models/query_result.dart';
import 'package:libredb_mobile/shared/models/vector_column.dart';

/// Reads Studio's answer to one statement (`QueryResult` in `src/lib/types.ts`, the body of `POST /api/db/query` in
/// `src/lib/api/editor-query.ts`), for every reader that builds a [QueryResult].
///
/// A missing or mistyped required field throws a [FormatException]. The fields that report lost or incomplete data,
/// `pagination` (with its `wasLimited`), `warnings` and `openTransaction`, are read strictly: present but malformed
/// throws too, so the result is shown as a failure instead of hiding that rows or notices are missing. Absent, they
/// read as none. Any other optional field of an unexpected type is left out.
final class QueryResultJson {
  const QueryResultJson._();

  /// The answer of `POST /api/db/query`.
  static QueryResult read(String body) {
    final json = jsonDecode(body);
    return json is Map<String, dynamic> ? fromJson(json) : throw const FormatException('The answer is not an object');
  }

  /// One statement's result inside a larger answer, such as a script statement or a transaction run.
  static QueryResult fromJson(Map<String, dynamic> json) => QueryResult(
    fields: [for (final item in _list(json['fields'], 'fields')) _string(item, 'fields')],
    rows: [for (final row in _list(json['rows'], 'rows')) Map<String, Object?>.from(_map(row, 'row'))],
    rowCount: _int(json['rowCount'], 'rowCount'),
    executionTime: _duration(json['executionTime'], 'executionTime'),
    columnTypes: _columnTypes(json['columnTypes']),
    warnings: json.containsKey('warnings') ? _warnings(json['warnings']) : const [],
    pagination: json.containsKey('pagination') ? _pagination(json['pagination']) : null,
    openTransactionRolledBack: openTransactionRolledBack(json),
    vectorColumns: _vectorColumns(json['vectorColumns']),
  );

  /// Whether Studio rolled back a transaction the statements left open: `openTransaction` is absent or the string
  /// `rolled-back`, the only value Studio sends; anything else throws.
  static bool openTransactionRolledBack(Map<String, dynamic> json) {
    if (!json.containsKey('openTransaction')) return false;
    return json['openTransaction'] == 'rolled-back'
        ? true
        : throw const FormatException('The openTransaction is not rolled-back');
  }

  static QueryPagination _pagination(Object? value) {
    final pagination = _map(value, 'pagination');
    final wasLimited = pagination['wasLimited'];
    return QueryPagination(
      limit: _int(pagination['limit'], 'limit'),
      offset: _int(pagination['offset'], 'offset'),
      hasMore: _bool(pagination['hasMore'], 'hasMore'),
      totalReturned: _int(pagination['totalReturned'], 'totalReturned'),
      wasLimited: pagination.containsKey('wasLimited') && _bool(wasLimited, 'wasLimited'),
    );
  }

  static List<QueryWarning> _warnings(Object? value) => [for (final item in _list(value, 'warnings')) _warning(item)];

  static QueryWarning _warning(Object? value) {
    final warning = _map(value, 'warning');
    final code = warning['code'];
    final severity = warning['severity'];
    return QueryWarning(
      message: _string(warning['message'], 'warning message'),
      code: code == null ? null : '$code',
      severity: severity is String ? severity : null,
    );
  }

  static Map<String, String> _columnTypes(Object? value) => {
    if (value is Map)
      for (final MapEntry(:key, :value) in value.entries)
        if (key is String && value is String) key: value,
  };

  static Map<String, VectorColumn> _vectorColumns(Object? value) => {
    if (value is Map)
      for (final MapEntry(:key, :value) in value.entries)
        if (key is String) key: ?_vectorColumn(value),
  };

  static VectorColumn? _vectorColumn(Object? value) {
    if (value is! Map) return null;
    final kind = value['kind'];
    final dtype = value['dtype'];
    final dimension = value['dimension'];
    final sparseEncoding = value['sparseEncoding'];
    if (kind is! String || dtype is! String || (dimension != null && dimension is! int)) return null;
    if (sparseEncoding != null && sparseEncoding is! String) return null;
    return VectorColumn(
      kind: kind,
      dtype: dtype,
      dimension: dimension as int?,
      sparseEncoding: sparseEncoding as String?,
    );
  }

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
