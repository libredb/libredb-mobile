import 'dart:math' as math;

// A port of the content fit of Studio's result columns (`getContentFitColumnSize` in
// `src/components/results-grid/column-sizing.ts:1-2`, `:47-63`, and `CONTENT_FIT_SAMPLE_ROWS` in
// `src/components/ResultsGrid.tsx:103`, at libredb-studio c9989a6b5).
//
// Studio counts 7.2 px a character, the width of its own 12 px monospace font, and 6 px a character of the declared
// type. The phone does not port those figures, since its monospace font is wider: the table measures its header texts,
// one character of its cell font and each column's longest sampled value with a text layout, in the styles and with the
// text scaler it draws them in, and passes those widths here.
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

/// The width that shows a column's header, the name [nameWidth] wide with its declared type [typeWidth] wide under it
/// and, when [markerWidth] is not 0, the lock of a masked column that wide, and its widest sampled value whole, between
/// [resultColumnMinWidth] and [resultColumnMaxWidth].
///
/// The widest value is the longer of [longestValueWidth], the laid out width of the sample's value with the most
/// characters, and that count of [cellCharacterWidth], one character of the cell font: the count holds where the font
/// is fixed width, the layout where it is not or the value is drawn in another style.
///
/// The text widths are as drawn, with the system text scaler; [scale], the text scale at 12 px, scales the padding and
/// the bounds.
double contentFitColumnWidth({
  required double nameWidth,
  required double typeWidth,
  required double markerWidth,
  required int longestValueLength,
  required double cellCharacterWidth,
  required double longestValueWidth,
  double scale = 1,
}) {
  final padding = (_horizontalPadding + _borderWidth) * scale;
  final marker = markerWidth > 0 ? _markerGap * scale + markerWidth : 0;
  final header = math.max(nameWidth, typeWidth) + marker + padding;
  final cell = math.max(longestValueLength * cellCharacterWidth, longestValueWidth) + padding;
  return math.min(
    resultColumnMaxWidth * scale,
    math.max(resultColumnMinWidth * scale, math.max(header, cell).ceilToDouble()),
  );
}
