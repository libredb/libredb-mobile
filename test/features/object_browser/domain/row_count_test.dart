import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/features/object_browser/domain/row_count.dart';
import 'package:libredb_mobile/shared/models/query_result.dart';

QueryResult _result(List<String> fields, List<Map<String, Object?>> rows) =>
    QueryResult(fields: fields, rows: rows, rowCount: rows.length, executionTime: Duration.zero);

QueryResult _one(String field, Object? value) => _result(
  [field],
  [
    {field: value},
  ],
);

void main() {
  group('reads the only field of the only row, whatever its name', () {
    test('row_count, as most SQL engines answer', () => expect(readRowCount(_one('row_count', 42)), 42));
    test('ROW_COUNT, as Oracle folds the alias', () => expect(readRowCount(_one('ROW_COUNT', 7)), 7));
    test('count, as MongoDB answers', () => expect(readRowCount(_one('count', 0)), 0));
    test('a string of decimal digits, as Postgres sends a bigint', () {
      expect(readRowCount(_one('row_count', '20000')), 20000);
      expect(readRowCount(_one('row_count', '9007199254740993')), 9007199254740993);
    });
  });

  group('refuses another shape with a FormatException', () {
    final refused = <String, QueryResult>{
      'no row': _result(['row_count'], const []),
      'two rows': _result(
        ['row_count'],
        const [
          {'row_count': 1},
          {'row_count': 2},
        ],
      ),
      'two fields': _result(
        ['row_count', 'other'],
        const [
          {'row_count': 1, 'other': 2},
        ],
      ),
      'no field': _result(const [], const [<String, Object?>{}]),
      'a row with a key the fields do not name': _result(
        ['row_count'],
        const [
          {'row_count': 1, 'extra': 2},
        ],
      ),
      'null': _one('row_count', null),
      'a fraction': _one('row_count', 1.5),
      'a whole double': _one('row_count', 3.0),
      'a negative number': _one('row_count', -1),
      'a negative string': _one('row_count', '-1'),
      'a string with a space': _one('row_count', ' 12'),
      'a string with a sign': _one('row_count', '+12'),
      'an empty string': _one('row_count', ''),
      'a decimal string': _one('row_count', '12.0'),
      'a string past 64 bits': _one('row_count', '99999999999999999999'),
      'a boolean': _one('row_count', true),
      'a map': _one('row_count', const {'n': 1}),
    };
    for (final MapEntry(key: name, value: result) in refused.entries) {
      test(name, () => expect(() => readRowCount(result), throwsFormatException));
    }
  });
}
