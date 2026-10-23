part of 'object_search_bloc.dart';

sealed class ObjectSearchEvent extends Equatable {
  const ObjectSearchEvent();

  @override
  List<Object?> get props => const [];
}

/// Opens the search: reads provider-meta, on open and on a retry after it failed.
final class ObjectSearchStarted extends ObjectSearchEvent {
  const ObjectSearchStarted();
}

/// An event that carries the term as the field holds it, each one cancelling the search before it.
sealed class ObjectSearchTermEvent extends ObjectSearchEvent {
  const ObjectSearchTermEvent(this.term);

  final String term;

  @override
  List<Object?> get props => [term];
}

/// The user typed; the search waits for a pause before it is sent.
final class ObjectSearchTermChanged extends ObjectSearchTermEvent {
  const ObjectSearchTermChanged(super.term);
}

/// The user submitted the term from the keyboard, or asked to send a failed search again; it is sent at once.
final class ObjectSearchSubmitted extends ObjectSearchTermEvent {
  const ObjectSearchSubmitted(super.term);
}

/// A request of the search: the one event stream that sends a search or clears the screen, each one replacing the
/// request before it.
sealed class _ObjectSearchRequest extends ObjectSearchEvent {
  const _ObjectSearchRequest();
}

/// Sends a search for [term], the [generation]th request.
final class _ObjectSearchSent extends _ObjectSearchRequest {
  const _ObjectSearchSent(this.term, this.generation);

  final String term;
  final int generation;

  @override
  List<Object?> get props => [term, generation];
}

/// The term became too short to search: the screen waits for a term again.
final class _ObjectSearchCleared extends _ObjectSearchRequest {
  const _ObjectSearchCleared();
}
