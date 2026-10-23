part of 'object_detail_bloc.dart';

sealed class ObjectDetailEvent extends Equatable {
  const ObjectDetailEvent();

  @override
  List<Object?> get props => const [];
}

/// Describes the object, on open and on a retry.
final class ObjectDetailRequested extends ObjectDetailEvent {
  const ObjectDetailRequested();
}

/// Describes the object afresh from a pull to refresh, keeping the detail on screen while Studio answers.
final class ObjectDetailRefreshed extends ObjectDetailEvent {
  const ObjectDetailRefreshed();
}

/// A statement may have changed the connection's schema, and its kept answers are gone: the detail loads again.
final class _ObjectDetailSchemaChanged extends ObjectDetailEvent {
  const _ObjectDetailSchemaChanged();
}
