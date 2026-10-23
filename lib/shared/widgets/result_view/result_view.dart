import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/shared/design_system/tokens/app_spacing.dart';
import 'package:libredb_mobile/shared/models/query_result.dart';
import 'package:libredb_mobile/shared/widgets/result_view/result_card.dart';
import 'package:libredb_mobile/shared/widgets/result_view/result_notices.dart';
import 'package:libredb_mobile/shared/widgets/result_view/result_view_bloc.dart';
import 'package:libredb_mobile/shared/widgets/result_view/row_detail_sheet.dart';

/// The result of the [ResultViewBloc] above it: the stats strip over a card per row, or an empty state.
///
/// It shows no error: a failed run is its caller's, shown with `StudioErrorBanner`. A tap on a card opens the row's
/// detail sheet, and a long press on a card's field its copy menu.
class ResultView extends StatelessWidget {
  const ResultView({super.key});

  /// The share of the view's height the stats strip takes at most; a taller strip scrolls.
  static const maxNoticeShare = 0.4;

  @override
  Widget build(BuildContext context) => BlocBuilder<ResultViewBloc, ResultViewState>(
    builder: (context, state) => switch (state) {
      ResultViewLoaded(:final result) when result.rows.isEmpty => ResultEmptyView(result: result),
      ResultViewLoaded(:final result, :final maskedColumns) => LayoutBuilder(
        builder: (context, constraints) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ResultStatsStrip(
              result: result,
              maxHeight: constraints.hasBoundedHeight ? constraints.maxHeight * maxNoticeShare : double.infinity,
            ),
            const Divider(height: 1),
            Expanded(
              child: ResultCardList(
                fields: result.fields,
                rows: result.rows,
                maskedColumns: maskedColumns,
                vectorColumns: result.vectorColumns,
                onRowTap: (index) =>
                    showRowDetailSheet(context, result: result, maskedColumns: maskedColumns, index: index),
                onFieldLongPress: (index, field) =>
                    showRowCopyMenu(context, result: result, maskedColumns: maskedColumns, index: index, field: field),
              ),
            ),
          ],
        ),
      ),
    },
  );
}

/// A result without rows (Studio's empty grid, `ResultsGrid.tsx:1323-1335`): the rows a write affected, the line for a
/// result Studio bounded before its first row, or no data; the warnings shown outright, since no strip is drawn; and
/// the rollback banner.
class ResultEmptyView extends StatelessWidget {
  const ResultEmptyView({super.key, required this.result});

  final QueryResult result;

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
            if (result.openTransactionRolledBack) const ResultRolledBackBanner(),
          ],
        ),
      ),
    );
  }
}
