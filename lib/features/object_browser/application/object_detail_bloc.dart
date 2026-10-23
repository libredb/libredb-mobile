import 'dart:async';

import 'package:clock/clock.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/core/logging/app_logger.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/object_browser/domain/entities/database_object.dart';
import 'package:libredb_mobile/features/object_browser/domain/entities/object_detail.dart';
import 'package:libredb_mobile/features/object_browser/domain/repositories/object_browser_repository.dart';
import 'package:libredb_mobile/shared/models/provider_meta.dart';
import 'package:libredb_mobile/shared/models/provider_meta_repository.dart';
import 'package:libredb_mobile/shared/utils/event_transformers.dart';

part 'object_detail_event.dart';
part 'object_detail_state.dart';

/// The detail of the object at [path] of [connectionId], of [kind]: its columns, indexes, foreign keys and exclusion
/// constraints, through the cached repositories.
///
/// A foreign key names only a table, so its target is looked up in the lists of the object's container, kind by kind
/// among the kinds with columns, until each name is found; a name that no list holds, or that two objects carry,
/// stays unresolved and is never turned into a guessed path. PostgreSQL qualifies `referencedTable` as `schema.table`
/// whenever the referenced schema is not `public`, even within the same schema (Studio's `postgres.ts`), so such a
/// key stays unresolved. A list Studio refuses leaves its names unresolved and is kept as
/// [ObjectDetailLoaded.foreignKeyLookupError], so the page says the links were not checked; it does not fail the
/// detail, which is already read. A pull to refresh takes the cache's refresh path for the
/// describe, and a schema change of the connection loads the detail again.
class ObjectDetailBloc extends Bloc<ObjectDetailEvent, ObjectDetailState> {
  ObjectDetailBloc({
    required this._repository,
    required this._providerMeta,
    required this.connectionId,
    required this.path,
    required this.kind,
    Stream<String> schemaChanges = const Stream.empty(),
  }) : super(const ObjectDetailLoading()) {
    on<ObjectDetailEvent>(_onLoad, transformer: EventTransformers.restart());
    _schemaChanges = schemaChanges
        .where((id) => id == connectionId)
        .listen((_) => add(const _ObjectDetailSchemaChanged()));
  }

  static final _log = AppLogger.getLogger('ObjectDetailBloc');

  final IObjectBrowserRepository _repository;
  final IProviderMetaRepository _providerMeta;

  /// The connection, from the page's route.
  final String connectionId;

  /// The object's path, from the page's route.
  final List<String> path;

  /// The object's kind id, from the page's route.
  final String kind;

  late final StreamSubscription<String> _schemaChanges;

  Future<void> _onLoad(ObjectDetailEvent event, Emitter<ObjectDetailState> emit) async {
    final onScreen = switch (state) {
      final ObjectDetailLoaded loaded => loaded,
      ObjectDetailFailure(:final previous) => previous,
      ObjectDetailLoading() => null,
    };
    if (onScreen != null) {
      emit(_copy(onScreen, isRefreshing: true));
    } else if (state is! ObjectDetailLoading) {
      emit(const ObjectDetailLoading());
    }

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

    final described = await _repository.describe(
      connectionId,
      path: path,
      kind: kind,
      refresh: event is ObjectDetailRefreshed,
    );
    if (emit.isDone) return;
    switch (described) {
      case Failure(:final error):
        _fail(error, onScreen, emit);
      case Success(data: final detail):
        final (targets, lookupError) = await _foreignKeyTargets(providerMeta, detail);
        if (emit.isDone) return;
        emit(
          ObjectDetailLoaded(
            meta: providerMeta,
            detail: detail,
            kind: _kindOf(providerMeta),
            foreignKeyTargets: targets,
            foreignKeyLookupError: lookupError,
            loadedAt: clock.now(),
          ),
        );
    }
  }

  ObjectKind? _kindOf(ProviderMeta meta) {
    for (final declared in meta.objectKinds) {
      if (declared.id == kind) return declared;
    }
    _log.info('provider-meta does not declare the kind of the route');
    return null;
  }

  Future<(Map<String, DatabaseObject>, AppError?)> _foreignKeyTargets(ProviderMeta meta, ObjectDetail detail) async {
    final wanted = {for (final key in detail.foreignKeys) key.referencedTable};
    final found = <String, DatabaseObject>{};
    AppError? refused;
    final container = path.isEmpty ? const <String>[] : path.sublist(0, path.length - 1);
    for (final declared in meta.objectKinds) {
      if (wanted.isEmpty) break;
      if (!declared.hasColumns || declared.keyBrowserOnly || declared.attachedTo != null) continue;
      final listed = await _repository.list(connectionId, container: container, kind: declared.id, refresh: false);
      switch (listed) {
        case Failure(:final error):
          _log.warn('a foreign key\'s table was not looked up in a list: {}', [error.code ?? error.runtimeType]);
          refused ??= error;
        case Success(:final data):
          for (final name in wanted.toList()) {
            final named = data.where((object) => object.name == name).toList();
            if (named.isEmpty) continue;
            wanted.remove(name);
            if (named.length == 1) found[name] = named.single;
          }
      }
    }
    return (found, refused);
  }

  void _fail(AppError error, ObjectDetailLoaded? onScreen, Emitter<ObjectDetailState> emit) {
    _log.warn('detail not read: {}', [error.code ?? error.runtimeType]);
    // A request the offline device never sent says nothing new, so the detail on screen stays, marked stale.
    if (onScreen != null && error.code == AppErrorCode.networkOffline.key) {
      emit(_copy(onScreen));
      return;
    }
    emit(ObjectDetailFailure(error: error, previous: onScreen == null ? null : _copy(onScreen)));
  }

  static ObjectDetailLoaded _copy(ObjectDetailLoaded loaded, {bool isRefreshing = false}) => ObjectDetailLoaded(
    meta: loaded.meta,
    detail: loaded.detail,
    kind: loaded.kind,
    foreignKeyTargets: loaded.foreignKeyTargets,
    foreignKeyLookupError: loaded.foreignKeyLookupError,
    loadedAt: loaded.loadedAt,
    isRefreshing: isRefreshing,
  );

  @override
  Future<void> close() async {
    await _schemaChanges.cancel();
    return super.close();
  }
}
