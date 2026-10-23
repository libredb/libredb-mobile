part of 'row_count_bloc.dart';

sealed class RowCountState extends Equatable {
  const RowCountState();

  @override
  List<Object?> get props => const [];
}

/// Nothing was counted yet.
final class RowCountIdle extends RowCountState {
  const RowCountIdle();
}

/// A count runs; [previous] is the last count, kept on screen meanwhile.
final class RowCountRunning extends RowCountState {
  const RowCountRunning({this.previous});

  final int? previous;

  @override
  List<Object?> get props => [previous];
}

final class RowCountLoaded extends RowCountState {
  const RowCountLoaded(this.count);

  final int count;

  @override
  List<Object?> get props => [count];
}

/// The count was refused or its answer could not be read; [error] keeps its code for the line that says so.
final class RowCountFailure extends RowCountState {
  const RowCountFailure(this.error);

  final AppError error;

  @override
  List<Object?> get props => [error];
}
