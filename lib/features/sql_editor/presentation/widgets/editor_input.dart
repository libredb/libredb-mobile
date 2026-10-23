import 'package:flutter/material.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/shared/design_system/tokens/app_spacing.dart';

/// The statement the user types: a plain multi-line monospace field that fills its space, with every input aid that
/// would change the text turned off, since a smart quote or a corrected word breaks a statement.
class EditorInput extends StatelessWidget {
  const EditorInput({super.key, required this.controller, required this.focusNode});

  final TextEditingController controller;
  final FocusNode focusNode;

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
