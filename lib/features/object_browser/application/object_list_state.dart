part of 'object_list_bloc.dart';

sealed class ObjectListState extends Equatable {
  const ObjectListState();

  @override
  List<Object?> get props => const [];
}

final class ObjectListLoading extends ObjectListState {
  const ObjectListLoading();
}

/// The objects of one kind in a container, and the ones the filter leaves on screen.
final class ObjectListLoaded extends ObjectListState {
  const ObjectListLoaded({
    required this.meta,
    required this.kind,
    required this.childKindLabels,
    required this.objects,
    required this.visible,
    required this.query,
    required this.loadedAt,
    this.isRefreshing = false,
  });

  /// The connection's provider-meta, which decides what a row's View rows offers.
  final ProviderMeta meta;

  /// The kind, as the engine declares it.
  final ObjectKind kind;

  /// The plural labels of the kinds nested under an object of [kind], such as the procedures and functions of an
  /// Oracle package, in the engine's order; empty for a kind with none.
  final List<String> childKindLabels;

  /// Every object Studio listed, in its order.
  final List<DatabaseObject> objects;

  /// The objects whose name the filter matches, all of them while not filtering.
  final List<DatabaseObject> visible;

  /// The filter as typed.
  final String query;

  /// When the list was read; offline, the page shows it as what was loaded at this time.
  final DateTime loadedAt;

  final bool isRefreshing;

  /// Whether [query] filters the list at all; whitespace alone does not.
  bool get isFiltering => normalizeSearchQuery(query).isNotEmpty;

  @override
  List<Object?> get props => [meta, kind, childKindLabels, objects, visible, query, loadedAt, isRefreshing];
}

/// The list could not be read.
///
/// [error] is shown by `StudioErrorBanner`; [previous] is the list shown before a refresh that failed, which stays on
/// screen under the error.
final class ObjectListFailure extends ObjectListState {
  const ObjectListFailure({required this.error, this.previous});

  final AppError error;
  final ObjectListLoaded? previous;

  @override
  List<Object?> get props => [error, previous];
}
