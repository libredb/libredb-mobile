part of 'row_count_bloc.dart';

sealed class RowCountEvent extends Equatable {
  const RowCountEvent();

  @override
  List<Object?> get props => const [];
}

/// The user tapped Count rows: runs [statement], the generator's count, in its catalog.
final class RowCountRequested extends RowCountEvent {
  const RowCountRequested(this.statement);

  final PreviewStatement statement;

  @override
  List<Object?> get props => [statement];
}
