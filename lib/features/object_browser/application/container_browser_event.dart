part of 'container_browser_bloc.dart';

sealed class ContainerBrowserEvent extends Equatable {
  const ContainerBrowserEvent();

  @override
  List<Object?> get props => const [];
}

/// An event that reads the level, each one cancelling the read before it.
sealed class ContainerBrowserLoadEvent extends ContainerBrowserEvent {
  const ContainerBrowserLoadEvent();
}

/// Loads the level, on open and on a retry.
final class ContainerBrowserRequested extends ContainerBrowserLoadEvent {
  const ContainerBrowserRequested();
}

/// Reads the level afresh from a pull to refresh, keeping it on screen while Studio answers.
final class ContainerBrowserRefreshed extends ContainerBrowserLoadEvent {
  const ContainerBrowserRefreshed();
}

/// A statement may have changed the connection's schema, and its kept answers are gone: the level loads again.
final class _ContainerBrowserSchemaChanged extends ContainerBrowserLoadEvent {
  const _ContainerBrowserSchemaChanged();
}

/// The user typed into the level's filter; it narrows the containers on screen and never sends a request.
final class ContainerBrowserFilterChanged extends ContainerBrowserEvent {
  const ContainerBrowserFilterChanged(this.query);

  final String query;

  @override
  List<Object?> get props => [query];
}
