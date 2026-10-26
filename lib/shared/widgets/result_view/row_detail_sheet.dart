import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:libredb_mobile/core/logging/app_logger.dart';
import 'package:libredb_mobile/core/security/screen_capture_guard.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/shared/design_system/tokens/app_spacing.dart';
import 'package:libredb_mobile/shared/models/query_result.dart';
import 'package:libredb_mobile/shared/utils/cell_values.dart';
import 'package:libredb_mobile/shared/utils/sensitive_clipboard.dart';
import 'package:libredb_mobile/shared/widgets/cells/detail_cell.dart';
import 'package:libredb_mobile/shared/widgets/cells/sensitive_selectable_text.dart';
import 'package:libredb_mobile/shared/design_system/tokens/app_typography.dart';

// The row detail sheet and the copy of a field or a row, as Studio's `RowDetailSheet`
// (`src/components/results-grid/RowDetailSheet.tsx`) and the grid's copy menu (`copyCell` and `copyRow`,
// `src/components/ResultsGrid.tsx:484-526`) at libredb-studio c9989a6b5. Every value comes from the masked rows the
// result view holds, and every copy goes through [SensitiveClipboard].

final _log = AppLogger.getLogger('RowCopy');

/// Whether [field] of [row] is masked: a masked column whose value is not NULL, as the sheet and the card show it.
bool isMaskedField(Map<String, Object?> row, String field, Set<String> maskedColumns) =>
    maskedColumns.contains(field) && row[field] != null;

/// What a copy of [field] of [row] writes: the mask of a masked field, else [CellValue.copyText] (Studio's
/// `copyTextOf`): the full hex of a binary value, the whole vector, the pretty JSON, `null` for NULL and `NULL` for a
/// field the row lacks.
String fieldCopyText(QueryResult result, Set<String> maskedColumns, int index, String field) {
  final row = result.rows[index];
  if (isMaskedField(row, field, maskedColumns)) return row[field]! as String;
  return classifyCell(row[field], vector: result.vectorColumns[field], isAbsent: !row.containsKey(field)).copyText;
}

/// Puts [text] on the clipboard through [SensitiveClipboard] and says on [messenger] whether it got there. A failure is
/// logged with its type and code, never the text.
Future<void> copyResultText(ScaffoldMessengerState messenger, S s, String text) async {
  String message;
  try {
    await SensitiveClipboard.copy(text);
    message = s.result_copied;
  } on PlatformException catch (error) {
    _log.warn('result value not copied: {} {}', [error.runtimeType, error.code]);
    message = s.result_copy_failed(error.code);
  } on MissingPluginException catch (error) {
    _log.warn('result value not copied: {}', [error.runtimeType]);
    message = s.result_copy_failed('MissingPluginException');
  } on UnsupportedError catch (error) {
    _log.warn('result value not copied: {}', [error.runtimeType]);
    message = s.result_copy_failed('UnsupportedError');
  }
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// Opens the row at [index] of [result] in a full-height modal sheet, over the page and its rows, with no route of its
/// own; a horizontal swipe moves through the rows already loaded and asks for none.
Future<void> showRowDetailSheet(
  BuildContext context, {
  required QueryResult result,
  required Set<String> maskedColumns,
  required int index,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (context) => RowDetailSheet(result: result, maskedColumns: maskedColumns, initialIndex: index),
);

/// The menu a long press on a field of a card or a table cell opens: Copy value and Copy row as JSON.
Future<void> showRowCopyMenu(
  BuildContext context, {
  required QueryResult result,
  required Set<String> maskedColumns,
  required int index,
  required String field,
}) {
  final messenger = ScaffoldMessenger.of(context);
  final s = S.of(context);
  return showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: Text(
              field,
              style: const TextStyle(fontFamily: AppTypography.mono),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(s.result_row_title(index + 1)),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.copy),
            title: Text(s.result_copy_value),
            onTap: () {
              Navigator.of(sheetContext).pop();
              copyResultText(messenger, s, fieldCopyText(result, maskedColumns, index, field));
            },
          ),
          ListTile(
            leading: const Icon(Icons.data_object),
            title: Text(s.result_copy_row),
            onTap: () {
              Navigator.of(sheetContext).pop();
              copyResultText(messenger, s, rowJsonText(result.rows[index]));
            },
          ),
        ],
      ),
    ),
  );
}

/// The rows of a result one at a time, from [initialIndex]: each field's name, its declared type from
/// [QueryResult.columnTypes] and its detail form, selectable, with a copy per field and a Copy row of the whole row.
///
/// The sheet holds its own messenger, so a copy's notice shows above the sheet rather than under it.
///
/// While open it keeps out of screenshots, screen recordings and the recent-apps preview ([ScreenCaptureGuard]) with a
/// lease of its own, so the result under it stays protected when it closes.
class RowDetailSheet extends StatefulWidget {
  const RowDetailSheet({super.key, required this.result, required this.maskedColumns, required this.initialIndex});

  final QueryResult result;
  final Set<String> maskedColumns;
  final int initialIndex;

  @override
  State<RowDetailSheet> createState() => _RowDetailSheetState();
}

class _RowDetailSheetState extends State<RowDetailSheet> {
  late int _index = widget.initialIndex;
  late final _pages = PageController(initialPage: widget.initialIndex);

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final result = widget.result;
    return ScreenCaptureGuard(
      child: ScaffoldMessenger(
        child: Builder(
          builder: (context) => Scaffold(
            backgroundColor: Colors.transparent,
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.sm, AppSpacing.sm),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          s.result_row_position(_index + 1, result.rows.length),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      TextButton.icon(
                        key: const ValueKey('row-copy-json'),
                        icon: const Icon(Icons.data_object),
                        label: Text(s.result_copy_row),
                        onPressed: () =>
                            copyResultText(ScaffoldMessenger.of(context), s, rowJsonText(result.rows[_index])),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: PageView.builder(
                    key: const ValueKey('row-pages'),
                    controller: _pages,
                    itemCount: result.rows.length,
                    onPageChanged: (index) => setState(() => _index = index),
                    itemBuilder: (context, index) =>
                        _RowFields(result: result, maskedColumns: widget.maskedColumns, index: index),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RowFields extends StatelessWidget {
  const _RowFields({required this.result, required this.maskedColumns, required this.index});

  final QueryResult result;
  final Set<String> maskedColumns;
  final int index;

  @override
  Widget build(BuildContext context) => ListView.separated(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
    itemCount: result.fields.length,
    separatorBuilder: (context, _) => const Divider(height: 1, indent: AppSpacing.lg, endIndent: AppSpacing.lg),
    itemBuilder: (context, position) =>
        _FieldTile(result: result, maskedColumns: maskedColumns, index: index, field: result.fields[position]),
  );
}

class _FieldTile extends StatelessWidget {
  const _FieldTile({required this.result, required this.maskedColumns, required this.index, required this.field});

  final QueryResult result;
  final Set<String> maskedColumns;
  final int index;
  final String field;

  void _copy(BuildContext context) =>
      copyResultText(ScaffoldMessenger.of(context), S.of(context), fieldCopyText(result, maskedColumns, index, field));

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final row = result.rows[index];
    final masked = isMaskedField(row, field, maskedColumns);
    final type = result.columnTypes[field];
    final valueStyle = theme.textTheme.bodyMedium;
    void copySelection(String text) => copyResultText(ScaffoldMessenger.of(context), s, text);
    return Padding(
      key: ValueKey('row-field-$field'),
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.xs, AppSpacing.xs, AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The name takes the long press; the value below keeps it for selecting part of the text.
          InkWell(
            key: const ValueKey('row-field-label'),
            onLongPress: () => _copy(context),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              field,
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: muted,
                                fontFamily: AppTypography.mono,
                              ),
                            ),
                          ),
                          if (masked)
                            Padding(
                              padding: const EdgeInsetsDirectional.only(start: AppSpacing.xs),
                              child: Icon(
                                Icons.lock_outline,
                                size: MediaQuery.textScalerOf(context).scale(12),
                                color: theme.colorScheme.tertiary,
                                semanticLabel: s.result_masked_semantics,
                              ),
                            ),
                        ],
                      ),
                      if (type != null)
                        Text(type, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline)),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy, size: 18),
                  tooltip: s.result_copy_value,
                  onPressed: () => _copy(context),
                ),
              ],
            ),
          ),
          if (masked)
            SensitiveSelectableText(
              row[field]! as String,
              onCopy: copySelection,
              style: valueStyle?.copyWith(fontStyle: FontStyle.italic, color: muted),
            )
          else
            DetailCell(
              cell: classifyCell(row[field], vector: result.vectorColumns[field], isAbsent: !row.containsKey(field)),
              onCopy: copySelection,
              style: valueStyle,
            ),
        ],
      ),
    );
  }
}
