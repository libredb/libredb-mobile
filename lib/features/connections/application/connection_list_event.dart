part of 'connection_list_bloc.dart';

sealed class ConnectionListEvent extends Equatable {
  const ConnectionListEvent();

  @override
  List<Object?> get props => const [];
}

/// Asks Studio for the list; a newer load replaces one still running.
sealed class ConnectionListLoadEvent extends ConnectionListEvent {
  const ConnectionListLoadEvent();
}

/// Loads the list, on open and on a retry.
final class ConnectionListRequested extends ConnectionListLoadEvent {
  const ConnectionListRequested();
}

/// Asks again from a pull to refresh, keeping the list on screen while the answer is awaited.
final class ConnectionListRefreshed extends ConnectionListLoadEvent {
  const ConnectionListRefreshed();
}

/// The search text the user typed; applied 200 ms after the last keystroke.
final class ConnectionListSearchChanged extends ConnectionListEvent {
  const ConnectionListSearchChanged(this.query);

  final String query;

  @override
  List<Object?> get props => [query];
}

/// Shows only the rows of [environment], or every row when it is null.
final class ConnectionListEnvironmentFilterChanged extends ConnectionListEvent {
  const ConnectionListEnvironmentFilterChanged(this.environment);

  final String? environment;

  @override
  List<Object?> get props => [environment];
}

/// Asks Studio again on the live refresh timer, without showing that a refresh runs.
final class ConnectionListPolled extends ConnectionListLoadEvent {
  const ConnectionListPolled();
}

/// Whether the list is on screen with the app in the foreground and the device online: the live refresh runs only then.
final class ConnectionListAutoRefreshChanged extends ConnectionListEvent {
  const ConnectionListAutoRefreshChanged({required this.active, this.askNow = false});

  final bool active;

  /// Whether to ask Studio at once instead of after the usual wait, as when the app comes back to the foreground.
  final bool askNow;

  @override
  List<Object?> get props => [active, askNow];
}
