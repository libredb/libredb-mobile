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
  const ObjectSourceLoaded(this.source, {this.hasDetails = false});

  final ObjectSource source;

  /// Whether the object's kind has columns, so its detail page can be opened from its source.
  final bool hasDetails;

  @override
  List<Object?> get props => [source, hasDetails];
}

/// The source could not be read; [error] is shown by the Browse failure view, from its code.
final class ObjectSourceFailure extends ObjectSourceState {
  const ObjectSourceFailure(this.error, {this.hasDetails = false});

  final AppError error;

  /// Whether the object's kind has columns, so its detail can be opened even though its source was refused; false
  /// when provider-meta itself failed.
  final bool hasDetails;

  @override
  List<Object?> get props => [error, hasDetails];
}
