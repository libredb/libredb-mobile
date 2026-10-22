part of 'connection_list_bloc.dart';

sealed class ConnectionListState extends Equatable {
  const ConnectionListState();

  @override
  List<Object?> get props => const [];
}

final class ConnectionListInitial extends ConnectionListState {
  const ConnectionListInitial();
}

final class ConnectionListLoading extends ConnectionListState {
  const ConnectionListLoading();
}

/// The list Studio answered, with the search and the environment filter applied to it.
///
/// A refresh keeps the list on screen: [isRefreshing] while it runs, and [refreshErrorCode] when it failed, so the
/// page shows the failure next to the list it still has.
final class ConnectionListLoaded extends ConnectionListState {
  const ConnectionListLoaded({
    required this.connections,
    this.cacheHint,
    this.query = '',
    this.environment,
    this.isRefreshing = false,
    this.refreshErrorCode,
  });

  /// Every connection Studio answered, before the search and the filter.
  final List<StudioConnection> connections;

  /// How often Studio expects the list to be asked again, when it sent a hint.
  final Duration? cacheHint;

  /// The search text as typed; see [filterConnections].
  final String query;

  /// The environment the list is narrowed to, or null for every row.
  final String? environment;

  final bool isRefreshing;

  /// Why the last refresh failed; shown via `errorCode.resolve(context)`, the raw message only goes to the log.
  final AppErrorCode? refreshErrorCode;

  /// The rows that match [query] and [environment], in sections by group.
  List<ConnectionSection> get sections =>
      groupConnections(filterConnections(connections, query: query, environment: environment));

  /// The environments the filter offers: those of every row, and the chosen one even when no row has it any more.
  List<String> get environments {
    final present = environmentsOf(connections);
    final chosen = environment;
    return chosen == null || present.contains(chosen) ? present : [...present, chosen];
  }

  ConnectionListLoaded _with({
    List<StudioConnection>? connections,
    String? query,
    String? Function()? environment,
    bool isRefreshing = false,
    AppErrorCode? refreshErrorCode,
  }) => ConnectionListLoaded(
    connections: connections ?? this.connections,
    cacheHint: cacheHint,
    query: query ?? this.query,
    environment: environment == null ? this.environment : environment(),
    isRefreshing: isRefreshing,
    refreshErrorCode: refreshErrorCode,
  );

  @override
  List<Object?> get props => [connections, cacheHint, query, environment, isRefreshing, refreshErrorCode];
}

final class ConnectionListFailure extends ConnectionListState {
  const ConnectionListFailure({required this.errorCode});

  /// Shown via `errorCode.resolve(context)`; the raw message only goes to the log.
  final AppErrorCode errorCode;

  @override
  List<Object?> get props => [errorCode];
}
