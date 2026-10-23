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
import 'package:stream_transform/stream_transform.dart';

part 'object_search_event.dart';
part 'object_search_state.dart';

/// A name search across every container of [connectionId], which Studio answers with one walk of the whole catalog,
/// so a search spends a request slot and is sent only on purpose: on a keyboard submit, or once the user stops typing
/// for [debounce], and only for a term of at least [minimumLength] characters.
///
/// Every new term cancels the wait and the search before it, so typing fast sends at most one request per pause and a
/// late answer to an older term is never shown. A server-level connection (`catalogSessions`) sends no search at all:
/// Studio refuses a walk over every database of its server. The results live in this bloc only and are never cached.
class ObjectSearchBloc extends Bloc<ObjectSearchEvent, ObjectSearchState> {
  ObjectSearchBloc({required this._repository, required this._providerMeta, required this.connectionId})
    : super(const ObjectSearchPreparing()) {
    on<ObjectSearchStarted>(_onStarted, transformer: EventTransformers.restart());
    on<ObjectSearchTermEvent>(_onTerm, transformer: _debounceTyping);
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

  /// Restartable over every term event: a typed term long enough to search waits [debounce] first, while a submit and
  /// a term too short to search act at once, and each event cancels the wait or the search of the one before it.
  static Stream<ObjectSearchTermEvent> _debounceTyping(
    Stream<ObjectSearchTermEvent> events,
    Stream<ObjectSearchTermEvent> Function(ObjectSearchTermEvent) mapper,
  ) => events.switchMap((event) {
    final waits = event is ObjectSearchTermChanged && _searchable(event.term);
    return waits ? _after(debounce, event).switchMap(mapper) : mapper(event);
  });

  /// [event] once [delay] has passed, with the timer cancelled when the listener goes, so a dropped wait leaves no
  /// timer behind.
  ///
  /// The cancel answers a future of the current zone, which `switchMap` awaits before it listens to the next wait: a
  /// plain callback would hand it the root zone's completed future, whose continuation a test's fake clock never runs.
  static Stream<E> _after<E>(Duration delay, E event) {
    Timer? timer;
    late final StreamController<E> controller;
    controller = StreamController<E>(
      onListen: () => timer = Timer(delay, () {
        controller.add(event);
        unawaited(controller.close());
      }),
      onCancel: () async => timer?.cancel(),
    );
    return controller.stream;
  }

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

  Future<void> _onTerm(ObjectSearchTermEvent event, Emitter<ObjectSearchState> emit) async {
    final meta = state.meta;
    // No term is taken before provider-meta says the connection can be searched.
    if (meta == null || meta.catalogSessions) return;
    if (!_searchable(event.term)) {
      emit(ObjectSearchIdle(meta: meta));
      return;
    }
    final term = _trimmed(event.term);
    emit(ObjectSearchSearching(meta: meta, term: term));
    final result = await _repository.search(connectionId, term: term);
    if (emit.isDone) return;
    switch (result) {
      case Failure(:final error):
        // Only the code: the message of a 400 is Studio's English sentence, never shown nor logged.
        _log.warn('search failed: {}', [error.code ?? error.runtimeType]);
        emit(ObjectSearchFailure(error: error, meta: meta, term: term));
      case Success(:final data):
        emit(ObjectSearchResults(meta: meta, term: term, groups: _group(meta, data)));
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
}
