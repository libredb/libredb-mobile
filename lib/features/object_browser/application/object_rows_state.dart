part of 'object_rows_bloc.dart';

sealed class ObjectRowsState extends Equatable {
  const ObjectRowsState();

  @override
  List<Object?> get props => const [];
}

final class ObjectRowsLoading extends ObjectRowsState {
  const ObjectRowsLoading();
}

/// The generator writes no preview for this object on this engine, so nothing ran.
final class ObjectRowsUnavailable extends ObjectRowsState {
  const ObjectRowsUnavailable({required this.meta, required this.kind});

  final ProviderMeta meta;
  final ObjectKind kind;

  @override
  List<Object?> get props => [meta, kind];
}

/// The preview's first page, masked.
final class ObjectRowsLoaded extends ObjectRowsState {
  const ObjectRowsLoaded({
    required this.meta,
    required this.kind,
    required this.preview,
    required this.masked,
    required this.policy,
    required this.loadedAt,
    required this.run,
    this.isRefreshing = false,
  });

  final ProviderMeta meta;
  final ObjectKind kind;

  /// The statement that ran and its catalog; it has no ORDER BY, so a later page may not follow the first's order.
  final PreviewStatement preview;

  /// The answer, masked by [policy].
  final MaskedResult masked;

  /// The policy [masked] was masked with, for the result view and every later page.
  final MaskingPolicy policy;

  /// When the rows were read; offline, the page shows them as what was loaded at this time.
  final DateTime loadedAt;

  /// Which run answered, counted from one, so the page shows each answer as a result of its own.
  final int run;

  final bool isRefreshing;

  ObjectRowsLoaded copyWith({required bool isRefreshing}) => ObjectRowsLoaded(
    meta: meta,
    kind: kind,
    preview: preview,
    masked: masked,
    policy: policy,
    loadedAt: loadedAt,
    run: run,
    isRefreshing: isRefreshing,
  );

  @override
  List<Object?> get props => [meta, kind, preview, masked, policy, loadedAt, run, isRefreshing];
}

/// The preview could not be read.
///
/// [error] is shown by the Browse failure view, and for `studio.query_error` the database's own words under it, on
/// screen only. [meta] and [kind] are kept once read, so the heading still offers the count; [previous] is what was
/// shown before a refresh that failed, which stays on screen under the error.
final class ObjectRowsFailure extends ObjectRowsState {
  const ObjectRowsFailure({required this.error, this.meta, this.kind, this.previous});

  final AppError error;
  final ProviderMeta? meta;
  final ObjectKind? kind;
  final ObjectRowsLoaded? previous;

  @override
  List<Object?> get props => [error, meta, kind, previous];
}
