import 'package:flutter/material.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/shared/design_system/tokens/app_spacing.dart';
import 'package:libredb_mobile/shared/models/query_result.dart';
import 'package:libredb_mobile/shared/models/vector_column.dart';
import 'package:libredb_mobile/shared/utils/cell_values.dart';
import 'package:libredb_mobile/shared/widgets/cells/compact_cell.dart';
import 'package:libredb_mobile/shared/widgets/result_view/column_sizing.dart';
import 'package:libredb_mobile/shared/widgets/result_view/row_detail_sheet.dart';

/// The rows of a result as a table (Studio's phone table, `src/components/ResultsGrid.tsx:1429-1491`): a header row
/// pinned above the rows, each column named with its declared type under it when `columnTypes` names one, and the
/// rows built lazily as they scroll into view. The table scrolls sideways as one, header and rows together.
///
/// Every value comes from the masked rows; the header of a column in [maskedColumns] carries a lock that a screen
/// reader reads as a masked value. Each column opens at the width its header and its first rows need
/// ([contentFitColumnWidth]), scaled with the system text size.
///
/// As on a card, a tap on a row opens its detail sheet and a long press on a cell the copy menu of that value and its
/// row (`showRowDetailSheet` and `showRowCopyMenu`), which copy the masked values through the sensitive clipboard.
class ResultTable extends StatefulWidget {
  const ResultTable({super.key, required this.result, required this.maskedColumns});

  final QueryResult result;
  final Set<String> maskedColumns;

  @override
  State<ResultTable> createState() => _ResultTableState();
}

class _ResultTableState extends State<ResultTable> {
  final _horizontal = ScrollController();
  final _vertical = ScrollController();

  @override
  void dispose() {
    _horizontal.dispose();
    _vertical.dispose();
    super.dispose();
  }

  List<double> _widths(BuildContext context) {
    final cellCharacterWidth = _measuredWidth(context, '0', _cellStyle(Theme.of(context)));
    final sample = widget.result.rows.take(contentFitSampleRows).toList();
    return [for (final field in widget.result.fields) _columnWidth(context, field, sample, cellCharacterWidth)];
  }

  /// The content fit of [field]: one layout of its name, its declared type and its longest value in [sample].
  double _columnWidth(
    BuildContext context,
    String field,
    List<Map<String, Object?>> sample,
    double cellCharacterWidth,
  ) {
    final result = widget.result;
    final theme = Theme.of(context);
    final scaler = MediaQuery.textScalerOf(context);
    final masked = widget.maskedColumns.contains(field);
    final longest = _longestSampledCell(sample, field, result.vectorColumns);
    return contentFitColumnWidth(
      nameWidth: _measuredWidth(context, field, _nameStyle(theme)),
      typeWidth: switch (result.columnTypes[field]) {
        final type? => _measuredWidth(context, type, _typeStyle(theme)),
        null => 0,
      },
      markerWidth: masked ? scaler.scale(_markerSize) : 0,
      longestValueLength: longest?.cell.compactText.length ?? 0,
      cellCharacterWidth: cellCharacterWidth,
      longestValueWidth: switch (longest) {
        null => 0,
        (:final cell, :final raw) => _measuredWidth(
          context,
          cell is NullCell ? cell.compactText : CompactCell.shownText(cell.compactText),
          _shownStyle(cell, masked && raw != null ? _maskedStyle(theme) : _cellStyle(theme)),
        ),
      },
      scale: scaler.scale(12) / 12,
    );
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    final widths = _widths(context);
    final total = widths.fold<double>(0, (sum, width) => sum + width);
    final maskedColumns = widget.maskedColumns;
    return Scrollbar(
      controller: _horizontal,
      child: SingleChildScrollView(
        key: const ValueKey('result-table-horizontal'),
        controller: _horizontal,
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: total,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Header(result: result, widths: widths, maskedColumns: widget.maskedColumns),
              const Divider(height: 1),
              Expanded(
                child: Scrollbar(
                  controller: _vertical,
                  child: ListView.builder(
                    controller: _vertical,
                    itemCount: result.rows.length,
                    itemBuilder: (context, index) => ResultTableRow(
                      key: ValueKey('result-row-$index'),
                      row: result.rows[index],
                      fields: result.fields,
                      widths: widths,
                      maskedColumns: widget.maskedColumns,
                      vectorColumns: result.vectorColumns,
                      onTap: () =>
                          showRowDetailSheet(context, result: result, maskedColumns: maskedColumns, index: index),
                      onCellLongPress: (field) => showRowCopyMenu(
                        context,
                        result: result,
                        maskedColumns: maskedColumns,
                        index: index,
                        field: field,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The cell with the most characters of [field] in [sample], with the row's raw value, or null for no rows.
({CellValue cell, Object? raw})? _longestSampledCell(
  List<Map<String, Object?>> sample,
  String field,
  Map<String, VectorColumn> vectorColumns,
) {
  ({CellValue cell, Object? raw})? longest;
  for (final row in sample) {
    final cell = _cellOf(row, field, vectorColumns);
    if (longest == null || cell.compactText.length > longest.cell.compactText.length) {
      longest = (cell: cell, raw: row[field]);
    }
  }
  return longest;
}

/// The style [CompactCell] draws [cell] in, given its [style].
TextStyle? _shownStyle(CellValue cell, TextStyle? style) =>
    cell is NullCell ? style?.copyWith(fontStyle: FontStyle.italic) : style;

/// The width of [text] on one line, laid out as a [Text] in [style] lays it out, with the system text scaler.
double _measuredWidth(BuildContext context, String text, TextStyle? style) {
  var effective = DefaultTextStyle.of(context).style.merge(style);
  if (MediaQuery.boldTextOf(context)) {
    effective = effective.merge(const TextStyle(fontWeight: FontWeight.bold));
  }
  final painter = TextPainter(
    text: TextSpan(text: text, style: effective),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
    locale: Localizations.maybeLocaleOf(context),
    maxLines: 1,
  )..layout();
  final width = painter.width;
  painter.dispose();
  return width;
}

TextStyle? _nameStyle(ThemeData theme) =>
    theme.textTheme.labelMedium?.copyWith(fontFamily: 'monospace', color: theme.colorScheme.onSurfaceVariant);

TextStyle? _typeStyle(ThemeData theme) =>
    theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8));

TextStyle? _cellStyle(ThemeData theme) => theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace');

TextStyle? _maskedStyle(ThemeData theme) =>
    theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic, color: theme.colorScheme.onSurfaceVariant);

const _markerSize = 12.0;

CellValue _cellOf(Map<String, Object?> row, String field, Map<String, VectorColumn> vectorColumns) =>
    classifyCell(row[field], vector: vectorColumns[field], isAbsent: !row.containsKey(field));

const _cellPadding = EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm);

class _Header extends StatelessWidget {
  const _Header({required this.result, required this.widths, required this.maskedColumns});

  final QueryResult result;
  final List<double> widths;
  final Set<String> maskedColumns;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      key: const ValueKey('result-table-header'),
      color: theme.colorScheme.surfaceContainerHigh,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (index, field) in result.fields.indexed)
            Container(
              key: ValueKey('result-header-$field'),
              width: widths[index],
              padding: _cellPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          field,
                          style: _nameStyle(theme),
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (maskedColumns.contains(field))
                        Padding(
                          padding: const EdgeInsetsDirectional.only(start: AppSpacing.xs),
                          child: Icon(
                            Icons.lock_outline,
                            size: MediaQuery.textScalerOf(context).scale(_markerSize),
                            color: theme.colorScheme.tertiary,
                            semanticLabel: S.of(context).result_masked_semantics,
                          ),
                        ),
                    ],
                  ),
                  if (result.columnTypes[field] case final type?)
                    Text(
                      type,
                      key: ValueKey('result-column-type-$field'),
                      style: _typeStyle(theme),
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// One row of a [ResultTable]: a compact cell per field, each in its column's width.
class ResultTableRow extends StatelessWidget {
  const ResultTableRow({
    super.key,
    required this.row,
    required this.fields,
    required this.widths,
    required this.maskedColumns,
    required this.vectorColumns,
    this.onTap,
    this.onCellLongPress,
  });

  final Map<String, Object?> row;
  final List<String> fields;
  final List<double> widths;
  final Set<String> maskedColumns;
  final Map<String, VectorColumn> vectorColumns;

  /// Opens the row's detail.
  final VoidCallback? onTap;

  /// Opens the copy menu of the field whose cell was long pressed.
  final ValueChanged<String>? onCellLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = _cellStyle(theme);
    final maskedStyle = _maskedStyle(theme);
    return InkWell(
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: theme.colorScheme.outlineVariant, width: 0.5)),
        ),
        child: Row(
          children: [
            for (final (index, field) in fields.indexed)
              GestureDetector(
                key: ValueKey('result-cell-$field'),
                behavior: HitTestBehavior.opaque,
                onLongPress: onCellLongPress == null ? null : () => onCellLongPress!(field),
                child: Container(
                  width: widths[index],
                  padding: _cellPadding,
                  child: CompactCell(
                    cell: _cellOf(row, field, vectorColumns),
                    style: maskedColumns.contains(field) && row[field] != null ? maskedStyle : style,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
