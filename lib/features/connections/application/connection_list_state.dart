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

final class ConnectionListLoaded extends ConnectionListState {
  const ConnectionListLoaded({required this.connections, this.cacheHint, required this.loadedAt});

  final List<StudioConnection> connections;

  /// How often Studio expects the list to be asked again, when it sent a hint.
  final Duration? cacheHint;

  /// When Studio answered with [connections]; offline, the page shows the list as what was loaded at this time.
  final DateTime loadedAt;

  @override
  List<Object?> get props => [connections, cacheHint, loadedAt];
}

final class ConnectionListFailure extends ConnectionListState {
  const ConnectionListFailure({required this.errorCode});

  /// Shown via `errorCode.resolve(context)`; the raw message only goes to the log.
  final AppErrorCode errorCode;

  @override
  List<Object?> get props => [errorCode];
}
