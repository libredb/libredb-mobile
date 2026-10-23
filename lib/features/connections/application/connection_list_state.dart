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
/// A refresh keeps the list on screen: [isRefreshing] while it runs, and [refreshError] when it failed, so the page
/// shows the failure next to the list it still has.
final class ConnectionListLoaded extends ConnectionListState {
  const ConnectionListLoaded({
    required this.connections,
    this.cacheHint,
    required this.loadedAt,
    this.query = '',
    this.environment,
    this.isRefreshing = false,
    this.refreshError,
  });

  /// Every connection Studio answered, before the search and the filter.
  final List<StudioConnection> connections;

  /// How often Studio expects the list to be asked again, when it sent a hint.
  final Duration? cacheHint;

  /// When Studio answered with [connections]; offline, the page shows the list as what was loaded at this time.
  final DateTime loadedAt;

  /// The search text as typed; see [filterConnections].
  final String query;

  /// The environment the list is narrowed to, or null for every row.
  final String? environment;

  final bool isRefreshing;

  /// Why the last refresh failed, shown by `StudioErrorBanner` from its code; the raw message only goes to the log.
  final AppError? refreshError;

  /// Whether [query] filters the list at all; whitespace alone does not (see [normalizeSearchQuery]).
  bool get isSearching => normalizeSearchQuery(query).isNotEmpty;

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
    AppError? refreshError,
  }) => ConnectionListLoaded(
    connections: connections ?? this.connections,
    cacheHint: cacheHint,
    loadedAt: loadedAt,
    query: query ?? this.query,
    environment: environment == null ? this.environment : environment(),
    isRefreshing: isRefreshing,
    refreshError: refreshError,
  );

  @override
  List<Object?> get props => [connections, cacheHint, loadedAt, query, environment, isRefreshing, refreshError];
}

/// Studio cannot serve the granted connections right now: `GET /api/connections/managed` answered 503
/// `GOVERNANCE_UNAVAILABLE`. That says nothing about what was granted, so the page never shows it as an empty list.
///
/// [previous] is the list shown before the outage, which the page keeps greyed under the outage notice; without one
/// the outage covers the page. The bloc asks again every [ConnectionListBloc.unavailableRetryInterval] while the list
/// is in the foreground, and [isRetrying] is true while a retry the user asked for runs. A retry that fails before it
/// reaches governance, such as an identity provider outage, a 429 or a 500, says nothing about whether governance is
/// back, so the outage stays and [retryError] says why that retry failed.
final class ConnectionListUnavailable extends ConnectionListState {
  const ConnectionListUnavailable({required this.errorCode, this.previous, this.isRetrying = false, this.retryError});

  /// The code of Studio's answer, `studio.governance_unavailable`; the raw message only goes to the log.
  final AppErrorCode errorCode;

  final ConnectionListLoaded? previous;

  final bool isRetrying;

  /// Why the last retry failed without an answer from governance; a 429 makes the next retry wait as Studio asked.
  final AppError? retryError;

  @override
  List<Object?> get props => [errorCode, previous, isRetrying, retryError];
}

final class ConnectionListFailure extends ConnectionListState {
  const ConnectionListFailure({required this.errorCode});

  /// Shown via `errorCode.resolve(context)`; the raw message only goes to the log.
  final AppErrorCode errorCode;

  @override
  List<Object?> get props => [errorCode];
}
