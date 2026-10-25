part of 'platform_connection_list_bloc.dart';

sealed class PlatformConnectionListEvent extends Equatable {
  const PlatformConnectionListEvent();

  @override
  List<Object?> get props => const [];
}

/// Asks Platform for the list; a newer load replaces one still running.
sealed class PlatformConnectionListLoadEvent extends PlatformConnectionListEvent {
  const PlatformConnectionListLoadEvent();
}

/// Loads the list when the tab opens.
final class PlatformConnectionListRequested extends PlatformConnectionListLoadEvent {
  const PlatformConnectionListRequested();
}

/// Asks again from a pull to refresh or a retry, keeping a loaded list on screen while the answer is awaited.
final class PlatformConnectionListRefreshed extends PlatformConnectionListLoadEvent {
  const PlatformConnectionListRefreshed();
}

/// The search text the user typed; applied [PlatformConnectionListBloc.searchDebounce] after the last keystroke.
final class PlatformConnectionListSearchChanged extends PlatformConnectionListEvent {
  const PlatformConnectionListSearchChanged(this.query);

  final String query;

  @override
  List<Object?> get props => [query];
}

/// The connection Platform answered after enabling or disabling it, which takes the place of the item with its id.
final class PlatformConnectionReplaced extends PlatformConnectionListEvent {
  const PlatformConnectionReplaced(this.connection);

  /// Its text never carries the name.
  final PlatformConnection connection;

  @override
  List<Object?> get props => [connection];
}
