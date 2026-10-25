part of 'platform_connection_list_bloc.dart';

sealed class PlatformConnectionListState extends Equatable {
  const PlatformConnectionListState();

  @override
  List<Object?> get props => const [];
}

final class PlatformConnectionListInitial extends PlatformConnectionListState {
  const PlatformConnectionListInitial();
}

final class PlatformConnectionListLoading extends PlatformConnectionListState {
  const PlatformConnectionListLoading();
}

/// The list Platform answered, with the search applied to it.
///
/// A refresh keeps the list on screen: [isRefreshing] while it runs, and [refreshError] when it failed, so the page
/// shows the failure next to the list it still has.
final class PlatformConnectionListLoaded extends PlatformConnectionListState {
  const PlatformConnectionListLoaded({
    required this.connections,
    this.query = '',
    this.isRefreshing = false,
    this.refreshError,
  });

  /// Every connection Platform answered, in its order (newest first).
  final List<PlatformConnection> connections;

  /// The search text as typed.
  final String query;

  final bool isRefreshing;

  /// Why the last refresh failed, shown via `refreshError.resolve(context)`; the raw message only goes to the log.
  final AppErrorCode? refreshError;

  /// The connections whose name or engine id matches [query], in Platform's order.
  List<PlatformConnection> get visible =>
      connections.where((c) => matchesSearch(query, [c.name, c.engine])).toList(growable: false);

  PlatformConnectionListLoaded _with({
    List<PlatformConnection>? connections,
    String? query,
    bool? isRefreshing,
    AppErrorCode? Function()? refreshError,
  }) => PlatformConnectionListLoaded(
    connections: connections ?? this.connections,
    query: query ?? this.query,
    isRefreshing: isRefreshing ?? this.isRefreshing,
    refreshError: refreshError == null ? this.refreshError : refreshError(),
  );

  @override
  List<Object?> get props => [connections, query, isRefreshing, refreshError];
}

final class PlatformConnectionListFailure extends PlatformConnectionListState {
  const PlatformConnectionListFailure({required this.errorCode});

  /// Shown via `errorCode.resolve(context)`; the raw message only goes to the log.
  final AppErrorCode errorCode;

  @override
  List<Object?> get props => [errorCode];
}
