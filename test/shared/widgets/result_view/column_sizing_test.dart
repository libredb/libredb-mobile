import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/shared/widgets/result_view/column_sizing.dart';

double _fit({
  double nameWidth = 0,
  double typeWidth = 0,
  bool hasMarker = false,
  double cellCharacterWidth = 8,
  List<String> values = const [],
}) => contentFitColumnWidth(
  nameWidth: nameWidth,
  typeWidth: typeWidth,
  hasMarker: hasMarker,
  cellCharacterWidth: cellCharacterWidth,
  values: values,
);

void main() {
  test("Studio's bounds: 80 and 500 px", () {
    expect(resultColumnMinWidth, 80);
    expect(resultColumnMaxWidth, 500);
  });

  test('a short header and short values open at the least width', () {
    expect(_fit(nameWidth: 16, values: const ['1', '2']), 80);
  });

  test('the widest sampled value wins over a narrower header, at the measured character width plus 33 px', () {
    // 'entry 100' is 9 characters of a font measured at 8.4 px: 9 * 8.4 + 32 + 1 = 108.6, rounded up.
    expect(_fit(nameWidth: 40, cellCharacterWidth: 8.4, values: const ['entry 1', 'entry 100', 'entry 10']), 109);
    // The same values in a wider font open a wider column: 9 * 10 + 33 = 123.
    expect(_fit(nameWidth: 40, cellCharacterWidth: 10, values: const ['entry 100']), 123);
  });

  test('a header wider than its values wins, at its measured width', () {
    // 'null_value' measured at 84.2 px: 84.2 + 32 + 1 = 117.2, rounded up.
    expect(_fit(nameWidth: 84.2, values: const ['a']), 118);
  });

  test('the declared type under the name counts when it is the wider, not added to the name', () {
    expect(_fit(nameWidth: 16, typeWidth: 150, values: const ['a']), 183);
    expect(_fit(nameWidth: 150, typeWidth: 100, values: const ['a']), 183);
  });

  test("a masked column's lock adds 16 px to its header", () {
    // 130 + 4 + 12 + 32 + 1 = 179.
    expect(_fit(nameWidth: 130, hasMarker: true, values: const ['a']), 179);
  });

  test('a long value or header is capped at 500 px', () {
    expect(_fit(values: ['x' * 1000]), 500);
    expect(_fit(nameWidth: 900), 500);
  });

  test('only the first 200 rows are sampled, so Load more never changes a width', () {
    expect(contentFitSampleRows, 200);
  });
}
