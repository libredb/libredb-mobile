part of 'result_view_bloc.dart';

sealed class ResultViewState extends Equatable {
  const ResultViewState();

  @override
  List<Object?> get props => const [];
}

/// A masked result, shown as a card per row with its stats strip, or as an empty state when it has no row.
final class ResultViewLoaded extends ResultViewState {
  const ResultViewLoaded({required this.result, required this.maskedColumns});

  /// The result with the values of [maskedColumns] already masked.
  final QueryResult result;

  /// The columns whose values are masked; each of their values that is not NULL carries a lock.
  final Set<String> maskedColumns;

  @override
  List<Object?> get props => [result, maskedColumns];
}
