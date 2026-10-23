import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/core/logging/app_logger.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/object_browser/domain/entities/answered.dart';
import 'package:libredb_mobile/features/object_browser/domain/entities/database_object.dart';
import 'package:libredb_mobile/features/object_browser/domain/repositories/object_browser_repository.dart';
import 'package:libredb_mobile/shared/models/provider_meta.dart';
import 'package:libredb_mobile/shared/models/provider_meta_repository.dart';
import 'package:libredb_mobile/shared/utils/event_transformers.dart';
import 'package:libredb_mobile/shared/utils/search_fold.dart';

part 'object_list_event.dart';
part 'object_list_state.dart';

/// The objects of one [kind] in [container]: Studio answers a kind whole, with no paging, so the filter narrows the
/// list on screen and never sends a request.
///
/// It reads through the cached repositories, a pull to refresh takes the cache's refresh path, and a schema change of
/// the connection loads the list again. Offline, a refresh that cannot reach Studio leaves the list on screen.
class ObjectListBloc extends Bloc<ObjectListEvent, ObjectListState> {
  ObjectListBloc({
    required this._repository,
    required this._providerMeta,
    required this.connectionId,
    required this.container,
    required this.kind,
    Stream<String> schemaChanges = const Stream.empty(),
  }) : super(const ObjectListLoading()) {
    on<ObjectListLoadEvent>(_onLoad, transformer: EventTransformers.restart());
    on<ObjectListFilterChanged>(_onFilterChanged, transformer: EventTransformers.debounceRestartable(filterDebounce));
    _schemaChanges = schemaChanges
        .where((id) => id == connectionId)
        .listen((_) => add(const _ObjectListSchemaChanged()));
  }

  /// How long the filter waits after the last keystroke.
  static const filterDebounce = Duration(milliseconds: 200);

  static final _log = AppLogger.getLogger('ObjectListBloc');

  final IObjectBrowserRepository _repository;
  final IProviderMetaRepository _providerMeta;

  /// The connection, from the page's route.
  final String connectionId;

  /// The container's path, empty on an engine with no container level. On a server-level connection its first segment
  /// is the catalog, so no request names one apart.
  final List<String> container;

  /// The kind's id, opaque.
  final String kind;

  late final StreamSubscription<String> _schemaChanges;

  /// The filter as typed, kept across loads so a refresh shows the same narrowing.
  String _query = '';

  /// The folded name of each object of the list on screen, by index, so a keystroke folds nothing again.
  List<String> _foldedNames = const [];

  Future<void> _onLoad(ObjectListLoadEvent event, Emitter<ObjectListState> emit) async {
    final onScreen = switch (state) {
      final ObjectListLoaded loaded => loaded,
      ObjectListFailure(:final previous) => previous,
      ObjectListLoading() => null,
    };
    emit(onScreen == null ? const ObjectListLoading() : _copy(onScreen, isRefreshing: true));

    final meta = await _providerMeta.providerMeta(connectionId);
    if (emit.isDone) return;
    final ProviderMeta providerMeta;
    switch (meta) {
      case Failure(:final error):
        _fail(error, onScreen, emit);
        return;
      case Success(:final data):
        providerMeta = data;
    }
    final declared = _kindOf(providerMeta, kind);
    if (declared == null) {
      _log.warn('the engine declares no kind of the route\'s id');
      _fail(const ValidationError('The engine declares no such object kind'), onScreen, emit);
      return;
    }

    final result = await _repository.list(
      connectionId,
      container: container,
      kind: kind,
      refresh: event is ObjectListRefreshed,
    );
    if (emit.isDone) return;
    switch (result) {
      case Failure(:final error):
        _fail(error, onScreen, emit);
      case Success(data: Answered(value: final data, :final at)):
        // An empty kind shows no filter field, so a filter kept from before would hide what a later refresh brings.
        if (data.isEmpty) _query = '';
        _foldedNames = [for (final object in data) foldForSearch(object.name)];
        emit(
          ObjectListLoaded(
            meta: providerMeta,
            kind: declared,
            childKindLabels: _childKindLabels(providerMeta, declared),
            objects: data,
            visible: _visible(data),
            query: _query,
            loadedAt: at,
          ),
        );
    }
  }

  void _onFilterChanged(ObjectListFilterChanged event, Emitter<ObjectListState> emit) {
    _query = event.query;
    switch (state) {
      case final ObjectListLoaded loaded:
        emit(_copy(loaded, isRefreshing: loaded.isRefreshing));
      case ObjectListFailure(:final error, :final previous?):
        emit(ObjectListFailure(error: error, previous: _copy(previous)));
      case ObjectListFailure() || ObjectListLoading():
        break;
    }
  }

  /// The objects of [objects] whose name holds the filter, compared by the shared search fold; the name only, as
  /// Studio's tree filter compares it, never the path.
  List<DatabaseObject> _visible(List<DatabaseObject> objects) {
    final normalized = normalizeSearchQuery(_query);
    if (normalized.isEmpty) return objects;
    return [
      for (var i = 0; i < objects.length; i++)
        if (_foldedNames[i].contains(normalized)) objects[i],
    ];
  }

  /// The plural labels of [kind]'s child kinds. Studio draws no child kind at all, so a child the engine does not
  /// declare is left out rather than shown as its raw id, and logged.
  static List<String> _childKindLabels(ProviderMeta meta, ObjectKind kind) {
    final labels = <String>[];
    for (final child in kind.childKinds) {
      final declared = _kindOf(meta, child);
      if (declared == null) {
        _log.info('child kind {} of kind {} is not declared by the engine', [child, kind.id]);
      } else {
        labels.add(declared.labelPlural);
      }
    }
    return labels;
  }

  static ObjectKind? _kindOf(ProviderMeta meta, String id) {
    for (final kind in meta.objectKinds) {
      if (kind.id == id) return kind;
    }
    return null;
  }

  void _fail(AppError error, ObjectListLoaded? onScreen, Emitter<ObjectListState> emit) {
    _log.warn('list not read: {}', [error.code ?? error.runtimeType]);
    // A request the offline device never sent says nothing new, so the list on screen stays, marked stale by the page.
    if (onScreen != null && error.code == AppErrorCode.networkOffline.key) {
      emit(_copy(onScreen));
      return;
    }
    emit(ObjectListFailure(error: error, previous: onScreen == null ? null : _copy(onScreen)));
  }

  /// [loaded] with the filter as it is now.
  ObjectListLoaded _copy(ObjectListLoaded loaded, {bool isRefreshing = false}) => ObjectListLoaded(
    meta: loaded.meta,
    kind: loaded.kind,
    childKindLabels: loaded.childKindLabels,
    objects: loaded.objects,
    visible: loaded.query == _query ? loaded.visible : _visible(loaded.objects),
    query: _query,
    loadedAt: loaded.loadedAt,
    isRefreshing: isRefreshing,
  );

  @override
  Future<void> close() async {
    await _schemaChanges.cancel();
    return super.close();
  }
}
