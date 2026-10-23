part of 'kind_counts_bloc.dart';

sealed class KindCountsEvent extends Equatable {
  const KindCountsEvent();

  @override
  List<Object?> get props => const [];
}

/// Loads the counts, on open and on a retry.
final class KindCountsRequested extends KindCountsEvent {
  const KindCountsRequested();
}

/// Reads the counts afresh from a pull to refresh, keeping them on screen while Studio answers.
final class KindCountsRefreshed extends KindCountsEvent {
  const KindCountsRefreshed();
}

/// A statement may have changed the connection's schema, and its kept answers are gone: the counts load again.
final class _KindCountsSchemaChanged extends KindCountsEvent {
  const _KindCountsSchemaChanged();
}
