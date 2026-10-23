import 'dart:async';

import 'package:clock/clock.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/core/logging/app_logger.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/object_browser/application/kind_sections.dart';
import 'package:libredb_mobile/features/object_browser/domain/entities/object_container.dart';
import 'package:libredb_mobile/features/object_browser/domain/repositories/object_browser_repository.dart';
import 'package:libredb_mobile/shared/models/provider_meta_repository.dart';
import 'package:libredb_mobile/shared/utils/event_transformers.dart';

part 'kind_counts_event.dart';
part 'kind_counts_state.dart';

/// The kind screen of a container: which kinds of objects [container] holds and how many of each.
///
/// The container's name and the kinds it names come from its level's list, which the cache normally already holds;
/// an engine with no container level counts at the connection itself, with an empty [container]. It reads through the
/// cached repositories, a pull to refresh takes the cache's refresh path for the counts, and a schema change of the
/// connection loads the counts again. Offline, a refresh that cannot reach Studio leaves the counts on screen.
class KindCountsBloc extends Bloc<KindCountsEvent, KindCountsState> {
  KindCountsBloc({
    required this._repository,
    required this._providerMeta,
    required this.connectionId,
    required this.container,
    Stream<String> schemaChanges = const Stream.empty(),
  }) : super(const KindCountsLoading()) {
    on<KindCountsEvent>(_onLoad, transformer: EventTransformers.restart());
    _schemaChanges = schemaChanges
        .where((id) => id == connectionId)
        .listen((_) => add(const _KindCountsSchemaChanged()));
  }

  static final _log = AppLogger.getLogger('KindCountsBloc');

  final IObjectBrowserRepository _repository;
  final IProviderMetaRepository _providerMeta;

  /// The connection, from the page's route.
  final String connectionId;

  /// The container's path, empty on an engine with no container level.
  final List<String> container;

  late final StreamSubscription<String> _schemaChanges;

  Future<void> _onLoad(KindCountsEvent event, Emitter<KindCountsState> emit) async {
    final onScreen = switch (state) {
      final KindCountsLoaded loaded => loaded,
      KindCountsFailure(:final previous) => previous,
      KindCountsLoading() => null,
    };
    emit(onScreen == null ? const KindCountsLoading() : _copy(onScreen, isRefreshing: true));

    final meta = await _providerMeta.providerMeta(connectionId);
    if (emit.isDone) return;
    switch (meta) {
      case Failure(:final error):
        _fail(error, onScreen, emit);
        return;
      case Success(data: final providerMeta):
        ObjectContainer? named;
        String? levelLabel;
        if (container.isNotEmpty) {
          final parent = container.sublist(0, container.length - 1);
          final siblings = await _repository.containers(
            connectionId,
            parent: parent.isEmpty ? null : parent,
            refresh: false,
          );
          if (emit.isDone) return;
          switch (siblings) {
            case Failure(:final error):
              _fail(error, onScreen, emit);
              return;
            case Success(:final data):
              named = _find(data);
          }
          final levels = providerMeta.containerLevels;
          levelLabel = container.length <= levels.length ? levels[container.length - 1].label : null;
        }

        final counts = await _repository.counts(
          connectionId,
          container: container,
          refresh: event is KindCountsRefreshed,
        );
        if (emit.isDone) return;
        switch (counts) {
          case Failure(:final error):
            _fail(error, onScreen, emit);
          case Success(:final data):
            emit(
              KindCountsLoaded(
                container: named,
                levelLabel: levelLabel,
                sections: kindSectionsOf(providerMeta, data, containerKinds: named?.kinds),
                loadedAt: clock.now(),
                browsesKeys: providerMeta.keyScan != null,
              ),
            );
        }
    }
  }

  /// The container in its level's list; when the list no longer names it, a container of that path that holds every
  /// kind, named by its last segment, as a container answered without `kinds` does.
  ObjectContainer _find(List<ObjectContainer> siblings) {
    for (final sibling in siblings) {
      if (listEquals(sibling.path, container)) return sibling;
    }
    _log.info('the container is not in its level\'s list, so every kind of the engine applies');
    return ObjectContainer(path: container, name: container.last, level: container.length - 1);
  }

  void _fail(AppError error, KindCountsLoaded? onScreen, Emitter<KindCountsState> emit) {
    _log.warn('counts not read: {}', [error.code ?? error.runtimeType]);
    // A request the offline device never sent says nothing new, so the counts on screen stay, marked stale by the page.
    if (onScreen != null && error.code == AppErrorCode.networkOffline.key) {
      emit(_copy(onScreen));
      return;
    }
    emit(KindCountsFailure(error: error, previous: onScreen == null ? null : _copy(onScreen)));
  }

  static KindCountsLoaded _copy(KindCountsLoaded loaded, {bool isRefreshing = false}) => KindCountsLoaded(
    container: loaded.container,
    levelLabel: loaded.levelLabel,
    sections: loaded.sections,
    loadedAt: loaded.loadedAt,
    isRefreshing: isRefreshing,
    browsesKeys: loaded.browsesKeys,
  );

  @override
  Future<void> close() async {
    await _schemaChanges.cancel();
    return super.close();
  }
}
