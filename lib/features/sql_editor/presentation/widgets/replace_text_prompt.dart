import 'package:flutter/material.dart';
import 'package:libredb_mobile/generated/l10n.dart';

/// Whether [incoming] may take the place of [current], the editor's text: at once when the editor holds nothing but
/// white space or the same text, and otherwise only after the user confirms the replace. Nothing runs either way.
///
/// The History sheet's tap uses it, and the editor's open request reuses it for a statement from elsewhere.
Future<bool> confirmReplaceEditorText(BuildContext context, {required String current, required String incoming}) async {
  if (current.trim().isEmpty || current == incoming) return true;
  final s = S.of(context);
  final answer = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(s.sql_history_replace_title),
      content: Text(s.sql_history_replace_message),
      actions: [
        TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: Text(s.cancel)),
        FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: Text(s.sql_history_replace)),
      ],
    ),
  );
  return answer ?? false;
}
