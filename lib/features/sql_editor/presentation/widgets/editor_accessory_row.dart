import 'package:flutter/material.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/shared/design_system/tokens/app_spacing.dart';

/// [value] with [text] put in place of its selection, or at its cursor, and the cursor after it; a value without a
/// cursor gets [text] at its end.
TextEditingValue insertAtSelection(TextEditingValue value, String text) {
  final selection = value.selection;
  final (start, end) = selection.isValid ? (selection.start, selection.end) : (value.text.length, value.text.length);
  return TextEditingValue(
    text: value.text.replaceRange(start, end, text),
    selection: TextSelection.collapsed(offset: start + text.length),
  );
}

/// The row above the keyboard with the characters a statement needs that a phone keyboard hides, Tab (two spaces),
/// Undo and Redo: each insert goes in place of the selection or at the cursor.
///
/// It scrolls sideways, so every button keeps its size at the largest text scale, and it counts as part of the field
/// for taps, so tapping a button keeps the keyboard open.
class EditorAccessoryRow extends StatelessWidget {
  const EditorAccessoryRow({super.key, required this.controller, required this.undoController});

  final TextEditingController controller;
  final UndoHistoryController undoController;

  static const symbols = [';', ',', '(', ')', '*', "'", '"', '=', '.'];

  static const tab = '  ';

  static Key symbolKey(String symbol) => ValueKey('sql-editor-insert-$symbol');
  static const tabKey = ValueKey('sql-editor-insert-tab');
  static const undoKey = ValueKey('sql-editor-undo');
  static const redoKey = ValueKey('sql-editor-redo');

  void _insert(String text) => controller.value = insertAtSelection(controller.value, text);

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final mono = Theme.of(context).textTheme.titleMedium?.copyWith(fontFamily: 'monospace');
    return TextFieldTapRegion(
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          child: ValueListenableBuilder<UndoHistoryValue>(
            valueListenable: undoController,
            builder: (context, history, _) => Row(
              children: [
                for (final symbol in symbols)
                  TextButton(
                    key: symbolKey(symbol),
                    onPressed: () => _insert(symbol),
                    child: Text(symbol, style: mono),
                  ),
                IconButton(
                  key: tabKey,
                  tooltip: s.sql_editor_tab,
                  onPressed: () => _insert(tab),
                  icon: const Icon(Icons.keyboard_tab),
                ),
                IconButton(
                  key: undoKey,
                  tooltip: s.sql_editor_undo,
                  onPressed: history.canUndo ? undoController.undo : null,
                  icon: const Icon(Icons.undo),
                ),
                IconButton(
                  key: redoKey,
                  tooltip: s.sql_editor_redo,
                  onPressed: history.canRedo ? undoController.redo : null,
                  icon: const Icon(Icons.redo),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
