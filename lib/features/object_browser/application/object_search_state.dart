part of 'object_search_bloc.dart';

sealed class ObjectSearchState extends Equatable {
  const ObjectSearchState();

  /// The connection's provider-meta once read, null before and when it could not be read.
  ProviderMeta? get meta => null;

  /// The ids of the kinds the search is narrowed to, in the order the engine declares them; empty for every kind.
  List<String> get kinds => const [];

  /// The kinds a search can be narrowed to: every kind the engine declares but those only its key browser lists,
  /// which Studio refuses in a search.
  List<ObjectKind> get searchKinds => [
    for (final kind in meta?.objectKinds ?? const <ObjectKind>[])
      if (!kind.keyBrowserOnly) kind,
  ];

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
  const ObjectSearchIdle({required this.meta, this.kinds = const []});

  @override
  final ProviderMeta meta;

  @override
  final List<String> kinds;

  @override
  List<Object?> get props => [meta, kinds];
}

/// A search for [term] was sent.
final class ObjectSearchSearching extends ObjectSearchState {
  const ObjectSearchSearching({required this.meta, required this.term, this.kinds = const []});

  @override
  final ProviderMeta meta;

  /// The term as sent, trimmed.
  final String term;

  @override
  final List<String> kinds;

  @override
  List<Object?> get props => [meta, term, kinds];
}

/// What Studio found for [term], grouped by container path; empty when nothing matched.
final class ObjectSearchResults extends ObjectSearchState {
  const ObjectSearchResults({required this.meta, required this.term, required this.groups, this.kinds = const []});

  @override
  final ProviderMeta meta;
  final String term;
  final List<ObjectSearchGroup> groups;

  @override
  final List<String> kinds;

  @override
  List<Object?> get props => [meta, term, groups, kinds];
}

/// Studio refused the search for [term] because it would walk more container and kind pairs than one search may
/// (`INVENTORY_PAIR_LIMIT`, from Studio 1.1.0): the screen asks the user to pick kinds from [searchKinds], which
/// narrows it.
final class ObjectSearchTooBroad extends ObjectSearchState {
  const ObjectSearchTooBroad({required this.meta, required this.term, this.kinds = const []});

  @override
  final ProviderMeta meta;
  final String term;

  @override
  final List<String> kinds;

  @override
  List<Object?> get props => [meta, term, kinds];
}

/// Provider-meta or the search could not be read.
///
/// [error] is shown by `StudioErrorBanner`, which shows the generic message for a 400 without a code, such as a blank
/// term or an undeclared kind; the screen never reads Studio's English message to guess. A search over too many places
/// is [ObjectSearchTooBroad] instead. [meta] is null when provider-meta failed, so a retry starts again; else [term] is
/// the search to send again.
final class ObjectSearchFailure extends ObjectSearchState {
  const ObjectSearchFailure({required this.error, this.meta, this.term, this.kinds = const []});

  final AppError error;

  @override
  final ProviderMeta? meta;
  final String? term;

  @override
  final List<String> kinds;

  @override
  List<Object?> get props => [error, meta, term, kinds];
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
