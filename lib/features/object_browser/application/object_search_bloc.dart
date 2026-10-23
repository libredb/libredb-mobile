import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:libredb_mobile/core/logging/app_logger.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/object_browser/domain/entities/database_object.dart';
import 'package:libredb_mobile/features/object_browser/domain/repositories/object_browser_repository.dart';
import 'package:libredb_mobile/shared/models/provider_meta.dart';
import 'package:libredb_mobile/shared/models/provider_meta_repository.dart';
import 'package:libredb_mobile/shared/utils/event_transformers.dart';

part 'object_search_event.dart';
part 'object_search_state.dart';

/// A name search across every container of [connectionId], which Studio answers with one walk of the whole catalog,
/// so a search spends a request slot and is sent only on purpose: on a keyboard submit, or once the user stops typing
/// for [debounce], and only for a term of at least [minimumLength] characters.
///
/// A typed term only replaces the wait of the term before it; the search in flight goes on until another request is
/// actually sent, which replaces it, so a late answer to an older term is never shown. A term that is in flight, or on
/// screen with nothing in flight, is never sent again: typing away from it and back within the pause sends nothing,
/// while after a failure the same term is sent again, so Retry works. A term too short to search clears the screen at
/// once. A server-level connection (`catalogSessions`) sends no search at all: Studio refuses a walk over every
/// database of its server. The results live in this bloc only and are never cached.
class ObjectSearchBloc extends Bloc<ObjectSearchEvent, ObjectSearchState> {
  ObjectSearchBloc({required this._repository, required this._providerMeta, required this.connectionId})
    : super(const ObjectSearchPreparing()) {
    on<ObjectSearchStarted>(_onStarted, transformer: EventTransformers.restart());
    on<ObjectSearchTermEvent>(_onTerm);
    on<_ObjectSearchRequest>(_onRequest, transformer: EventTransformers.restart());
  }

  /// How long the search waits after the last keystroke.
  static const debounce = Duration(milliseconds: 400);

  /// The fewest characters of a trimmed term that the search sends.
  static const minimumLength = 2;

  static final _log = AppLogger.getLogger('ObjectSearchBloc');

  final IObjectBrowserRepository _repository;
  final IProviderMetaRepository _providerMeta;

  /// The connection, from the page's route.
  final String connectionId;

  /// The wait of the last typed term.
  Timer? _wait;

  /// The term whose request is in flight, null when none is.
  String? _inFlight;

  /// Counts every request sent and every clearing, so only the answer to the latest request is shown.
  int _generation = 0;

  static String _trimmed(String term) => term.trim();

  static bool _searchable(String term) => _trimmed(term).runes.length >= minimumLength;

  Future<void> _onStarted(ObjectSearchStarted event, Emitter<ObjectSearchState> emit) async {
    if (state is! ObjectSearchPreparing) emit(const ObjectSearchPreparing());
    final result = await _providerMeta.providerMeta(connectionId);
    if (emit.isDone) return;
    switch (result) {
      case Failure(:final error):
        _log.warn('provider-meta not read: {}', [error.code ?? error.runtimeType]);
        emit(ObjectSearchFailure(error: error));
      case Success(:final data) when data.catalogSessions:
        _log.info('search is not offered on a server-level connection');
        emit(const ObjectSearchNotAvailable());
      case Success(:final data):
        emit(ObjectSearchIdle(meta: data));
    }
  }

  void _onTerm(ObjectSearchTermEvent event, Emitter<ObjectSearchState> emit) {
    // No term is taken before provider-meta is read; a server-level connection is ObjectSearchNotAvailable, which
    // holds none, so it never searches.
    if (state.meta == null) return;
    if (!_searchable(event.term)) {
      _cancelWait();
      _generation++;
      _inFlight = null;
      add(const _ObjectSearchCleared());
      return;
    }
    final term = _trimmed(event.term);
    if (_isCurrent(term)) {
      _cancelWait();
      return;
    }
    if (event is ObjectSearchSubmitted) {
      _cancelWait();
      _send(term);
      return;
    }
    _cancelWait();
    _wait = Timer(debounce, () {
      _wait = null;
      if (!isClosed) _send(term);
    });
  }

  /// Whether [term] is the search in flight, or the one on screen while none is.
  bool _isCurrent(String term) {
    final inFlight = _inFlight;
    if (inFlight != null) return inFlight == term;
    return switch (state) {
      ObjectSearchResults(term: final shown) => shown == term,
      _ => false,
    };
  }

  void _send(String term) {
    _generation++;
    _inFlight = term;
    add(_ObjectSearchSent(term, _generation));
  }

  void _cancelWait() {
    _wait?.cancel();
    _wait = null;
  }

  Future<void> _onRequest(_ObjectSearchRequest event, Emitter<ObjectSearchState> emit) async {
    final meta = state.meta;
    if (meta == null) return;
    switch (event) {
      case _ObjectSearchCleared():
        emit(ObjectSearchIdle(meta: meta));
      case _ObjectSearchSent(:final term, :final generation):
        emit(ObjectSearchSearching(meta: meta, term: term));
        final result = await _repository.search(connectionId, term: term);
        if (emit.isDone || generation != _generation) return;
        _inFlight = null;
        switch (result) {
          case Failure(:final error):
            // Only the code: the message of a 400 is Studio's English sentence, never shown nor logged.
            _log.warn('search failed: {}', [error.code ?? error.runtimeType]);
            emit(ObjectSearchFailure(error: error, meta: meta, term: term));
          case Success(:final data):
            emit(ObjectSearchResults(meta: meta, term: term, groups: _group(meta, data)));
        }
    }
  }

  /// [matches] grouped by their container path, the first [ProviderMeta.containerLevels] segments of each path, in the
  /// order Studio lists them, which is container by container.
  static List<ObjectSearchGroup> _group(ProviderMeta meta, List<DatabaseObject> matches) {
    final depth = meta.containerLevels.length;
    final kinds = {for (final kind in meta.objectKinds) kind.id: kind};
    final groups = <String, (List<String>, List<ObjectSearchMatch>)>{};
    for (final object in matches) {
      final container = object.path.take(depth.clamp(0, object.path.length - 1)).toList(growable: false);
      final kind = kinds[object.kind];
      if (kind == null) _log.info('a match of kind {} is not declared by the engine', [object.kind]);
      groups
          .putIfAbsent(_containerKey(container), () => (container, <ObjectSearchMatch>[]))
          .$2
          .add(ObjectSearchMatch(object: object, kind: kind));
    }
    return [
      for (final (container, matches) in groups.values)
        ObjectSearchGroup(container: container, matches: List.unmodifiable(matches)),
    ];
  }

  /// A key that tells container paths apart whatever their names hold, since a name may hold any separator.
  static String _containerKey(List<String> container) => [for (final s in container) '${s.length}:$s'].join();

  @override
  Future<void> close() {
    _cancelWait();
    return super.close();
  }
}
