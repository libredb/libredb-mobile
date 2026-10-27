import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:libredb_mobile/core/security/screen_capture_guard.dart';
import 'package:libredb_mobile/features/sql_editor/application/editor_run_bloc.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/shared/design_system/tokens/app_radius.dart';
import 'package:libredb_mobile/shared/design_system/tokens/app_spacing.dart';
import 'package:libredb_mobile/shared/widgets/result_view/result_notices.dart';
import 'package:libredb_mobile/shared/widgets/result_view/result_view.dart';
import 'package:libredb_mobile/shared/widgets/result_view/result_view_bloc.dart';
import 'package:libredb_mobile/shared/design_system/tokens/app_typography.dart';

/// The answer of a script: the rolled-back notice when Studio ended a transaction the script left open, a card per
/// statement Studio ran, one line for the statements it did not run, and under them the rows of one statement in
/// [ResultView], masked with the run's policy and with no Load more, since Studio answers no paging for a script.
///
/// The last statement with rows opens first, as Studio's web shows it; a tap on another successful card opens its
/// rows the same way. A failed card shows the database's own words, on screen only. The notice keeps the advice to add
/// the commit keyword only when every statement succeeded: after a failure nothing complete is left to keep.
///
/// The whole view keeps out of screen captures while on screen ([ScreenCaptureGuard]): with no rows open, the cards
/// still show each statement's start and the database's words, which can repeat a value.
class ScriptResultView extends StatefulWidget {
  const ScriptResultView({super.key, required this.answer});

  final EditorScriptAnswered answer;

  static const notRunKey = ValueKey('script-not-run');

  /// The key of the card of the statement at [index].
  static ValueKey<String> cardKey(int index) => ValueKey('script-statement-$index');

  /// The share of the view's height the cards take at most while a statement's rows are open.
  static const maxCardsShare = 0.4;

  @override
  State<ScriptResultView> createState() => _ScriptResultViewState();
}

class _ScriptResultViewState extends State<ScriptResultView> {
  /// The position in the answer's statements of the one whose rows are open, null when none is.
  late int? _open = _lastWithRows();

  int? _lastWithRows() {
    final statements = widget.answer.statements;
    for (var i = statements.length - 1; i >= 0; i--) {
      if (statements[i].masked?.result.rows.isNotEmpty ?? false) return i;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) => ScreenCaptureGuard(child: _view(context));

  Widget _view(BuildContext context) {
    final s = S.of(context);
    final answer = widget.answer;
    final open = _open;
    final cards = ListView(
      shrinkWrap: open != null,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
      children: [
        if (answer.openTransactionRolledBack)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: ResultRolledBackBanner(
              notice: answer.hasError
                  ? s.sql_editor_script_rolled_back
                  : s.sql_editor_script_rolled_back_keep(answer.commitKeyword),
            ),
          ),
        for (final (position, statement) in answer.statements.indexed)
          _StatementCard(
            key: ScriptResultView.cardKey(statement.index),
            statement: statement,
            open: position == open,
            onTap: statement.masked == null || position == open ? null : () => setState(() => _open = position),
          ),
        if (answer.notRun > 0)
          Padding(
            key: ScriptResultView.notRunKey,
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Row(
              spacing: AppSpacing.sm,
              children: [
                const Icon(Icons.block),
                Expanded(child: Text(s.sql_editor_script_not_run(answer.notRun))),
              ],
            ),
          ),
      ],
    );
    if (open == null) return cards;
    final masked = answer.statements[open].masked!;
    return LayoutBuilder(
      builder: (context, constraints) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: constraints.hasBoundedHeight
                  ? constraints.maxHeight * ScriptResultView.maxCardsShare
                  : double.infinity,
            ),
            child: cards,
          ),
          const Divider(height: 1),
          Expanded(
            child: BlocProvider(
              // Each statement's rows are a result of their own.
              key: ValueKey((answer.run, open)),
              create: (_) => ResultViewBloc(masked: masked, policy: answer.policy),
              child: const ResultView(),
            ),
          ),
        ],
      ),
    );
  }
}

/// One statement of the script: its number, the start of its text, success or failure, and its row count and time,
/// or for a failure its time and the database's own words.
class _StatementCard extends StatelessWidget {
  const _StatementCard({super.key, required this.statement, required this.open, this.onTap});

  final EditorScriptStatement statement;
  final bool open;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final number = resultNumberFormat(context);
    final time = number.format(statement.executionTime.inMicroseconds / Duration.microsecondsPerMillisecond);
    final failed = statement.failed;
    final rowCount = statement.rowCount ?? 0;
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        side: BorderSide(color: open ? scheme.primary : scheme.outline, width: open ? 2 : 1),
      ),
      elevation: 0,
      child: Semantics(
        selected: open,
        onTapHint: onTap == null ? null : s.sql_editor_script_show_rows,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: AppSpacing.xs,
              children: [
                Row(
                  spacing: AppSpacing.sm,
                  children: [
                    Icon(
                      failed ? Icons.error_outline : Icons.check_circle_outline,
                      color: failed ? scheme.error : scheme.primary,
                      size: MediaQuery.textScalerOf(context).scale(18),
                    ),
                    Expanded(
                      child: Text(
                        s.sql_editor_script_statement(statement.index + 1),
                        style: theme.textTheme.titleSmall,
                      ),
                    ),
                    Text(
                      failed ? s.sql_editor_script_failed : s.sql_editor_script_succeeded,
                      style: theme.textTheme.labelMedium?.copyWith(color: failed ? scheme.error : scheme.primary),
                    ),
                  ],
                ),
                Text(
                  _start(statement.sql),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(fontFamily: AppTypography.mono),
                ),
                Text(
                  failed
                      ? s.sql_editor_script_failed_time(time)
                      : s.result_stats(rowCount, number.format(rowCount), time),
                  style: theme.textTheme.labelSmall,
                ),
                if (statement.error case final error?)
                  SelectableText(error, style: theme.textTheme.bodySmall?.copyWith(color: scheme.error)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The start of [sql] on one line, its runs of white space as one space.
  static String _start(String sql) => sql.replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// How long the script sent at [since] has run, in minutes and seconds, counted again each second.
class ScriptElapsedTime extends StatefulWidget {
  const ScriptElapsedTime({super.key, required this.since});

  final DateTime since;

  static const textKey = ValueKey('script-elapsed');

  @override
  State<ScriptElapsedTime> createState() => _ScriptElapsedTimeState();
}

class _ScriptElapsedTimeState extends State<ScriptElapsedTime> {
  late final Timer _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _tick.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final elapsed = clock.now().difference(widget.since);
    final seconds = elapsed.isNegative ? 0 : elapsed.inSeconds;
    final text = '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
    return Text(S.of(context).sql_editor_script_elapsed(text), key: ScriptElapsedTime.textKey);
  }
}
