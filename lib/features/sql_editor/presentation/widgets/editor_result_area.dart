import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:libredb_mobile/features/sql_editor/application/editor_run_bloc.dart';
import 'package:libredb_mobile/features/sql_editor/presentation/widgets/script_result_view.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/shared/design_system/tokens/app_spacing.dart';
import 'package:libredb_mobile/shared/widgets/browse_database_words.dart';
import 'package:libredb_mobile/shared/widgets/offline_status.dart';
import 'package:libredb_mobile/shared/widgets/result_view/result_view.dart';
import 'package:libredb_mobile/shared/widgets/result_view/result_view_bloc.dart';
import 'package:libredb_mobile/shared/widgets/studio_error_banner.dart';

/// What the last run answered, under the editor: its masked result in the result view, a script's statements in
/// [ScriptResultView], the database's own words of a refused statement (on screen only), or the failure in
/// `StudioErrorBanner`, which offers no retry, since Run is the only way to send again. While a confirmation is open,
/// what was on screen before stays. While a script runs, its elapsed time shows under the progress, since a script
/// waits without a timeout. A cancelled run says what the cancel did, as a notice; a failed cancel shows its failure
/// above the run's progress. A run the app's switch to the background interrupted says so: a read with Run again,
/// anything else that its outcome is unknown, with no Run again, so the user checks the data before running it. A page
/// of Load more refused with `studio.connection_not_available` calls [onConnectionUnavailable], the editor's one way
/// to the active connection's vanish flow.
class EditorResultArea extends StatelessWidget {
  const EditorResultArea({
    super.key,
    required this.confirm,
    required this.onRunAgain,
    required this.onConnectionUnavailable,
  });

  static const runAgainKey = ValueKey('sql_editor_run_again');

  /// Asks the user to confirm a page of a flagged statement, as the page asks before the first run.
  final Future<bool> Function(EditorStatement statement) confirm;

  /// Run again of an interrupted read: the editor's Run, so the text goes through the write check again.
  final VoidCallback onRunAgain;

  /// A page of Load more was refused with `studio.connection_not_available`.
  final VoidCallback onConnectionUnavailable;

  @override
  Widget build(BuildContext context) => BlocBuilder<EditorRunBloc, EditorRunState>(
    builder: (context, state) => _of(context, switch (state) {
      EditorAwaitingConfirmation(:final previous) => previous,
      _ => state,
    }),
  );

  Widget _of(BuildContext context, EditorRunState state) => switch (state) {
    EditorIdle() || EditorAwaitingConfirmation() => const SizedBox.shrink(),
    EditorRunning(:final cancelFailure?) => _running(context, cancelFailure: cancelFailure),
    EditorRunning() || EditorCancelling() => _progress(context),
    EditorCancelled(:final outcome) => _cancelled(context, outcome),
    EditorInterrupted(:final wasRead) => _interrupted(context, wasRead: wasRead),
    EditorSucceeded() => _result(context, state),
    EditorScriptAnswered() => ScriptResultView(key: ValueKey(state.run), answer: state),
    EditorStatementFailed(:final error) => SingleChildScrollView(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.sm),
            child: StudioErrorBanner(error: error),
          ),
          if (browseDatabaseWordsOf(error) case final words?) BrowseDatabaseWords(words),
        ],
      ),
    ),
    EditorFailed(:final error) => SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: StudioErrorBanner(
        error: error,
        onRetryAvailable: () => context.read<EditorRunBloc>().add(const EditorRateLimitElapsed()),
      ),
    ),
  };

  /// The run goes on after a failed cancel: the failure, a rate limit's countdown included, above the progress.
  Widget _running(BuildContext context, {required AppError cancelFailure}) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: StudioErrorBanner(
          error: cancelFailure,
          onRetryAvailable: () => context.read<EditorRunBloc>().add(const EditorRateLimitElapsed()),
        ),
      ),
      Expanded(child: _progress(context)),
    ],
  );

  /// The progress of the run in flight, with a script's elapsed time under it.
  Widget _progress(BuildContext context) {
    final since = context.read<EditorRunBloc>().scriptStartedAt;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: AppSpacing.md,
        children: [
          const CircularProgressIndicator(),
          if (since != null) ScriptElapsedTime(since: since),
        ],
      ),
    );
  }

  /// What a cancel did, as a notice and never as an error.
  Widget _cancelled(BuildContext context, EditorCancelOutcome outcome) {
    final s = S.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(switch (outcome) {
              EditorCancelOutcome.confirmed => s.sql_editor_cancelled,
              EditorCancelOutcome.notConfirmed => s.sql_editor_cancel_not_confirmed,
              EditorCancelOutcome.stoppedWaiting => s.sql_editor_stopped_waiting,
            }),
          ),
        ],
      ),
    );
  }

  /// What a switch to the background did to the run, as a notice; Run again only for a read.
  Widget _interrupted(BuildContext context, {required bool wasRead}) {
    final s = S.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(wasRead ? Icons.info_outline : Icons.warning_amber_outlined),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text(wasRead ? s.sql_editor_interrupted_read : s.sql_editor_interrupted_unknown)),
            ],
          ),
          if (wasRead)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: OnlineOnlyAction(
                builder: (context, online) => OutlinedButton.icon(
                  key: runAgainKey,
                  onPressed: online ? onRunAgain : null,
                  icon: const Icon(Icons.replay),
                  label: Text(s.sql_editor_run_again),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _result(BuildContext context, EditorSucceeded state) => BlocProvider(
    // Each run is a result of its own, masked with the policy of its own run.
    key: ValueKey(state.run),
    create: (_) {
      final run = context.read<EditorRunBloc>();
      return ResultViewBloc(
        masked: state.masked,
        policy: state.policy,
        loadPage: (page) => run.loadPage(state.statement, page, confirm: () => confirm(state.statement)),
        supportsResultPagination: state.supportsResultPagination,
      );
    },
    child: ResultView(
      rolledBackNotice: S.of(context).sql_editor_rolled_back(state.commitKeyword),
      onConnectionUnavailable: onConnectionUnavailable,
    ),
  );
}
