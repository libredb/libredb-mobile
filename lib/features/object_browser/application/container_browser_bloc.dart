import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/core/logging/app_logger.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/object_browser/application/session_default_entry.dart';
import 'package:libredb_mobile/features/object_browser/domain/entities/answered.dart';
import 'package:libredb_mobile/features/object_browser/domain/entities/object_container.dart';
import 'package:libredb_mobile/features/object_browser/domain/repositories/object_browser_repository.dart';
import 'package:libredb_mobile/shared/models/provider_meta.dart';
import 'package:libredb_mobile/shared/models/provider_meta_repository.dart';
import 'package:libredb_mobile/shared/utils/event_transformers.dart';
import 'package:libredb_mobile/shared/utils/search_fold.dart';

part 'container_browser_event.dart';
part 'container_browser_state.dart';

/// One level of a connection's containers: the top level, or the level under [parent].
///
/// It reads through the cached repositories, so going back and forth spends none of the user's Studio request budget;
/// a pull to refresh takes the cache's refresh path. A schema change of the connection, which already dropped its kept
/// answers, loads the level again. Offline, a refresh that cannot reach Studio leaves the level on screen.
class ContainerBrowserBloc extends Bloc<ContainerBrowserEvent, ContainerBrowserState> {
  ContainerBrowserBloc({
    required this._repository,
    required this._providerMeta,
    required this.connectionId,
    this.parent = const [],
    Stream<String> schemaChanges = const Stream.empty(),
    this._entry,
  }) : super(const ContainerBrowserLoading()) {
    on<ContainerBrowserLoadEvent>(_onLoad, transformer: EventTransformers.restart());
    on<ContainerBrowserFilterChanged>(
      _onFilterChanged,
      transformer: EventTransformers.debounceRestartable(filterDebounce),
    );
    _schemaChanges = schemaChanges
        .where((id) => id == connectionId)
        .listen((_) => add(const _ContainerBrowserSchemaChanged()));
  }

  /// How long the filter waits after the last keystroke.
  static const filterDebounce = Duration(milliseconds: 200);

  static final _log = AppLogger.getLogger('ContainerBrowserBloc');

  final IObjectBrowserRepository _repository;
  final IProviderMetaRepository _providerMeta;
  final SessionDefaultEntry? _entry;

  /// The connection, from the page's route.
  final String connectionId;

  /// The container whose children this level lists, empty for the top level.
  final List<String> parent;

  late final StreamSubscription<String> _schemaChanges;

  /// Whether a first answer arrived, after which the level never opens a container by itself.
  bool _answered = false;

  /// The filter as typed, kept across loads so a refresh shows the same narrowing.
  String _query = '';

  Future<void> _onLoad(ContainerBrowserLoadEvent event, Emitter<ContainerBrowserState> emit) async {
    final refresh = event is ContainerBrowserRefreshed;
    final onScreen = switch (state) {
      final ContainerBrowserLoaded loaded => loaded,
      ContainerBrowserFailure(:final previous) => previous,
      ContainerBrowserLoading() || ContainerBrowserNoLevels() => null,
    };
    emit(onScreen == null ? const ContainerBrowserLoading() : _copy(onScreen, isRefreshing: true));

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
    final levels = providerMeta.containerLevels;
    if (levels.isEmpty) {
      emit(ContainerBrowserNoLevels(searchesObjects: providerMeta.searchesObjects));
      return;
    }
    if (parent.length >= levels.length) {
      // A route that names a container at the last level, or deeper, has no level under it to list.
      _log.warn('no container level under a parent of depth {} for {} levels', [parent.length, levels.length]);
      _fail(const ValidationError('No container level under this parent'), onScreen, emit);
      return;
    }

    final result = await _repository.containers(connectionId, parent: parent.isEmpty ? null : parent, refresh: refresh);
    if (emit.isDone) return;
    switch (result) {
      case Failure(:final error):
        _fail(error, onScreen, emit);
      case Success(data: Answered(value: final data, :final at)):
        // An empty level shows no filter field, so a filter kept from before would hide what a later refresh brings.
        if (data.isEmpty) _query = '';
        final first = !_answered;
        _answered = true;
        emit(
          ContainerBrowserLoaded(
            level: levels[parent.length],
            depth: levels.length,
            containers: data,
            loadedAt: at,
            openOnEntry: first && event is ContainerBrowserRequested ? _entry?.take(connectionId, parent, data) : null,
            query: _query,
            searchesObjects: providerMeta.searchesObjects,
          ),
        );
    }
  }

  void _onFilterChanged(ContainerBrowserFilterChanged event, Emitter<ContainerBrowserState> emit) {
    _query = event.query;
    switch (state) {
      case final ContainerBrowserLoaded loaded:
        emit(_copy(loaded, isRefreshing: loaded.isRefreshing));
      case ContainerBrowserFailure(:final error, :final previous?):
        emit(ContainerBrowserFailure(error: error, previous: _copy(previous)));
      case ContainerBrowserFailure() || ContainerBrowserLoading() || ContainerBrowserNoLevels():
        break;
    }
  }

  void _fail(AppError error, ContainerBrowserLoaded? onScreen, Emitter<ContainerBrowserState> emit) {
    _log.warn('level not read: {}', [error.code ?? error.runtimeType]);
    // A request the offline device never sent says nothing new, so the level on screen stays, marked stale by the page.
    if (onScreen != null && error.code == AppErrorCode.networkOffline.key) {
      emit(_copy(onScreen, isRefreshing: false));
      return;
    }
    emit(ContainerBrowserFailure(error: error, previous: onScreen == null ? null : _copy(onScreen)));
  }

  /// [loaded] with the filter as it is now.
  ContainerBrowserLoaded _copy(ContainerBrowserLoaded loaded, {bool isRefreshing = false}) => ContainerBrowserLoaded(
    level: loaded.level,
    depth: loaded.depth,
    containers: loaded.containers,
    loadedAt: loaded.loadedAt,
    isRefreshing: isRefreshing,
    query: _query,
    searchesObjects: loaded.searchesObjects,
  );

  @override
  Future<void> close() async {
    await _schemaChanges.cancel();
    return super.close();
  }
}
