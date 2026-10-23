import 'dart:math' as math;

// A port of the content fit of Studio's result columns (`getContentFitColumnSize` in
// `src/components/results-grid/column-sizing.ts:1-2`, `:47-63`, and `CONTENT_FIT_SAMPLE_ROWS` in
// `src/components/ResultsGrid.tsx:103`, at libredb-studio c9989a6b5).
//
// Studio counts 7.2 px a character, the width of its own 12 px monospace font, and 6 px a character of the declared
// type. The phone does not port those figures, since its monospace font is wider: the table measures its header texts
// and one character of its cell font with a text layout in the styles it draws them in, and passes those widths here.
//
// The phone's header differs from the web's in two ways, and the header width follows them: it has no sort or filter
// control, so their 40 px are not counted, and it shows the declared type under the column name rather than beside it,
// so the wider of the two counts rather than their sum.

/// The least width of a result column, in logical pixels at text scale 1.
const resultColumnMinWidth = 80.0;

/// The most width a result column opens at.
const resultColumnMaxWidth = 500.0;

/// How many of the first rows a column's width is read from; a fixed sample keeps a width from jumping when Load more
/// appends a page.
const contentFitSampleRows = 200;

const _horizontalPadding = 32.0;
const _borderWidth = 1.0;
const _markerGap = 4.0;
const _markerWidth = 12.0;

/// The width that shows a column's header, the name [nameWidth] wide with its declared type [typeWidth] wide under it
/// and, when [hasMarker], the lock of a masked column, and the widest of [values] whole, between
/// [resultColumnMinWidth] and [resultColumnMaxWidth].
///
/// [values] are the texts the cells show, of the masked rows. The cell font is monospace, so the longest value's
/// character count times [cellCharacterWidth], one character of that font, is its width, with no layout pass per value.
/// Every width is in logical pixels at text scale 1.
double contentFitColumnWidth({
  required double nameWidth,
  required double typeWidth,
  required bool hasMarker,
  required double cellCharacterWidth,
  required Iterable<String> values,
}) {
  final header =
      math.max(nameWidth, typeWidth) + (hasMarker ? _markerGap + _markerWidth : 0) + _horizontalPadding + _borderWidth;
  var longest = 0;
  for (final value in values) {
    longest = math.max(longest, value.length);
  }
  final cell = longest * cellCharacterWidth + _horizontalPadding + _borderWidth;
  return math.min(resultColumnMaxWidth, math.max(resultColumnMinWidth, math.max(header, cell).ceilToDouble()));
}
