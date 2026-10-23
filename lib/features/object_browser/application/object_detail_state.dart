part of 'object_detail_bloc.dart';

sealed class ObjectDetailState extends Equatable {
  const ObjectDetailState();

  @override
  List<Object?> get props => const [];
}

final class ObjectDetailLoading extends ObjectDetailState {
  const ObjectDetailLoading();
}

/// The object's columns, indexes, foreign keys and exclusion constraints.
final class ObjectDetailLoaded extends ObjectDetailState {
  const ObjectDetailLoaded({
    required this.detail,
    this.kind,
    required this.foreignKeyTargets,
    required this.loadedAt,
    this.isRefreshing = false,
  });

  final ObjectDetail detail;

  /// The object's kind as the engine declares it; null when provider-meta does not name the route's kind.
  final ObjectKind? kind;

  /// The object each foreign key's `referencedTable` names, by that name: one object of a kind with columns, of that
  /// name, in the same container. A name that is missing here has no such object and shows as text.
  final Map<String, DatabaseObject> foreignKeyTargets;

  /// When the detail was read; offline, the page shows it as what was loaded at this time.
  final DateTime loadedAt;

  final bool isRefreshing;

  @override
  List<Object?> get props => [detail, kind, foreignKeyTargets, loadedAt, isRefreshing];
}

/// The detail could not be read.
///
/// [error] is shown by the Browse failure view, from its code; [previous] is what was shown before a refresh that
/// failed, which stays on screen under the error.
final class ObjectDetailFailure extends ObjectDetailState {
  const ObjectDetailFailure({required this.error, this.previous});

  final AppError error;
  final ObjectDetailLoaded? previous;

  @override
  List<Object?> get props => [error, previous];
}
