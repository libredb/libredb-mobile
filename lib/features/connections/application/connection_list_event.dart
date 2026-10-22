part of 'connection_list_bloc.dart';

sealed class ConnectionListEvent extends Equatable {
  const ConnectionListEvent();

  @override
  List<Object?> get props => const [];
}

/// Loads the list, on open and on a retry. A newer request replaces one still running.
final class ConnectionListRequested extends ConnectionListEvent {
  const ConnectionListRequested();
}
