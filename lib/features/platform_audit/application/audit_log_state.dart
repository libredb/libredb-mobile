part of 'audit_log_bloc.dart';

/// What the audit log page shows; every variant carries the [filter] it was asked for, so the chips always name it.
sealed class AuditLogState extends Equatable {
  const AuditLogState({required this.filter});

  final AuditFilter filter;

  @override
  List<Object?> get props => [filter];
}

final class AuditLogInitial extends AuditLogState {
  const AuditLogInitial({required super.filter});
}

final class AuditLogLoading extends AuditLogState {
  const AuditLogLoading({required super.filter});
}

/// The events read so far, newest first, each listed once.
///
/// A refresh or a filter change keeps the list on screen: [isRefreshing] while it runs, and [refreshError] when it
/// failed. A Load more keeps it too: [isLoadingMore] while it runs, and [loadMoreError] when it failed.
final class AuditLogLoaded extends AuditLogState {
  const AuditLogLoaded({
    required super.filter,
    required this.events,
    required this.total,
    this.nextOffset,
    this.isRefreshing = false,
    this.refreshError,
    this.isLoadingMore = false,
    this.loadMoreError,
  });

  final List<AuditEvent> events;

  /// How many events the filter selects, as Platform counted them on the last page read.
  final int total;

  /// The offset of the next page, past every row Platform answered so far; null when the last page was the end.
  ///
  /// It counts Platform's rows rather than [events], since an event repeated across pages is listed once.
  final int? nextOffset;

  final bool isRefreshing;

  /// Why the last refresh or filter change failed, shown via `refreshError.resolve(context)`.
  final AppErrorCode? refreshError;

  final bool isLoadingMore;

  /// Why the last Load more failed, shown via `loadMoreError.resolve(context)`.
  final AppErrorCode? loadMoreError;

  /// Whether Platform holds events past the ones read, by its rule that `offset + limit < total` means another page.
  bool get hasMore => nextOffset != null;

  /// Whether a Load more would be sent now.
  bool get canLoadMore => hasMore && !isLoadingMore && !isRefreshing;

  AuditLogLoaded _with({
    AuditFilter? filter,
    bool? isRefreshing,
    AppErrorCode? Function()? refreshError,
    bool? isLoadingMore,
    AppErrorCode? Function()? loadMoreError,
  }) => AuditLogLoaded(
    filter: filter ?? this.filter,
    events: events,
    total: total,
    nextOffset: nextOffset,
    isRefreshing: isRefreshing ?? this.isRefreshing,
    refreshError: refreshError == null ? this.refreshError : refreshError(),
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    loadMoreError: loadMoreError == null ? this.loadMoreError : loadMoreError(),
  );

  @override
  List<Object?> get props => [
    filter,
    events,
    total,
    nextOffset,
    isRefreshing,
    refreshError,
    isLoadingMore,
    loadMoreError,
  ];
}

/// The first page could not be read; the raw message only goes to the log.
final class AuditLogFailure extends AuditLogState {
  const AuditLogFailure({required super.filter, required this.errorCode});

  final AppErrorCode errorCode;

  @override
  List<Object?> get props => [filter, errorCode];
}

/// Platform answered `PLAN_FEATURE_REQUIRED`: the install's plan has no audit log.
final class AuditLogPlanRefused extends AuditLogState {
  const AuditLogPlanRefused({required super.filter});
}

/// Platform answered `PERMISSION_DENIED`: this account may not read the audit log.
final class AuditLogPermissionRefused extends AuditLogState {
  const AuditLogPermissionRefused({required super.filter});
}
