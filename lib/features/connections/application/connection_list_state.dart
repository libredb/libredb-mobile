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
  const ConnectionListLoaded({required this.connections});

  final List<StudioConnection> connections;

  @override
  List<Object?> get props => [connections];
}

final class ConnectionListFailure extends ConnectionListState {
  const ConnectionListFailure({required this.errorCode});

  /// Shown via `errorCode.resolve(context)`; the raw message only goes to the log.
  final AppErrorCode errorCode;

  @override
  List<Object?> get props => [errorCode];
}
