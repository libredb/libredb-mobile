import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:libredb_mobile/features/sql_editor/application/editor_run_bloc.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/shared/design_system/tokens/app_spacing.dart';
import 'package:libredb_mobile/shared/widgets/browse_database_words.dart';
import 'package:libredb_mobile/shared/widgets/result_view/result_view.dart';
import 'package:libredb_mobile/shared/widgets/result_view/result_view_bloc.dart';
import 'package:libredb_mobile/shared/widgets/studio_error_banner.dart';

/// What the last run answered, under the editor: its masked result in the result view, the database's own words of a
/// refused statement (on screen only), or the failure in `StudioErrorBanner`, which offers no retry, since Run is the
/// only way to send again. While a confirmation is open, what was on screen before stays. A cancelled run says what
/// the cancel did, as a notice; a failed cancel shows its failure above the run's progress.
class EditorResultArea extends StatelessWidget {
  const EditorResultArea({super.key, required this.confirm});

  /// Asks the user to confirm a page of a flagged statement, as the page asks before the first run.
  final Future<bool> Function(EditorStatement statement) confirm;

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
    EditorRunning() || EditorCancelling() => const Center(child: CircularProgressIndicator()),
    EditorCancelled(:final outcome) => _cancelled(context, outcome),
    EditorSucceeded() => _result(context, state),
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
      const Expanded(child: Center(child: CircularProgressIndicator())),
    ],
  );

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
    child: ResultView(rolledBackNotice: S.of(context).sql_editor_rolled_back(state.commitKeyword)),
  );
}
