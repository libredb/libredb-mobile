part of 'object_source_bloc.dart';

sealed class ObjectSourceEvent extends Equatable {
  const ObjectSourceEvent();

  @override
  List<Object?> get props => const [];
}

/// Reads the source, on open and on a retry.
final class ObjectSourceRequested extends ObjectSourceEvent {
  const ObjectSourceRequested();
}
