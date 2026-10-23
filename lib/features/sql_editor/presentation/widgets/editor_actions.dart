import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:libredb_mobile/features/sql_editor/application/editor_run_bloc.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/shared/design_system/tokens/app_spacing.dart';
import 'package:libredb_mobile/shared/widgets/offline_status.dart';

/// Run, under the text: an action that needs Studio, so it is disabled offline with the reason; disabled while the
/// text is empty, while a run is in flight or waits for its confirmation, and while a rate limit's delay runs.
class EditorActions extends StatelessWidget {
  const EditorActions({super.key, required this.text, required this.onRun});

  final TextEditingController text;
  final VoidCallback onRun;

  static const runKey = ValueKey('sql-editor-run');

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final state = context.watch<EditorRunBloc>().state;
    final running = state is EditorRunning;
    final busy = switch (state) {
      EditorRunning() || EditorAwaitingConfirmation() || EditorFailed(waitingForRetry: true) => true,
      EditorIdle() || EditorSucceeded() || EditorStatementFailed() || EditorFailed() => false,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
      child: Align(
        alignment: AlignmentDirectional.centerEnd,
        child: OnlineOnlyAction(
          builder: (context, online) => ValueListenableBuilder<TextEditingValue>(
            valueListenable: text,
            builder: (context, value, _) => FilledButton.icon(
              key: runKey,
              onPressed: online && !busy && value.text.trim().isNotEmpty ? onRun : null,
              icon: running
                  ? SizedBox.square(
                      dimension: MediaQuery.textScalerOf(context).scale(16),
                      child: const CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.play_arrow),
              label: Text(running ? s.sql_editor_running : s.sql_editor_run),
            ),
          ),
        ),
      ),
    );
  }
}
