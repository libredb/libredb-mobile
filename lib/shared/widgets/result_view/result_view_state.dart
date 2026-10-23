part of 'result_view_bloc.dart';

sealed class ResultViewState extends Equatable {
  const ResultViewState();

  /// The result on screen, with the values of [maskedColumns] already masked.
  QueryResult get result;

  /// The columns whose values are masked; each of their values that is not NULL carries a lock.
  Set<String> get maskedColumns;

  @override
  List<Object?> get props => const [];
}

/// A masked result, shown as cards or a table with its stats strip, or as an empty state when it has no row;
/// [loadingMore] while its next page is in flight.
final class ResultViewLoaded extends ResultViewState {
  const ResultViewLoaded({required this.result, required this.maskedColumns, this.loadingMore = false});

  @override
  final QueryResult result;

  @override
  final Set<String> maskedColumns;

  final bool loadingMore;

  @override
  List<Object?> get props => [result, maskedColumns, loadingMore];
}

/// The next page of [result] failed: the rows stay on screen, and [error] is shown by `StudioErrorBanner` with a retry
/// the user taps. It keeps the error itself, not only its code, since the banner needs `retryAfter`; nothing logs its
/// message.
final class ResultViewLoadMoreFailed extends ResultViewState {
  const ResultViewLoadMoreFailed({required this.result, required this.maskedColumns, required this.error});

  @override
  final QueryResult result;

  @override
  final Set<String> maskedColumns;

  final AppError error;

  @override
  List<Object?> get props => [result, maskedColumns, error];
}
