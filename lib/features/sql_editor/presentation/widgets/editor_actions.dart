import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:libredb_mobile/features/sql_editor/application/editor_run_bloc.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/shared/design_system/tokens/app_spacing.dart';
import 'package:libredb_mobile/shared/widgets/offline_status.dart';

/// Run, under the text: an action that needs Studio, so it is disabled offline with the reason; disabled while the
/// text is empty, while a run waits for its confirmation, and while a rate limit's delay runs.
///
/// While a statement runs, Run becomes Cancel, or Stop waiting on an engine that cannot cancel; it reads Cancelling
/// and is disabled while Studio is asked, and stays disabled while a rate limit on the cancel counts down. After a
/// cancel that failed otherwise, Stop waiting stands beside Cancel and drops the request without posting again.
class EditorActions extends StatelessWidget {
  const EditorActions({
    super.key,
    required this.text,
    required this.onRun,
    required this.onCancel,
    required this.onStopWaiting,
  });

  final TextEditingController text;
  final VoidCallback onRun;
  final VoidCallback onCancel;
  final VoidCallback onStopWaiting;

  static const runKey = ValueKey('sql-editor-run');
  static const stopWaitingKey = ValueKey('sql-editor-stop-waiting');

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final state = context.watch<EditorRunBloc>().state;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
      child: Align(
        alignment: AlignmentDirectional.centerEnd,
        child: switch (state) {
          EditorRunning(:final supportsCancel, :final waitingForRetry, :final cancelFailure) => Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            alignment: WrapAlignment.end,
            children: [
              // A cancel that failed, other than a rate limit, can leave the user waiting on a run Studio may never
              // stop, so the request can also be dropped without posting another cancel.
              if (cancelFailure != null && cancelFailure is! RateLimitedError)
                OutlinedButton(key: stopWaitingKey, onPressed: onStopWaiting, child: Text(s.sql_editor_stop_waiting)),
              FilledButton.tonalIcon(
                key: runKey,
                onPressed: waitingForRetry ? null : onCancel,
                icon: const Icon(Icons.stop),
                label: Text(supportsCancel ? s.sql_editor_cancel : s.sql_editor_stop_waiting),
              ),
            ],
          ),
          EditorCancelling() => FilledButton.tonalIcon(
            key: runKey,
            onPressed: null,
            icon: SizedBox.square(
              dimension: MediaQuery.textScalerOf(context).scale(16),
              child: const CircularProgressIndicator(strokeWidth: 2),
            ),
            label: Text(s.sql_editor_cancelling),
          ),
          EditorAwaitingConfirmation() || EditorFailed(waitingForRetry: true) => _run(busy: true),
          EditorIdle() ||
          EditorSucceeded() ||
          EditorStatementFailed() ||
          EditorFailed() ||
          EditorCancelled() => _run(busy: false),
        },
      ),
    );
  }

  Widget _run({required bool busy}) {
    return OnlineOnlyAction(
      builder: (context, online) => ValueListenableBuilder<TextEditingValue>(
        valueListenable: text,
        builder: (context, value, _) => FilledButton.icon(
          key: runKey,
          onPressed: online && !busy && value.text.trim().isNotEmpty ? onRun : null,
          icon: const Icon(Icons.play_arrow),
          label: Text(S.of(context).sql_editor_run),
        ),
      ),
    );
  }
}
