import 'package:libredb_mobile/shared/models/query_result.dart';

final _digits = RegExp(r'^[0-9]+$');

/// The count a count statement answered: the only field of the only row, whatever its name, since Studio's answer
/// names it `row_count` on most SQL engines, `ROW_COUNT` on Oracle, which folds the unquoted alias, and `count` on
/// MongoDB.
///
/// The value is a JSON integer or a string of decimal digits, as Postgres sends a `bigint`. Another row count, field
/// count or value throws a [FormatException], which names no value.
int readRowCount(QueryResult result) {
  if (result.rows.length != 1) throw const FormatException('A count answer has one row');
  if (result.fields.length != 1) throw const FormatException('A count answer has one field');
  final row = result.rows.single;
  final field = result.fields.single;
  if (row.length != 1 || !row.containsKey(field)) throw const FormatException('A count row holds its one field');
  return switch (row[field]) {
    final int count when count >= 0 => count,
    final String digits when _digits.hasMatch(digits) =>
      int.tryParse(digits) ?? (throw const FormatException('A count past 64 bits')),
    _ => throw const FormatException('A count is a whole number or a string of digits'),
  };
}
