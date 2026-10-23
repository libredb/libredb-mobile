part of 'container_browser_bloc.dart';

sealed class ContainerBrowserState extends Equatable {
  const ContainerBrowserState();

  @override
  List<Object?> get props => const [];
}

final class ContainerBrowserLoading extends ContainerBrowserState {
  const ContainerBrowserLoading();
}

/// The engine nests its objects in no container, as SQLite does, so the connection opens on its kinds.
final class ContainerBrowserNoLevels extends ContainerBrowserState {
  const ContainerBrowserNoLevels({required this.searchesObjects});

  /// [ProviderMeta.searchesObjects] of the engine.
  final bool searchesObjects;

  @override
  List<Object?> get props => [searchesObjects];
}

/// The containers of one level, such as the schemas of a database.
final class ContainerBrowserLoaded extends ContainerBrowserState {
  const ContainerBrowserLoaded({
    required this.level,
    required this.depth,
    required this.containers,
    required this.loadedAt,
    this.isRefreshing = false,
    this.openOnEntry,
    this.query = '',
    required this.searchesObjects,
  });

  /// The level, in the engine's own words.
  final ContainerLevel level;

  /// How many container levels the engine has.
  final int depth;

  final List<ObjectContainer> containers;

  /// When the containers were read; offline, the page shows them as what was loaded at this time.
  final DateTime loadedAt;

  final bool isRefreshing;

  /// The session-default container the page opens by itself, on the first entry of the connection only.
  final ObjectContainer? openOnEntry;

  /// The filter as typed.
  final String query;

  /// [ProviderMeta.searchesObjects] of the engine.
  final bool searchesObjects;

  /// The containers whose name holds [query], compared by the shared search fold; all of them while not filtering.
  List<ObjectContainer> get visibleContainers => [
    for (final container in containers)
      if (matchesSearch(query, [container.name])) container,
  ];

  /// Whether [container] is at the last level, so it opens on its kinds rather than on the level under it.
  bool opensKinds(ObjectContainer container) => container.path.length >= depth;

  @override
  List<Object?> get props => [level, depth, containers, loadedAt, isRefreshing, openOnEntry, query, searchesObjects];
}

/// The level could not be read.
///
/// [error] is shown by `StudioErrorBanner`, from its code; [previous] is the level shown before a refresh that failed,
/// which stays on screen under the error.
final class ContainerBrowserFailure extends ContainerBrowserState {
  const ContainerBrowserFailure({required this.error, this.previous});

  final AppError error;
  final ContainerBrowserLoaded? previous;

  @override
  List<Object?> get props => [error, previous];
}
