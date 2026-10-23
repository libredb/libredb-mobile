part of 'kind_counts_bloc.dart';

sealed class KindCountsState extends Equatable {
  const KindCountsState();

  @override
  List<Object?> get props => const [];
}

final class KindCountsLoading extends KindCountsState {
  const KindCountsLoading();
}

/// The kinds a container holds and how many of each.
final class KindCountsLoaded extends KindCountsState {
  const KindCountsLoaded({
    this.container,
    this.levelLabel,
    required this.sections,
    required this.loadedAt,
    this.isRefreshing = false,
  });

  /// The container, as its level lists it; null on an engine with no container level, whose kinds are the
  /// connection's own.
  final ObjectContainer? container;

  /// What the engine calls the container's level, such as Schema; null with no container level.
  final String? levelLabel;

  final List<KindSection> sections;

  /// When the counts were read; offline, the page shows them as what was loaded at this time.
  final DateTime loadedAt;

  final bool isRefreshing;

  @override
  List<Object?> get props => [container, levelLabel, sections, loadedAt, isRefreshing];
}

/// The counts could not be read.
///
/// [error] is shown by `StudioErrorBanner`, from its code; [previous] is what was shown before a refresh that failed,
/// which stays on screen under the error.
final class KindCountsFailure extends KindCountsState {
  const KindCountsFailure({required this.error, this.previous});

  final AppError error;
  final KindCountsLoaded? previous;

  @override
  List<Object?> get props => [error, previous];
}
