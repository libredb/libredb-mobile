import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/shared/widgets/result_view/column_sizing.dart';

double _fit({
  double nameWidth = 0,
  double typeWidth = 0,
  double markerWidth = 0,
  int longestValueLength = 0,
  double cellCharacterWidth = 8,
  double longestValueWidth = 0,
  double scale = 1,
}) => contentFitColumnWidth(
  nameWidth: nameWidth,
  typeWidth: typeWidth,
  markerWidth: markerWidth,
  longestValueLength: longestValueLength,
  cellCharacterWidth: cellCharacterWidth,
  longestValueWidth: longestValueWidth,
  scale: scale,
);

void main() {
  test("Studio's bounds: 80 and 500 px", () {
    expect(resultColumnMinWidth, 80);
    expect(resultColumnMaxWidth, 500);
  });

  test('a short header and short values open at the least width', () {
    expect(_fit(nameWidth: 16, longestValueLength: 1, longestValueWidth: 8), 80);
  });

  test('the widest sampled value wins over a narrower header, at the measured character width plus 33 px', () {
    // 'entry 100' is 9 characters of a font measured at 8.4 px: 9 * 8.4 + 32 + 1 = 108.6, rounded up.
    expect(_fit(nameWidth: 40, longestValueLength: 9, cellCharacterWidth: 8.4, longestValueWidth: 75.6), 109);
    // The same value in a wider font opens a wider column: 9 * 10 + 33 = 123.
    expect(_fit(nameWidth: 40, longestValueLength: 9, cellCharacterWidth: 10, longestValueWidth: 90), 123);
  });

  test('the laid out longest value wins when it is wider than its characters at the cell font, and loses when not', () {
    // A proportional or masked italic face: 12 wide characters laid out at 130 px, against 12 * 6 = 72.
    expect(_fit(longestValueLength: 12, cellCharacterWidth: 6, longestValueWidth: 130), 163);
    // A value of narrow characters laid out at 40 px still gets its 12 * 6 = 72.
    expect(_fit(longestValueLength: 12, cellCharacterWidth: 6, longestValueWidth: 40), 105);
  });

  test('a header wider than its values wins, at its measured width', () {
    // 'null_value' measured at 84.2 px: 84.2 + 32 + 1 = 117.2, rounded up.
    expect(_fit(nameWidth: 84.2, longestValueLength: 1, longestValueWidth: 8), 118);
  });

  test('the declared type under the name counts when it is the wider, not added to the name', () {
    expect(_fit(nameWidth: 16, typeWidth: 150), 183);
    expect(_fit(nameWidth: 150, typeWidth: 100), 183);
  });

  test("a masked column's lock adds its width and a 4 px gap to its header", () {
    // 130 + 4 + 12 + 32 + 1 = 179.
    expect(_fit(nameWidth: 130, markerWidth: 12), 179);
  });

  test('the text scale scales the padding, the gap and the bounds; the measured widths are already scaled', () {
    // 2 * 33 = 66 of padding beside a header laid out at 200 px.
    expect(_fit(nameWidth: 200, scale: 2), 266);
    // 200 + 2 * 4 + 24 + 66 = 298.
    expect(_fit(nameWidth: 200, markerWidth: 24, scale: 2), 298);
    expect(_fit(nameWidth: 10, scale: 2), 160);
    expect(_fit(longestValueWidth: 5000, scale: 2), 1000);
  });

  test('a long value or header is capped at 500 px', () {
    expect(_fit(longestValueLength: 1000, longestValueWidth: 8000), 500);
    expect(_fit(nameWidth: 900), 500);
  });

  test('only the first 200 rows are sampled, so Load more never changes a width', () {
    expect(contentFitSampleRows, 200);
  });
}
