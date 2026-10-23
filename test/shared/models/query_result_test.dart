import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/shared/models/query_page.dart';
import 'package:libredb_mobile/shared/models/query_result.dart';
import 'package:libredb_mobile/shared/models/vector_column.dart';

// Ports Studio's cases of the Load more append rule (libredb-studio tests/unit/lib/results/append-page.test.ts).
void main() {
  const vectors = {'emb': VectorColumn(kind: 'dense', dtype: 'float32', dimension: 3)};
  const pagination = QueryPagination(limit: 2, offset: 2, hasMore: false, totalReturned: 1, wasLimited: false);

  QueryResult shownOf({Map<String, VectorColumn> vectorColumns = const {}}) => QueryResult(
    fields: const ['n'],
    rows: const [
      {'n': 1},
      {'n': 2},
    ],
    rowCount: 2,
    executionTime: const Duration(milliseconds: 3),
    vectorColumns: vectorColumns,
  );

  QueryResult pageOf({
    List<String> fields = const ['n'],
    List<Map<String, Object?>> rows = const [
      {'n': 3},
    ],
    Duration executionTime = const Duration(milliseconds: 7),
    Map<String, VectorColumn> vectorColumns = const {},
  }) => QueryResult(
    fields: fields,
    rows: rows,
    rowCount: rows.length,
    executionTime: executionTime,
    pagination: pagination,
    vectorColumns: vectorColumns,
  );

  group('appendResultPage', () {
    test('rows are concatenated after the rows on screen and rowCount is the merged count', () {
      expect(
        appendResultPage(shownOf(), pageOf()),
        const QueryResult(
          fields: ['n'],
          rows: [
            {'n': 1},
            {'n': 2},
            {'n': 3},
          ],
          rowCount: 3,
          executionTime: Duration(milliseconds: 7),
          pagination: pagination,
        ),
      );
    });

    test('an empty page that names no fields keeps the fields the rows are rendered under', () {
      final merged = appendResultPage(shownOf(), pageOf(fields: const [], rows: const []));

      expect(merged.fields, ['n']);
      expect(merged.rows, [
        {'n': 1},
        {'n': 2},
      ]);
      expect(merged.rowCount, 2);
    });

    test('a page that names fields is believed', () {
      expect(appendResultPage(shownOf(), pageOf(fields: const ['n', 'm'])).fields, ['n', 'm']);
    });

    test("a page that declares no vectorColumns keeps the rows' declaration", () {
      expect(appendResultPage(shownOf(vectorColumns: vectors), pageOf()).vectorColumns, vectors);
    });

    test('a page that declares its own vectorColumns is believed', () {
      const own = {'v': VectorColumn(kind: 'dense', dtype: 'float32', dimension: 2)};

      expect(appendResultPage(shownOf(vectorColumns: vectors), pageOf(vectorColumns: own)).vectorColumns, own);
    });

    test('with no declaration on either side there is none', () {
      expect(appendResultPage(shownOf(), pageOf()).vectorColumns, isEmpty);
    });

    test('every other field comes from the newest page, and nothing else is carried', () {
      final shown = QueryResult(
        fields: const ['n'],
        rows: shownOf().rows,
        rowCount: 2,
        executionTime: const Duration(milliseconds: 3),
        warnings: const [QueryWarning(message: 'old')],
        columnTypes: const {'n': 'int4'},
        pagination: const QueryPagination(limit: 2, offset: 0, hasMore: true, totalReturned: 2, wasLimited: true),
        openTransactionRolledBack: true,
      );
      final page = pageOf(executionTime: const Duration(milliseconds: 9));

      final merged = appendResultPage(shown, page);

      expect(merged.executionTime, const Duration(milliseconds: 9));
      expect(merged.pagination, pagination);
      expect(merged.warnings, isEmpty);
      expect(merged.columnTypes, isEmpty);
      expect(merged.openTransactionRolledBack, isFalse);
    });

    test("the newest page's warnings and column types replace the shown ones", () {
      final shown = QueryResult(
        fields: const ['n'],
        rows: shownOf().rows,
        rowCount: 2,
        executionTime: Duration.zero,
        warnings: const [QueryWarning(message: 'old')],
        columnTypes: const {'n': 'int4'},
      );
      const page = QueryResult(
        fields: ['n'],
        rows: [
          {'n': 3},
        ],
        rowCount: 1,
        executionTime: Duration.zero,
        warnings: [QueryWarning(message: 'new', code: '01000', severity: 'WARNING')],
        columnTypes: {'n': 'int8'},
      );

      final merged = appendResultPage(shown, page);

      expect(merged.warnings, const [QueryWarning(message: 'new', code: '01000', severity: 'WARNING')]);
      expect(merged.columnTypes, {'n': 'int8'});
    });

    test('neither input is changed', () {
      final shown = shownOf();
      final page = pageOf();

      final merged = appendResultPage(shown, page);

      expect(shown.rows, [
        {'n': 1},
        {'n': 2},
      ]);
      expect(page.rows, [
        {'n': 3},
      ]);
      expect(identical(merged.rows, shown.rows), isFalse);
    });
  });

  test('a result without vector columns declares none', () {
    const result = QueryResult(fields: [], rows: [], rowCount: 0, executionTime: Duration.zero);

    expect(result.vectorColumns, isEmpty);
  });

  test('two vector columns are equal when every part is', () {
    expect(
      const VectorColumn(kind: 'sparse', dtype: 'float32', dimension: null, sparseEncoding: 'index-map'),
      const VectorColumn(kind: 'sparse', dtype: 'float32', dimension: null, sparseEncoding: 'index-map'),
    );
    expect(
      const VectorColumn(kind: 'sparse', dtype: 'float32', dimension: null, sparseEncoding: 'index-map'),
      isNot(const VectorColumn(kind: 'sparse', dtype: 'float32', dimension: null, sparseEncoding: 'indices-values')),
    );
  });
}
