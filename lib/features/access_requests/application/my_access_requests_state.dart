part of 'my_access_requests_bloc.dart';

sealed class MyAccessRequestsState extends Equatable {
  const MyAccessRequestsState();

  @override
  List<Object?> get props => const [];
}

final class MyAccessRequestsInitial extends MyAccessRequestsState {
  const MyAccessRequestsInitial();
}

final class MyAccessRequestsLoading extends MyAccessRequestsState {
  const MyAccessRequestsLoading();
}

/// The requests Platform answered, in its order (newest first).
///
/// A refresh keeps the list on screen: [isRefreshing] while it runs, and [refreshError] when it failed, so the page
/// tells the user and still shows the list it has.
final class MyAccessRequestsLoaded extends MyAccessRequestsState {
  const MyAccessRequestsLoaded({required this.requests, this.isRefreshing = false, this.refreshError});

  final List<MyAccessRequest> requests;

  final bool isRefreshing;

  /// Why the last refresh failed, shown via `refreshError.resolve(context)`; the raw message only goes to the log.
  final AppErrorCode? refreshError;

  @override
  List<Object?> get props => [requests, isRefreshing, refreshError];
}

/// The list could not be loaded.
final class MyAccessRequestsFailure extends MyAccessRequestsState {
  const MyAccessRequestsFailure({required this.errorCode});

  /// Shown via `errorCode.resolve(context)`; the raw message only goes to the log.
  final AppErrorCode errorCode;

  @override
  List<Object?> get props => [errorCode];
}
