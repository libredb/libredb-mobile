part of 'grant_list_bloc.dart';

sealed class GrantListState extends Equatable {
  const GrantListState();

  @override
  List<Object?> get props => const [];
}

final class GrantListInitial extends GrantListState {
  const GrantListInitial();
}

final class GrantListLoading extends GrantListState {
  const GrantListLoading();
}

/// The grants Platform answered, in its order (by username).
///
/// A refresh keeps the list on screen: [isRefreshing] while it runs, and [refreshError] when it failed, so the page
/// shows the failure above the list it still has.
final class GrantListLoaded extends GrantListState {
  const GrantListLoaded({required this.grants, this.isRefreshing = false, this.refreshError});

  final List<PlatformGrant> grants;

  final bool isRefreshing;

  /// Why the last refresh failed, shown via `refreshError.resolve(context)`; the raw message only goes to the log.
  final AppErrorCode? refreshError;

  @override
  List<Object?> get props => [grants, isRefreshing, refreshError];
}

/// The grants could not be loaded; `platformNotFound` means the connection no longer exists.
final class GrantListFailure extends GrantListState {
  const GrantListFailure({required this.errorCode});

  /// Shown via `errorCode.resolve(context)`; the raw message only goes to the log.
  final AppErrorCode errorCode;

  @override
  List<Object?> get props => [errorCode];
}
