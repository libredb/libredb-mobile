import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/features/sql_editor/application/editor_draft_bloc.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/shared/design_system/tokens/app_spacing.dart';
import 'package:libredb_mobile/shared/l10n/app_error_code_l10n.dart';

/// What the editor says about its saved draft, under the field: that a text over the bound is not kept, that the
/// device refused a save, that the saved draft cannot be read (with Discard behind a confirmation), or that reading it
/// failed (with Retry). Nothing while the draft is kept.
class EditorDraftNotice extends StatelessWidget {
  const EditorDraftNotice({super.key});

  static const discardKey = ValueKey('sql-editor-draft-discard');
  static const retryKey = ValueKey('sql-editor-draft-retry');

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return BlocBuilder<EditorDraftBloc, EditorDraftState>(
      builder: (context, state) => switch (state) {
        EditorDraftOff() ||
        EditorDraftLoading() ||
        EditorDraftRestored() ||
        EditorDraftKept() => const SizedBox.shrink(),
        EditorDraftNotKept() => _line(context, Icons.info_outline, s.sql_editor_draft_not_kept),
        EditorDraftSaveFailed(:final errorCode) => _line(
          context,
          Icons.error_outline,
          s.sql_editor_draft_not_saved(errorCode.resolve(context)),
          error: true,
        ),
        EditorDraftUnreadable(:final discardFailure) => _line(
          context,
          Icons.error_outline,
          '${AppErrorCode.editorSavedTextUnreadable.resolve(context)} ${s.sql_editor_draft_unreadable_note}',
          error: true,
          detail: discardFailure?.resolve(context),
          action: TextButton(
            key: discardKey,
            onPressed: () => _discard(context),
            child: Text(s.editor_saved_text_discard),
          ),
        ),
        EditorDraftReadFailed(:final errorCode) => _line(
          context,
          Icons.error_outline,
          s.sql_editor_draft_read_failed(errorCode.resolve(context)),
          error: true,
          action: TextButton(
            key: retryKey,
            onPressed: () => context.read<EditorDraftBloc>().add(const EditorDraftRetryRequested()),
            child: Text(s.retry),
          ),
        ),
      },
    );
  }

  Widget _line(BuildContext context, IconData icon, String text, {bool error = false, String? detail, Widget? action}) {
    final scheme = Theme.of(context).colorScheme;
    final color = error ? scheme.error : scheme.onSurfaceVariant;
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(color: color);
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: MediaQuery.textScalerOf(context).scale(16), color: color),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(text, style: style),
                if (detail != null) Text(detail, style: style),
              ],
            ),
          ),
          ?action,
        ],
      ),
    );
  }

  Future<void> _discard(BuildContext context) async {
    final s = S.of(context);
    final bloc = context.read<EditorDraftBloc>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(s.editor_saved_text_discard_title),
        content: Text(s.editor_saved_text_discard_message),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: Text(s.cancel)),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(s.editor_saved_text_discard),
          ),
        ],
      ),
    );
    if (confirmed ?? false) bloc.add(const EditorDraftDiscardRequested());
  }
}
