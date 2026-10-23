import 'package:flutter/material.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/shared/design_system/tokens/app_spacing.dart';

/// The statement the user types: a multi-line monospace field that fills its space, coloured by its controller, with
/// every input aid that would change the text turned off, since a smart quote or a corrected word breaks a statement.
///
/// Its undo history and scroll position live in the page's controllers, so a rotation keeps them; it is read only
/// while the saved draft is read, so the draft never lands over a text typed meanwhile.
class EditorInput extends StatelessWidget {
  const EditorInput({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.undoController,
    required this.scrollController,
    this.readOnly = false,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final UndoHistoryController undoController;
  final ScrollController scrollController;
  final bool readOnly;

  static const fieldKey = ValueKey('sql-editor-input');

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 0),
      child: TextField(
        key: fieldKey,
        controller: controller,
        focusNode: focusNode,
        undoController: undoController,
        scrollController: scrollController,
        readOnly: readOnly,
        expands: true,
        maxLines: null,
        minLines: null,
        keyboardType: TextInputType.multiline,
        textAlignVertical: TextAlignVertical.top,
        autocorrect: false,
        enableSuggestions: false,
        enableIMEPersonalizedLearning: false,
        textCapitalization: TextCapitalization.none,
        smartDashesType: SmartDashesType.disabled,
        smartQuotesType: SmartQuotesType.disabled,
        spellCheckConfiguration: const SpellCheckConfiguration.disabled(),
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontFamily: 'monospace'),
        decoration: InputDecoration(
          hintText: s.sql_editor_hint,
          semanticCounterText: '',
          border: const OutlineInputBorder(),
          labelText: s.sql_editor_field_label,
          floatingLabelBehavior: FloatingLabelBehavior.never,
          alignLabelWithHint: true,
        ),
      ),
    );
  }
}
