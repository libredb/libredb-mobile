part of 'object_list_bloc.dart';

sealed class ObjectListEvent extends Equatable {
  const ObjectListEvent();

  @override
  List<Object?> get props => const [];
}

/// An event that reads the list, each one cancelling the read before it.
sealed class ObjectListLoadEvent extends ObjectListEvent {
  const ObjectListLoadEvent();
}

/// Loads the list, on open and on a retry.
final class ObjectListRequested extends ObjectListLoadEvent {
  const ObjectListRequested();
}

/// Reads the list afresh from a pull to refresh, keeping it on screen while Studio answers.
final class ObjectListRefreshed extends ObjectListLoadEvent {
  const ObjectListRefreshed();
}

/// A statement may have changed the connection's schema, and its kept answers are gone: the list loads again.
final class _ObjectListSchemaChanged extends ObjectListLoadEvent {
  const _ObjectListSchemaChanged();
}

/// The user typed into the filter; it narrows the list on screen and never sends a request.
final class ObjectListFilterChanged extends ObjectListEvent {
  const ObjectListFilterChanged(this.query);

  final String query;

  @override
  List<Object?> get props => [query];
}
