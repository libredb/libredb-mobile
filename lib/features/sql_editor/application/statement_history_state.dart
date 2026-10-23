part of 'statement_history_bloc.dart';

/// Which runs the sheet shows by how they ended.
enum HistoryStatusFilter { all, success, failure }

sealed class StatementHistoryState extends Equatable {
  const StatementHistoryState();

  @override
  List<Object?> get props => const [];
}

/// The history is being read.
final class StatementHistoryLoading extends StatementHistoryState {
  const StatementHistoryLoading();
}

/// The account's history, newest first, and the filters over it. [actionFailure] says why the last delete or clear
/// did not happen, until the next one does.
final class StatementHistoryLoaded extends StatementHistoryState {
  const StatementHistoryLoaded({
    required this.entries,
    required this.activeConnectionId,
    this.query = '',
    this.allConnections = false,
    this.statusFilter = HistoryStatusFilter.all,
    this.actionFailure,
  });

  final List<StatementHistoryEntry> entries;
  final String activeConnectionId;
  final String query;
  final bool allConnections;
  final HistoryStatusFilter statusFilter;
  final AppErrorCode? actionFailure;

  /// The entries the filters keep, newest first.
  List<StatementHistoryEntry> get visible => [
    for (final entry in entries)
      if ((allConnections || entry.connectionId == activeConnectionId) &&
          _keepsStatus(entry.status) &&
          matchesSearch(query, [entry.text, entry.connectionName]))
        entry,
  ];

  /// Whether [entry] can be put in the editor: a kept text of the connection open in it.
  bool opens(StatementHistoryEntry entry) => entry.connectionId == activeConnectionId && entry.text != null;

  bool _keepsStatus(StatementRunStatus status) => switch (statusFilter) {
    HistoryStatusFilter.all => true,
    HistoryStatusFilter.success => status == StatementRunStatus.success,
    HistoryStatusFilter.failure => status == StatementRunStatus.failure,
  };

  StatementHistoryLoaded copyWith({
    List<StatementHistoryEntry>? entries,
    String? query,
    bool? allConnections,
    HistoryStatusFilter? statusFilter,
    required AppErrorCode? actionFailure,
  }) => StatementHistoryLoaded(
    entries: entries ?? this.entries,
    activeConnectionId: activeConnectionId,
    query: query ?? this.query,
    allConnections: allConnections ?? this.allConnections,
    statusFilter: statusFilter ?? this.statusFilter,
    actionFailure: actionFailure,
  );

  @override
  List<Object?> get props => [entries, activeConnectionId, query, allConnections, statusFilter, actionFailure];

  /// Prints counts, never a statement or the search text.
  @override
  String toString() =>
      'StatementHistoryLoaded(${entries.length} entries, all: $allConnections, ${statusFilter.name}, '
      'search: ${query.length} characters, failure: ${actionFailure?.key})';
}

/// The saved history cannot be read; the sheet offers Discard behind a confirmation. [actionFailure] says why the last
/// discard did not happen.
final class StatementHistoryUnreadable extends StatementHistoryState {
  const StatementHistoryUnreadable({this.actionFailure});

  final AppErrorCode? actionFailure;

  @override
  List<Object?> get props => [actionFailure];
}

/// The history could not be read for another reason, shown through [errorCode] with Retry.
final class StatementHistoryFailure extends StatementHistoryState {
  const StatementHistoryFailure({required this.errorCode});

  final AppErrorCode errorCode;

  @override
  List<Object?> get props => [errorCode];
}
