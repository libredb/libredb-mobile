import 'package:flutter/material.dart';
import 'package:libredb_mobile/core/testing/app_key_constants.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/shared/design_system/tokens/app_spacing.dart';

/// Asks the user to confirm 'Remove my data', listing what leaves this phone and what stays.
class RemoveMyDataDialog extends StatelessWidget {
  const RemoveMyDataDialog({super.key});

  /// Opens the dialog and answers true when the user confirmed.
  static Future<bool> show(BuildContext context) async =>
      await showDialog<bool>(context: context, builder: (_) => const RemoveMyDataDialog()) ?? false;

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context);
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    Widget heading(String text) => Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md, bottom: AppSpacing.xs),
      child: Text(text, style: textTheme.titleSmall),
    );
    Widget item(String text) => Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('•  ', style: textTheme.bodyMedium),
          Expanded(child: Text(text, style: textTheme.bodyMedium)),
        ],
      ),
    );
    return AlertDialog(
      title: Text(l10n.remove_my_data_title),
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          heading(l10n.remove_my_data_removed),
          item(l10n.remove_my_data_drafts),
          item(l10n.remove_my_data_history),
          item(l10n.remove_my_data_favorites),
          item(l10n.remove_my_data_recents),
          item(l10n.remove_my_data_last_connection),
          item(l10n.remove_my_data_collapsed_sections),
          heading(l10n.remove_my_data_kept),
          item(l10n.remove_my_data_kept_preferences),
          const SizedBox(height: AppSpacing.md),
          Text(l10n.remove_my_data_signs_out, style: textTheme.bodyMedium),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l10n.cancel)),
        FilledButton(
          key: removeMyDataConfirmKey,
          style: FilledButton.styleFrom(backgroundColor: scheme.error, foregroundColor: scheme.onError),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.remove_my_data_confirm),
        ),
      ],
    );
  }
}
