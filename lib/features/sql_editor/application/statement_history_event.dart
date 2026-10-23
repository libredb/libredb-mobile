part of 'statement_history_bloc.dart';

sealed class StatementHistoryEvent extends Equatable {
  const StatementHistoryEvent();

  @override
  List<Object?> get props => const [];
}

/// Read the history, when the sheet opens or on Retry.
final class StatementHistoryLoadRequested extends StatementHistoryEvent {
  const StatementHistoryLoadRequested();
}

/// The search text as typed, compared with `matchesSearch` over the statement and the connection name.
final class StatementHistorySearchChanged extends StatementHistoryEvent {
  const StatementHistorySearchChanged(this.query);

  final String query;

  @override
  List<Object?> get props => [query];

  /// Prints the length, never the text, which can be part of a statement.
  @override
  String toString() => 'StatementHistorySearchChanged(${query.length} characters)';
}

/// Show every connection's entries, or only the active connection's.
final class StatementHistoryScopeChanged extends StatementHistoryEvent {
  const StatementHistoryScopeChanged({required this.allConnections});

  final bool allConnections;

  @override
  List<Object?> get props => [allConnections];
}

final class StatementHistoryStatusFilterChanged extends StatementHistoryEvent {
  const StatementHistoryStatusFilterChanged(this.filter);

  final HistoryStatusFilter filter;

  @override
  List<Object?> get props => [filter];
}

/// The user swiped the entry [entryId] away. [done] answers whether the store removed it, so the swipe dismisses the
/// row only then.
final class StatementHistoryEntryDeleted extends StatementHistoryEvent {
  const StatementHistoryEntryDeleted(this.entryId, {this.done});

  final String entryId;
  final Completer<bool>? done;

  @override
  List<Object?> get props => [entryId];
}

/// Remove the whole history, after the user confirmed Clear all, or Discard of a history that cannot be read.
final class StatementHistoryClearRequested extends StatementHistoryEvent {
  const StatementHistoryClearRequested();
}
