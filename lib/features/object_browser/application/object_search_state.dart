part of 'object_search_bloc.dart';

sealed class ObjectSearchState extends Equatable {
  const ObjectSearchState();

  /// The connection's provider-meta once read, null before and when it could not be read.
  ProviderMeta? get meta => null;

  @override
  List<Object?> get props => const [];
}

/// Provider-meta is being read.
final class ObjectSearchPreparing extends ObjectSearchState {
  const ObjectSearchPreparing();
}

/// A server-level connection, which Studio does not search.
final class ObjectSearchNotAvailable extends ObjectSearchState {
  const ObjectSearchNotAvailable();
}

/// Waiting for a term long enough to search.
final class ObjectSearchIdle extends ObjectSearchState {
  const ObjectSearchIdle({required this.meta});

  @override
  final ProviderMeta meta;

  @override
  List<Object?> get props => [meta];
}

/// A search for [term] was sent.
final class ObjectSearchSearching extends ObjectSearchState {
  const ObjectSearchSearching({required this.meta, required this.term});

  @override
  final ProviderMeta meta;

  /// The term as sent, trimmed.
  final String term;

  @override
  List<Object?> get props => [meta, term];
}

/// What Studio found for [term], grouped by container path; empty when nothing matched.
final class ObjectSearchResults extends ObjectSearchState {
  const ObjectSearchResults({required this.meta, required this.term, required this.groups});

  @override
  final ProviderMeta meta;
  final String term;
  final List<ObjectSearchGroup> groups;

  @override
  List<Object?> get props => [meta, term, groups];
}

/// Provider-meta or the search could not be read.
///
/// [error] is shown by `StudioErrorBanner`, which shows the generic message for a 400 without a code: Studio refuses a
/// search over too many places with one, as it does a blank term or an undeclared kind, so the screen cannot tell
/// them apart and never reads Studio's English message to guess. [meta] is null when provider-meta failed, so a retry
/// starts again; else [term] is the search to send again.
final class ObjectSearchFailure extends ObjectSearchState {
  const ObjectSearchFailure({required this.error, this.meta, this.term});

  final AppError error;

  @override
  final ProviderMeta? meta;
  final String? term;

  @override
  List<Object?> get props => [error, meta, term];
}

/// The matches in one container, such as a schema; [container] is empty on an engine with no container level.
final class ObjectSearchGroup extends Equatable {
  const ObjectSearchGroup({required this.container, required this.matches});

  final List<String> container;
  final List<ObjectSearchMatch> matches;

  @override
  List<Object?> get props => [container, matches];
}

/// One match, with its [kind] as the engine declares it, null for a kind the engine does not declare.
final class ObjectSearchMatch extends Equatable {
  const ObjectSearchMatch({required this.object, required this.kind});

  final DatabaseObject object;
  final ObjectKind? kind;

  @override
  List<Object?> get props => [object, kind];
}
