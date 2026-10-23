import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/shared/widgets/result_view/column_sizing.dart';

void main() {
  test("Studio's bounds: 80 and 500 px", () {
    expect(resultColumnMinWidth, 80);
    expect(resultColumnMaxWidth, 500);
  });

  test('a short header and short values open at the least width', () {
    expect(contentFitColumnWidth('id', null, false, const ['1', '2']), 80);
  });

  test(
    'the widest sampled value wins over a narrower header, at 7.2 px a character with 33 px of padding and border',
    () {
      // 20 characters: 20 * 7.2 + 32 + 1 = 177.
      expect(contentFitColumnWidth('id', null, false, const ['1', '12345678901234567890']), 177);
    },
  );

  test('a header wider than its values wins, the declared type under the name counted at 6 px a character', () {
    // 'customer_reference' is 18 characters: 18 * 7.2 + 32 + 1 = 162.6, rounded up.
    expect(contentFitColumnWidth('customer_reference', null, false, const ['a']), 163);
    // 'timestamp with time zone' is 24 characters: 24 * 6 + 32 + 1 = 177, wider than the name 'ts'.
    expect(contentFitColumnWidth('ts', 'timestamp with time zone', false, const ['a']), 177);
  });

  test("a masked column's lock adds 16 px to its header", () {
    // 18 * 7.2 + 4 + 12 + 32 + 1 = 178.6, rounded up.
    expect(contentFitColumnWidth('customer_reference', null, true, const ['a']), 179);
  });

  test('a long value is capped at 500 px', () {
    expect(contentFitColumnWidth('note', null, false, ['x' * 1000]), 500);
  });

  test('only the first 200 rows are sampled, so Load more never changes a width', () {
    expect(contentFitSampleRows, 200);
  });
}
