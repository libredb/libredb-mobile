import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/shared/design_system/tokens/app_radius.dart';
import 'package:libredb_mobile/shared/design_system/tokens/app_spacing.dart';
import 'package:libredb_mobile/shared/models/query_result.dart';

/// Formats a count in the locale's grouping: 1,207 in English, 1.207 in Turkish.
NumberFormat resultNumberFormat(BuildContext context) =>
    NumberFormat.decimalPattern(Localizations.localeOf(context).toString());

/// The engine's warnings, one per line, each as Studio's `describeWarning` writes it (the severity, then the message,
/// or `Warning` without one) with the code under it. Studio's text is shown as Studio wrote it.
class ResultWarningList extends StatelessWidget {
  const ResultWarningList({super.key, required this.warnings});

  final List<QueryWarning> warnings;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final style = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error);
    final codeStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      fontFamily: 'monospace',
    );
    return Column(
      key: const ValueKey('result-warnings'),
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: AppSpacing.xs,
      children: [
        for (final warning in warnings)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_line(s, warning), style: style),
              if (warning.code case final code?) Text(s.result_warning_code(code), style: codeStyle),
            ],
          ),
      ],
    );
  }

  static String _line(S s, QueryWarning warning) {
    final message = warning.message.isEmpty ? s.result_warning_fallback : warning.message;
    final severity = warning.severity;
    return severity == null || severity.isEmpty ? message : s.result_warning_line(severity, message);
  }
}

/// Studio rolled back a transaction the statement left open, so its changes were discarded: [notice] when the caller
/// words it, such as the SQL editor's with the engine's commit keyword, else the plain sentence.
class ResultRolledBackBanner extends StatelessWidget {
  const ResultRolledBackBanner({super.key, this.notice});

  final String? notice;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      key: const ValueKey('result-rolled-back'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(color: scheme.errorContainer, borderRadius: BorderRadius.circular(AppRadius.lg)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: AppSpacing.sm,
        children: [
          Icon(Icons.undo, color: scheme.onErrorContainer, size: MediaQuery.textScalerOf(context).scale(18)),
          Expanded(
            child: Text(
              notice ?? S.of(context).result_rolled_back,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}

/// The strip above the rows (Studio's `StatsBar`): the rows and execution time, the `limited` chip with Studio's
/// notice when Studio bounded the result, a chip that opens and shuts the warnings, open at first as Studio's is, a
/// [trailing] widget after the chips, Studio's notice that rows may repeat or be skipped between pages when
/// [orderNotice] asks for it, and the rollback banner, worded by [rolledBackNotice] when given. Each loss notice stays
/// reachable: a shut warning list keeps its chip, and a strip taller than [maxHeight], as at a large text size, scrolls
/// inside that height, so the rows keep their room.
class ResultStatsStrip extends StatefulWidget {
  const ResultStatsStrip({
    super.key,
    required this.result,
    this.maxHeight = double.infinity,
    this.orderNotice = false,
    this.trailing,
    this.rolledBackNotice,
  });

  final QueryResult result;

  /// The most height the strip takes.
  final double maxHeight;

  /// Whether to say, once, that without an ORDER BY the engine may return rows that repeat or are skipped between
  /// pages (`StatsBar.tsx:60`).
  final bool orderNotice;

  /// Shown after the chips, such as the card and table toggle.
  final Widget? trailing;

  /// The rollback banner's sentence, when the caller words it.
  final String? rolledBackNotice;

  @override
  State<ResultStatsStrip> createState() => _ResultStatsStripState();
}

class _ResultStatsStripState extends State<ResultStatsStrip> {
  bool _warningsOpen = true;
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final number = resultNumberFormat(context);
    final result = widget.result;
    final count = result.rows.length;
    final warnings = result.warnings;
    final chipStyle = theme.textTheme.labelSmall;
    final strip = Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppSpacing.sm,
        children: [
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                s.result_stats(
                  count,
                  number.format(count),
                  number.format(result.executionTime.inMicroseconds / Duration.microsecondsPerMillisecond),
                ),
                style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
              if (result.pagination?.wasLimited == true)
                Semantics(
                  label: s.result_limited_notice,
                  excludeSemantics: true,
                  child: Tooltip(
                    message: s.result_limited_notice,
                    triggerMode: TooltipTriggerMode.tap,
                    showDuration: const Duration(seconds: 4),
                    child: _Chip(
                      key: const ValueKey('result-limited-chip'),
                      background: scheme.primaryContainer,
                      child: Text(s.result_limited, style: chipStyle?.copyWith(color: scheme.onPrimaryContainer)),
                    ),
                  ),
                ),
              if (warnings.isNotEmpty)
                Semantics(
                  button: true,
                  expanded: _warningsOpen,
                  child: InkWell(
                    key: const ValueKey('result-warnings-chip'),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    onTap: () => setState(() => _warningsOpen = !_warningsOpen),
                    child: _Chip(
                      background: scheme.errorContainer,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Wraps at a large text size rather than run past the screen's edge.
                          Flexible(
                            child: Text(
                              s.result_warnings(warnings.length),
                              style: chipStyle?.copyWith(color: scheme.onErrorContainer),
                            ),
                          ),
                          Icon(
                            _warningsOpen ? Icons.expand_less : Icons.expand_more,
                            size: MediaQuery.textScalerOf(context).scale(14),
                            color: scheme.onErrorContainer,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ?widget.trailing,
            ],
          ),
          if (widget.orderNotice)
            Row(
              key: const ValueKey('result-order-notice'),
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: AppSpacing.xs,
              children: [
                Icon(Icons.info_outline, size: MediaQuery.textScalerOf(context).scale(14), color: scheme.tertiary),
                Expanded(
                  child: Text(
                    s.result_order_notice,
                    style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          if (warnings.isNotEmpty && _warningsOpen) ResultWarningList(warnings: warnings),
          if (result.openTransactionRolledBack) ResultRolledBackBanner(notice: widget.rolledBackNotice),
        ],
      ),
    );
    return ConstrainedBox(
      key: const ValueKey('result-notices'),
      constraints: BoxConstraints(maxHeight: widget.maxHeight),
      child: Scrollbar(
        controller: _scroll,
        thumbVisibility: true,
        child: SingleChildScrollView(controller: _scroll, child: strip),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({super.key, required this.background, required this.child});

  final Color background;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
    decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(AppRadius.sm)),
    child: child,
  );
}
