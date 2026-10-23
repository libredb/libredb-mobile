part of 'object_source_bloc.dart';

sealed class ObjectSourceState extends Equatable {
  const ObjectSourceState();

  @override
  List<Object?> get props => const [];
}

final class ObjectSourceLoading extends ObjectSourceState {
  const ObjectSourceLoading();
}

final class ObjectSourceLoaded extends ObjectSourceState {
  const ObjectSourceLoaded(this.source);

  final ObjectSource source;

  @override
  List<Object?> get props => [source];
}

/// The source could not be read; [error] is shown by the Browse failure view, from its code.
final class ObjectSourceFailure extends ObjectSourceState {
  const ObjectSourceFailure(this.error);

  final AppError error;

  @override
  List<Object?> get props => [error];
}
