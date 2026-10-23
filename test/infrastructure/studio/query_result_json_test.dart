import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/infrastructure/studio/query_result_json.dart';
import 'package:libredb_mobile/shared/models/query_page.dart';
import 'package:libredb_mobile/shared/models/query_result.dart';
import 'package:libredb_mobile/shared/models/vector_column.dart';

void main() {
  Map<String, Object?> answer([Map<String, Object?> more = const {}]) => {
    'rows': [
      {'n': 1},
    ],
    'fields': ['n'],
    'rowCount': 1,
    'executionTime': 2,
    ...more,
  };

  QueryResult read(Map<String, Object?> json) => QueryResultJson.read(jsonEncode(json));

  test('reads rows, fields, the count, the time, the column types and the paging', () {
    final result = read(
      answer({
        'columnTypes': {'n': 'int4', 'odd': 3},
        'pagination': {'limit': 500, 'offset': 0, 'hasMore': true, 'totalReturned': 1, 'wasLimited': true},
      }),
    );

    expect(result.fields, ['n']);
    expect(result.rows, [
      {'n': 1},
    ]);
    expect(result.rowCount, 1);
    expect(result.executionTime, const Duration(milliseconds: 2));
    expect(result.columnTypes, {'n': 'int4'});
    expect(
      result.pagination,
      const QueryPagination(limit: 500, offset: 0, hasMore: true, totalReturned: 1, wasLimited: true),
    );
  });

  test('a result inside a script has no paging; warnings and a rolled-back transaction are kept', () {
    final result = read(
      answer({
        'executionTime': 0.5,
        'openTransaction': 'rolled-back',
        'warnings': [
          {'message': 'table does not exist, skipping', 'code': '00000', 'severity': 'NOTICE'},
          {'message': 'numbered', 'code': 1},
        ],
      }),
    );

    expect(result.pagination, isNull);
    expect(result.openTransactionRolledBack, isTrue);
    expect(result.executionTime, const Duration(microseconds: 500));
    expect(result.warnings, const [
      QueryWarning(message: 'table does not exist, skipping', code: '00000', severity: 'NOTICE'),
      QueryWarning(message: 'numbered', code: '1'),
    ]);
  });

  test('refuses an answer without fields, rows or a row count', () {
    for (final body in [
      '{"rows":[],"rowCount":0,"executionTime":1}',
      '{"fields":[],"rowCount":0,"executionTime":1}',
      '{"rows":[],"fields":[],"executionTime":1}',
      '{"rows":[1],"fields":[],"rowCount":0,"executionTime":1}',
    ]) {
      expect(() => QueryResultJson.read(body), throwsFormatException, reason: body);
    }
  });

  group('the loss notices are read strictly', () {
    const page = {'limit': 500, 'offset': 0, 'hasMore': false, 'totalReturned': 1};
    final malformed = <String, Map<String, Object?>>{
      'a wasLimited string': {
        'pagination': {...page, 'wasLimited': 'true'},
      },
      'a wasLimited null': {
        'pagination': {...page, 'wasLimited': null},
      },
      'a pagination without wasLimited': {'pagination': page},
      'a pagination string': {'pagination': 'none'},
      'a pagination null': {'pagination': null},
      'a warnings object': {
        'warnings': {'message': 'x'},
      },
      'a warning without message': {
        'warnings': [
          {'code': 1},
        ],
      },
      'a warning whose message is not a string': {
        'warnings': [
          {'message': 7},
        ],
      },
      'a warning that is not an object': {
        'warnings': ['x'],
      },
      'an openTransaction of committed': {'openTransaction': 'committed'},
      'an openTransaction that is not a string': {'openTransaction': true},
    };

    for (final MapEntry(key: name, value: more) in malformed.entries) {
      test('$name fails the read', () {
        expect(() => read(answer(more)), throwsFormatException);
      });
    }

    test('absent ones read as none', () {
      final result = read(
        answer({
          'pagination': {...page, 'wasLimited': false},
        }),
      );

      expect(result.pagination?.wasLimited, isFalse);
      expect(result.warnings, isEmpty);
      expect(result.openTransactionRolledBack, isFalse);
      expect(read(answer()).pagination, isNull);
    });
  });

  group('vectorColumns', () {
    test('reads each declared column', () {
      final result = read(
        answer({
          'vectorColumns': {
            'emb': {'kind': 'dense', 'dtype': 'float32', 'dimension': 3},
            'bits': {'kind': 'dense', 'dtype': 'binary', 'dimension': 64},
            'terms': {'kind': 'sparse', 'dtype': 'float32', 'dimension': null, 'sparseEncoding': 'index-map'},
            'rows': {'kind': 'multi', 'dtype': 'float16', 'dimension': 4},
          },
        }),
      );

      expect(result.vectorColumns, const {
        'emb': VectorColumn(kind: 'dense', dtype: 'float32', dimension: 3),
        'bits': VectorColumn(kind: 'dense', dtype: 'binary', dimension: 64),
        'terms': VectorColumn(kind: 'sparse', dtype: 'float32', dimension: null, sparseEncoding: 'index-map'),
        'rows': VectorColumn(kind: 'multi', dtype: 'float16', dimension: 4),
      });
    });

    test('keeps a kind, a type or an encoding it does not know as an opaque string', () {
      final result = read(
        answer({
          'vectorColumns': {
            'q': {'kind': 'quantum', 'dtype': 'float8', 'dimension': 2, 'sparseEncoding': 'run-length'},
          },
        }),
      );

      expect(result.vectorColumns, const {
        'q': VectorColumn(kind: 'quantum', dtype: 'float8', dimension: 2, sparseEncoding: 'run-length'),
      });
    });

    test('a column without a dimension has none', () {
      final result = read(
        answer({
          'vectorColumns': {
            'emb': {'kind': 'dense', 'dtype': 'float32'},
          },
        }),
      );

      expect(result.vectorColumns['emb']?.dimension, isNull);
    });

    test('leaves out an entry of an unexpected shape and keeps the others', () {
      final result = read(
        answer({
          'vectorColumns': {
            'ok': {'kind': 'dense', 'dtype': 'float32', 'dimension': 3},
            'not an object': 'dense',
            'no kind': {'dtype': 'float32', 'dimension': 3},
            'kind a number': {'kind': 1, 'dtype': 'float32', 'dimension': 3},
            'no dtype': {'kind': 'dense', 'dimension': 3},
            'dimension a string': {'kind': 'dense', 'dtype': 'float32', 'dimension': '3'},
            'dimension a fraction': {'kind': 'dense', 'dtype': 'float32', 'dimension': 1.5},
            'encoding a number': {'kind': 'sparse', 'dtype': 'float32', 'dimension': null, 'sparseEncoding': 1},
          },
        }),
      );

      expect(result.vectorColumns.keys, ['ok']);
    });

    test('a vectorColumns that is not an object declares none', () {
      expect(read(answer({'vectorColumns': 'emb'})).vectorColumns, isEmpty);
      expect(read(answer()).vectorColumns, isEmpty);
    });
  });
}
