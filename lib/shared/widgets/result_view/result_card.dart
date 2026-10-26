import 'package:flutter/material.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/shared/design_system/tokens/app_radius.dart';
import 'package:libredb_mobile/shared/design_system/tokens/app_spacing.dart';
import 'package:libredb_mobile/shared/models/vector_column.dart';
import 'package:libredb_mobile/shared/utils/cell_values.dart';
import 'package:libredb_mobile/shared/widgets/cells/compact_cell.dart';
import 'package:libredb_mobile/shared/widgets/result_view/result_fields.dart';
import 'package:libredb_mobile/shared/design_system/tokens/app_typography.dart';

/// One row of a result as Studio's card (`src/components/results-grid/ResultCard.tsx`): the [primary] field as its
/// title, `Row n` when that value is NULL or the row lacks it, the [id] field under it when there is one, then the
/// [preview] fields and how many fields it does not show.
///
/// Every value comes from the masked rows; a field of [maskedColumns] with a value carries a lock that a screen reader
/// reads as a masked value. Nothing has a fixed height, so a card grows with the system text size.
class ResultCard extends StatelessWidget {
  const ResultCard({
    super.key,
    required this.row,
    required this.index,
    required this.fieldCount,
    required this.primary,
    required this.id,
    required this.preview,
    required this.maskedColumns,
    required this.vectorColumns,
    this.onTap,
    this.onFieldLongPress,
  });

  final Map<String, Object?> row;

  /// The row's place in the result, from 0.
  final int index;

  /// How many fields the result has.
  final int fieldCount;

  final String? primary;
  final String? id;
  final List<String> preview;
  final Set<String> maskedColumns;
  final Map<String, VectorColumn> vectorColumns;

  /// Opens the row detail; without it the card is not tappable.
  final VoidCallback? onTap;

  /// Opens the copy menu of the field a long press landed on: the title, the id line or a preview field.
  final ValueChanged<String>? onFieldLongPress;

  /// [child], showing [field], with the long press that opens its copy menu.
  Widget _field(String field, Widget child) {
    final onFieldLongPress = this.onFieldLongPress;
    return GestureDetector(
      key: ValueKey('card-field-$field'),
      behavior: HitTestBehavior.opaque,
      onLongPress: onFieldLongPress == null ? null : () => onFieldLongPress(field),
      child: child,
    );
  }

  /// The title row, which takes a long press only when it shows a field rather than `Row n`.
  Widget _titleRow(String? field, Widget child) => field == null ? child : _field(field, child);

  CellValue _cell(String field) =>
      classifyCell(row[field], vector: vectorColumns[field], isAbsent: !row.containsKey(field));

  bool _isMasked(String field) => maskedColumns.contains(field) && row[field] != null;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final primary = this.primary;
    final id = this.id;
    final hasTitle = primary != null && row[primary] != null;
    final titleStyle = theme.textTheme.titleSmall;
    final maskedStyle = TextStyle(fontStyle: FontStyle.italic, color: muted);
    final shown = (primary == null ? 0 : 1) + (id == null || id == primary ? 0 : 1) + preview.length;
    final hidden = fieldCount - shown;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.xs),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: AppSpacing.sm,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _titleRow(
                          hasTitle ? primary : null,
                          Row(
                            children: [
                              Flexible(
                                child: hasTitle
                                    ? CompactCell(
                                        cell: _cell(primary),
                                        style: _isMasked(primary) ? titleStyle?.merge(maskedStyle) : titleStyle,
                                      )
                                    : Text(
                                        s.result_row_title(index + 1),
                                        style: titleStyle,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                              ),
                              if (hasTitle && _isMasked(primary)) _Lock(label: s.result_masked_semantics),
                            ],
                          ),
                        ),
                        if (id != null && id != primary && row[id] != null)
                          _field(
                            id,
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    s.result_card_id(_cell(id).compactText),
                                    style: _isMasked(id)
                                        ? theme.textTheme.bodySmall?.merge(maskedStyle)
                                        : theme.textTheme.bodySmall?.copyWith(
                                            color: muted,
                                            fontFamily: AppTypography.mono,
                                          ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (_isMasked(id)) _Lock(label: s.result_masked_semantics),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (onTap != null) Icon(Icons.chevron_right, color: muted),
                ],
              ),
              for (final field in preview)
                _field(
                  field,
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                field,
                                style: theme.textTheme.bodySmall?.copyWith(color: muted),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (_isMasked(field)) _Lock(label: s.result_masked_semantics),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        flex: 3,
                        child: Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: CompactCell(
                            cell: _cell(field),
                            style: _isMasked(field)
                                ? theme.textTheme.bodySmall?.merge(maskedStyle)
                                : theme.textTheme.bodySmall?.copyWith(fontFamily: AppTypography.mono),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (hidden > 0)
                Text(
                  s.result_more_fields(hidden),
                  style: theme.textTheme.bodySmall?.copyWith(color: muted),
                  textAlign: TextAlign.center,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The lock on a masked field, sized with the text beside it.
class _Lock extends StatelessWidget {
  const _Lock({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.only(start: AppSpacing.xs),
    child: Icon(
      Icons.lock_outline,
      size: MediaQuery.textScalerOf(context).scale(12),
      color: Theme.of(context).colorScheme.tertiary,
      semanticLabel: label,
    ),
  );
}

/// The cards of [rows], built lazily as they scroll into view.
class ResultCardList extends StatelessWidget {
  const ResultCardList({
    super.key,
    required this.fields,
    required this.rows,
    required this.maskedColumns,
    required this.vectorColumns,
    this.onRowTap,
    this.onFieldLongPress,
  });

  final List<String> fields;
  final List<Map<String, Object?>> rows;
  final Set<String> maskedColumns;
  final Map<String, VectorColumn> vectorColumns;
  final ValueChanged<int>? onRowTap;

  /// Opens the copy menu of a card's field, with the row's index and the field.
  final void Function(int index, String field)? onFieldLongPress;

  @override
  Widget build(BuildContext context) {
    final primary = primaryField(fields, rows);
    final id = idField(fields);
    final preview = previewFields(fields, primary: primary, id: id);
    final onRowTap = this.onRowTap;
    final onFieldLongPress = this.onFieldLongPress;
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      itemCount: rows.length,
      itemBuilder: (context, index) => ResultCard(
        key: ValueKey('result-card-$index'),
        row: rows[index],
        index: index,
        fieldCount: fields.length,
        primary: primary,
        id: id,
        preview: preview,
        maskedColumns: maskedColumns,
        vectorColumns: vectorColumns,
        onTap: onRowTap == null ? null : () => onRowTap(index),
        onFieldLongPress: onFieldLongPress == null ? null : (field) => onFieldLongPress(index, field),
      ),
    );
  }
}
