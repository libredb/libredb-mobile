import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/features/sql_editor/application/statement_history_bloc.dart';
import 'package:libredb_mobile/features/sql_editor/domain/entities/statement_history_entry.dart';
import 'package:libredb_mobile/features/sql_editor/domain/repositories/statement_history_repository.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/shared/design_system/components/app_empty_state.dart';
import 'package:libredb_mobile/shared/design_system/components/app_error_state.dart';
import 'package:libredb_mobile/shared/design_system/tokens/app_spacing.dart';
import 'package:libredb_mobile/shared/l10n/app_error_code_l10n.dart';
import 'package:libredb_mobile/shared/widgets/local_filter_field.dart';
import 'package:libredb_mobile/shared/design_system/tokens/app_typography.dart';

/// Shows the History sheet of [subjectHash] over the editor of [activeConnectionId], and answers the entry the user
/// tapped to put in the editor, or null when the sheet closed without one. Only an entry whose text was kept can be
/// tapped, of [activeConnectionId] or of another connection, which the editor then opens; the sheet never runs
/// anything.
///
/// [onRoute] is told the sheet's route, so the editor can close it when it is disposed.
Future<StatementHistoryEntry?> showStatementHistorySheet(
  BuildContext context, {
  required String subjectHash,
  required String activeConnectionId,
  ValueChanged<Route<StatementHistoryEntry>>? onRoute,
}) {
  final repository = context.read<IStatementHistoryRepository>();
  return showModalBottomSheet<StatementHistoryEntry>(
    context: context,
    // Above the shell, as the write confirmation is, so a tab or connection switch cannot close the editor under it.
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (sheetContext) {
      if (ModalRoute.of(sheetContext) case final Route<StatementHistoryEntry> route) onRoute?.call(route);
      return BlocProvider(
        create: (_) => StatementHistoryBloc(
          repository: repository,
          subjectHash: subjectHash,
          activeConnectionId: activeConnectionId,
        )..add(const StatementHistoryLoadRequested()),
        child: const StatementHistorySheet(),
      );
    },
  );
}

/// The account's statement history on this phone: the open connection's entries by default with an All connections
/// switch, the local search over the text and the connection name, the status filter, a swipe to delete one entry and
/// Clear all behind a confirmation. A failed run says Failed and never the database's words, which are not kept.
class StatementHistorySheet extends StatelessWidget {
  const StatementHistorySheet({super.key});

  static const allConnectionsKey = ValueKey('statement_history_all_connections');
  static const clearAllKey = ValueKey('statement_history_clear_all');

  static ValueKey<String> entryKey(String id) => ValueKey('statement_history_entry_$id');

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return FractionallySizedBox(
      heightFactor: 0.85,
      child: BlocBuilder<StatementHistoryBloc, StatementHistoryState>(
        builder: (context, state) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(state: state),
            if (state case StatementHistoryLoaded(:final allConnections)) ...[
              SwitchListTile(
                key: allConnectionsKey,
                title: Text(s.sql_history_all_connections),
                value: allConnections,
                onChanged: (value) =>
                    context.read<StatementHistoryBloc>().add(StatementHistoryScopeChanged(allConnections: value)),
              ),
              LocalFilterField(
                hintText: s.sql_history_search_hint,
                onChanged: (query) => context.read<StatementHistoryBloc>().add(StatementHistorySearchChanged(query)),
              ),
              _StatusFilter(selected: state.statusFilter),
            ],
            Expanded(
              child: switch (state) {
                StatementHistoryLoading() => const Center(child: CircularProgressIndicator()),
                StatementHistoryLoaded() => _EntryList(state: state),
                StatementHistoryUnreadable(:final actionFailure) => _Unreadable(actionFailure: actionFailure),
                StatementHistoryFailure(:final errorCode) => AppErrorState(
                  title: errorCode.resolve(context),
                  retryLabel: s.retry,
                  onRetry: () => context.read<StatementHistoryBloc>().add(const StatementHistoryLoadRequested()),
                ),
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.state});

  final StatementHistoryState state;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final hasEntries = switch (state) {
      StatementHistoryLoaded(:final entries) => entries.isNotEmpty,
      StatementHistoryLoading() || StatementHistoryUnreadable() || StatementHistoryFailure() => false,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Row(
        children: [
          Expanded(child: Text(s.sql_history_title, style: Theme.of(context).textTheme.titleLarge)),
          TextButton(
            key: StatementHistorySheet.clearAllKey,
            onPressed: hasEntries ? () => _confirmClear(context) : null,
            child: Text(s.sql_history_clear_all),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmClear(BuildContext context) async {
    final s = S.of(context);
    final bloc = context.read<StatementHistoryBloc>();
    final confirmed = await _confirm(
      context,
      title: s.sql_history_clear_title,
      message: s.sql_history_clear_message,
      action: s.sql_history_clear_all,
    );
    if (confirmed) bloc.add(const StatementHistoryClearRequested());
  }
}

class _StatusFilter extends StatelessWidget {
  const _StatusFilter({required this.selected});

  final HistoryStatusFilter selected;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.xs),
      child: Wrap(
        spacing: AppSpacing.sm,
        children: [
          for (final (filter, label) in [
            (HistoryStatusFilter.all, s.sql_history_filter_all),
            (HistoryStatusFilter.success, s.sql_history_filter_success),
            (HistoryStatusFilter.failure, s.sql_history_filter_failure),
          ])
            ChoiceChip(
              label: Text(label),
              selected: selected == filter,
              onSelected: (_) => context.read<StatementHistoryBloc>().add(StatementHistoryStatusFilterChanged(filter)),
            ),
        ],
      ),
    );
  }
}

class _EntryList extends StatelessWidget {
  const _EntryList({required this.state});

  final StatementHistoryLoaded state;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final visible = state.visible;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (state.actionFailure case final failure?)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.xs),
            child: Text(failure.resolve(context), style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        Expanded(
          child: visible.isEmpty
              ? (state.entries.isEmpty
                    ? AppEmptyState(
                        icon: Icons.history,
                        title: s.sql_history_empty,
                        description: s.sql_history_empty_description,
                      )
                    : Center(child: Text(s.local_filter_no_match)))
              : ListView.builder(
                  itemCount: visible.length,
                  itemBuilder: (context, index) =>
                      _EntryTile(entry: visible[index], opens: state.opens(visible[index])),
                ),
        ),
      ],
    );
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.entry, required this.opens});

  final StatementHistoryEntry entry;
  final bool opens;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final failed = entry.status == StatementRunStatus.failure;
    final when = DateFormat.yMMMd(Localizations.localeOf(context).toString())
        .add_Hm()
        .format(entry.executedAt.toLocal());
    final details = [
      entry.connectionName,
      if (failed) s.sql_history_failed else s.sql_history_succeeded,
      if (entry.rowCount case final rows?) s.sql_history_rows(rows),
      s.sql_history_duration(entry.duration.inMilliseconds),
      when,
    ].join(' · ');
    final bloc = context.read<StatementHistoryBloc>();
    Future<bool> delete() {
      final done = Completer<bool>();
      bloc.add(StatementHistoryEntryDeleted(entry.id, done: done));
      return done.future;
    }

    return Dismissible(
      key: StatementHistorySheet.entryKey(entry.id),
      direction: DismissDirection.endToStart,
      // The row is dismissed only once the store removed the entry; a refused delete leaves it where it was.
      confirmDismiss: (_) => delete(),
      background: Container(
        color: theme.colorScheme.errorContainer,
        alignment: AlignmentDirectional.centerEnd,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: Text(s.sql_history_delete, style: TextStyle(color: theme.colorScheme.onErrorContainer)),
      ),
      child: Semantics(
        customSemanticsActions: {CustomSemanticsAction(label: s.sql_history_delete): delete},
        child: ListTile(
          enabled: opens,
          leading: Icon(
            failed ? Icons.error_outline : Icons.check_circle_outline,
            color: failed ? theme.colorScheme.error : null,
          ),
          title: switch (entry.text) {
            final text? => Text(
              text,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontFamily: AppTypography.mono),
            ),
            null => Text(s.sql_history_too_long, style: const TextStyle(fontStyle: FontStyle.italic)),
          },
          subtitle: Text(details),
          onTap: opens ? () => Navigator.of(context).pop(entry) : null,
        ),
      ),
    );
  }
}

class _Unreadable extends StatelessWidget {
  const _Unreadable({required this.actionFailure});

  final AppErrorCode? actionFailure;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(AppErrorCode.editorSavedTextUnreadable.resolve(context)),
          if (actionFailure case final failure?) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(failure.resolve(context), style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          const SizedBox(height: AppSpacing.lg),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: FilledButton(onPressed: () => _discard(context), child: Text(s.editor_saved_text_discard)),
          ),
        ],
      ),
    );
  }

  Future<void> _discard(BuildContext context) async {
    final s = S.of(context);
    final bloc = context.read<StatementHistoryBloc>();
    final confirmed = await _confirm(
      context,
      title: s.editor_saved_text_discard_title,
      message: s.editor_saved_text_discard_message,
      action: s.editor_saved_text_discard,
    );
    if (confirmed) bloc.add(const StatementHistoryClearRequested());
  }
}

/// Asks before a delete that cannot be undone; answers whether the user confirmed.
Future<bool> _confirm(
  BuildContext context, {
  required String title,
  required String message,
  required String action,
}) async {
  final s = S.of(context);
  final answer = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: Text(s.cancel)),
        FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: Text(action)),
      ],
    ),
  );
  return answer ?? false;
}
