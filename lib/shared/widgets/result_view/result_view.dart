import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/core/security/screen_capture_guard.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/shared/design_system/tokens/app_breakpoints.dart';
import 'package:libredb_mobile/shared/design_system/tokens/app_spacing.dart';
import 'package:libredb_mobile/shared/models/query_result.dart';
import 'package:libredb_mobile/shared/widgets/result_view/result_card.dart';
import 'package:libredb_mobile/shared/widgets/result_view/result_notices.dart';
import 'package:libredb_mobile/shared/widgets/offline_status.dart';
import 'package:libredb_mobile/shared/widgets/result_view/result_table.dart';
import 'package:libredb_mobile/shared/widgets/result_view/result_view_bloc.dart';
import 'package:libredb_mobile/shared/widgets/result_view/result_view_mode_cubit.dart';
import 'package:libredb_mobile/shared/widgets/result_view/result_view_mode_store.dart';
import 'package:libredb_mobile/shared/widgets/result_view/row_detail_sheet.dart';
import 'package:libredb_mobile/shared/widgets/studio_error_banner.dart';

/// The result of the [ResultViewBloc] above it: the stats strip over a card per row or a table, as the
/// [ResultViewModeCubit] above it says, or an empty state; under the rows, Load more when the bloc offers a page.
///
/// It shows no error of the run itself: a failed run is its caller's, shown with `StudioErrorBanner`. A failed page
/// keeps the rows, with the banner and a retry the user taps. A tap on a card opens the row's detail sheet, and a long
/// press on a card's field its copy menu.
///
/// Nothing in it reloads on a size change: the rows and the view mode live in blocs above it, so rotating the phone
/// keeps them and the scroll position.
///
/// [rolledBackNotice] words the notice that Studio rolled back a transaction the statement left open, when the caller
/// has more to say than the plain sentence, as the SQL editor names the engine's commit keyword.
///
/// [onConnectionUnavailable] is called once for each page Studio refuses with `studio.connection_not_available`, so the
/// caller hands its connection to the active connection's vanish flow.
///
/// While on screen it keeps out of screenshots, screen recordings and the recent-apps preview ([ScreenCaptureGuard]),
/// an empty result too, which can still name what the statement did.
class ResultView extends StatelessWidget {
  const ResultView({super.key, this.rolledBackNotice, this.onConnectionUnavailable});

  final String? rolledBackNotice;
  final VoidCallback? onConnectionUnavailable;

  /// The share of the view's height the stats strip takes at most, and the footer too; a taller one scrolls.
  static const maxNoticeShare = 0.4;

  @override
  Widget build(BuildContext context) => BlocListener<ResultViewBloc, ResultViewState>(
    listenWhen: (previous, current) =>
        current is ResultViewLoadMoreFailed &&
        current != previous &&
        current.error.code == AppErrorCode.studioConnectionNotAvailable.key,
    listener: (context, state) => onConnectionUnavailable?.call(),
    child: ScreenCaptureGuard(child: _view()),
  );

  Widget _view() => BlocBuilder<ResultViewBloc, ResultViewState>(
    builder: (context, state) {
      final result = state.result;
      if (result.rows.isEmpty) return ResultEmptyView(result: result, rolledBackNotice: rolledBackNotice);
      final bloc = context.read<ResultViewBloc>();
      final pageSize = bloc.pageOffer(result);
      // On a compact height, such as a phone held sideways, Load more shares the strip's row so the rows keep the
      // height; a failed page keeps its banner under the rows, where it has the room to say why.
      final besideToggle =
          pageSize != null &&
          state is! ResultViewLoadMoreFailed &&
          AppBreakpoints.isCompactHeight(MediaQuery.sizeOf(context).height);
      return LayoutBuilder(
        builder: (context, constraints) {
          final maxHeight = constraints.hasBoundedHeight ? constraints.maxHeight * maxNoticeShare : double.infinity;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ResultStatsStrip(
                result: result,
                maxHeight: maxHeight,
                orderNotice: bloc.showsOrderNotice(result),
                trailing: besideToggle
                    ? Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.xs,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          const ResultViewModeToggle(),
                          KeyedSubtree(
                            key: const ValueKey('result-load-more'),
                            child: ResultLoadMoreFooter.actionOf(context, state, pageSize),
                          ),
                        ],
                      )
                    : const ResultViewModeToggle(),
                rolledBackNotice: rolledBackNotice,
              ),
              const Divider(height: 1),
              Expanded(
                child: BlocBuilder<ResultViewModeCubit, ResultViewMode>(
                  builder: (context, mode) => switch (mode) {
                    ResultViewMode.cards => ResultCardList(
                      fields: result.fields,
                      rows: result.rows,
                      maskedColumns: state.maskedColumns,
                      vectorColumns: result.vectorColumns,
                      onRowTap: (index) =>
                          showRowDetailSheet(context, result: result, maskedColumns: state.maskedColumns, index: index),
                      onFieldLongPress: (index, field) => showRowCopyMenu(
                        context,
                        result: result,
                        maskedColumns: state.maskedColumns,
                        index: index,
                        field: field,
                      ),
                    ),
                    ResultViewMode.table => ResultTable(result: result, maskedColumns: state.maskedColumns),
                  },
                ),
              ),
              if (pageSize != null && !besideToggle) ...[
                const Divider(height: 1),
                ResultLoadMoreFooter(state: state, pageSize: pageSize, maxHeight: maxHeight),
              ],
            ],
          );
        },
      );
    },
  );
}

/// The card and table toggle, which the [ResultViewModeCubit] above it stores for the device.
class ResultViewModeToggle extends StatelessWidget {
  const ResultViewModeToggle({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final size = MediaQuery.textScalerOf(context).scale(18);
    return BlocBuilder<ResultViewModeCubit, ResultViewMode>(
      builder: (context, mode) => SegmentedButton<ResultViewMode>(
        key: const ValueKey('result-view-mode'),
        showSelectedIcon: false,
        style: const ButtonStyle(visualDensity: VisualDensity.compact),
        segments: [
          ButtonSegment(
            value: ResultViewMode.cards,
            icon: Icon(Icons.view_agenda_outlined, size: size),
            tooltip: s.result_view_cards,
          ),
          ButtonSegment(
            value: ResultViewMode.table,
            icon: Icon(Icons.table_chart_outlined, size: size),
            tooltip: s.result_view_table,
          ),
        ],
        selected: {mode},
        onSelectionChanged: (selected) => context.read<ResultViewModeCubit>().select(selected.single),
      ),
    );
  }
}

/// Load more under the rows, naming the [pageSize] it fetches, as Studio's `load 500 more`: an action that needs
/// Studio, so it is disabled offline with the reason; disabled while the page is in flight; and, for a failed page,
/// `StudioErrorBanner` with a retry the user taps, except for a page whose outcome is unknown, which the SQL editor
/// answers for a page of a text that may write dropped in the background (#150): it offers no retry, so the user checks
/// the data first. Taller than [maxHeight], it scrolls.
class ResultLoadMoreFooter extends StatelessWidget {
  const ResultLoadMoreFooter({
    super.key,
    required this.state,
    required this.pageSize,
    this.maxHeight = double.infinity,
  });

  final ResultViewState state;
  final int pageSize;
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: SingleChildScrollView(
        child: Padding(
          key: const ValueKey('result-load-more'),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
          child: Center(child: actionOf(context, state, pageSize)),
        ),
      ),
    );
  }

  /// The button or the banner the footer shows for [state], which the stats strip also shows on a compact height.
  static Widget actionOf(BuildContext context, ResultViewState state, int pageSize) {
    final s = S.of(context);
    final size = resultNumberFormat(context).format(pageSize);
    void loadMore() => context.read<ResultViewBloc>().add(const ResultViewLoadMoreRequested());
    return switch (state) {
      ResultViewLoadMoreFailed(:final error)
          when error is InterruptedError && error.code == AppErrorCode.editorPageOutcomeUnknown.key =>
        StudioErrorBanner(error: error),
      ResultViewLoadMoreFailed(:final error) => OnlineOnlyAction(
        builder: (context, enabled) => StudioErrorBanner(error: error, onRetry: enabled ? loadMore : null),
      ),
      ResultViewLoaded(loadingMore: true) => FilledButton.tonalIcon(
        onPressed: null,
        icon: SizedBox.square(
          dimension: MediaQuery.textScalerOf(context).scale(16),
          child: const CircularProgressIndicator(strokeWidth: 2),
        ),
        label: Text(s.result_loading_more(pageSize, size)),
      ),
      ResultViewLoaded() => OnlineOnlyAction(
        builder: (context, enabled) =>
            FilledButton.tonal(onPressed: enabled ? loadMore : null, child: Text(s.result_load_more(pageSize, size))),
      ),
    };
  }
}

/// A result without rows (Studio's empty grid, `ResultsGrid.tsx:1323-1335`): the rows a write affected, the line for a
/// result Studio bounded before its first row, or no data; the warnings shown outright, since no strip is drawn; and
/// the rollback banner, worded by [rolledBackNotice] when given.
class ResultEmptyView extends StatelessWidget {
  const ResultEmptyView({super.key, required this.result, this.rolledBackNotice});

  final QueryResult result;

  final String? rolledBackNotice;

  /// The rows a write affected: a result with no fields, no rows and a positive count (`affectedRowsLabel`,
  /// `ResultsGrid.tsx:80-84`). A zero count stays no data, since an engine that reports none and a write that matched
  /// nothing look alike.
  static bool isWrite(QueryResult result) => result.fields.isEmpty && result.rows.isEmpty && result.rowCount > 0;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final headline = isWrite(result)
        ? s.result_affected_rows(result.rowCount, resultNumberFormat(context).format(result.rowCount))
        : result.pagination?.wasLimited == true
        ? s.result_empty_bounded
        : s.result_empty;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: AppSpacing.md,
          children: [
            ExcludeSemantics(
              child: Text('∅', style: theme.textTheme.headlineMedium?.copyWith(color: theme.colorScheme.outline)),
            ),
            Text(headline, style: theme.textTheme.bodyMedium, textAlign: TextAlign.center),
            if (result.warnings.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: AppSpacing.xs,
                children: [
                  Text(s.result_engine_reported, style: theme.textTheme.labelMedium),
                  ResultWarningList(warnings: result.warnings),
                ],
              ),
            if (result.openTransactionRolledBack) ResultRolledBackBanner(notice: rolledBackNotice),
          ],
        ),
      ),
    );
  }
}
