part of 'container_browser_bloc.dart';

sealed class ContainerBrowserEvent extends Equatable {
  const ContainerBrowserEvent();

  @override
  List<Object?> get props => const [];
}

/// Loads the level, on open and on a retry.
final class ContainerBrowserRequested extends ContainerBrowserEvent {
  const ContainerBrowserRequested();
}

/// Reads the level afresh from a pull to refresh, keeping it on screen while Studio answers.
final class ContainerBrowserRefreshed extends ContainerBrowserEvent {
  const ContainerBrowserRefreshed();
}

/// A statement may have changed the connection's schema, and its kept answers are gone: the level loads again.
final class _ContainerBrowserSchemaChanged extends ContainerBrowserEvent {
  const _ContainerBrowserSchemaChanged();
}
