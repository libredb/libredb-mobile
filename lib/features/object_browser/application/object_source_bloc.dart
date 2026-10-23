import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:libredb_mobile/core/logging/app_logger.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/object_browser/domain/entities/object_source.dart';
import 'package:libredb_mobile/features/object_browser/domain/repositories/object_browser_repository.dart';
import 'package:libredb_mobile/shared/models/provider_meta_repository.dart';
import 'package:libredb_mobile/shared/utils/event_transformers.dart';

part 'object_source_event.dart';
part 'object_source_state.dart';

/// The definition of the object at [path] of [connectionId], of [kind].
///
/// Source is never kept: each open and each retry reads it from Studio. Nothing here logs its text. Whether the object
/// also has a detail to open comes from its kind in the cached provider-meta.
class ObjectSourceBloc extends Bloc<ObjectSourceEvent, ObjectSourceState> {
  ObjectSourceBloc({
    required this._repository,
    required this._providerMeta,
    required this.connectionId,
    required this.path,
    required this.kind,
  }) : super(const ObjectSourceLoading()) {
    on<ObjectSourceRequested>(_onRequested, transformer: EventTransformers.restart());
  }

  static final _log = AppLogger.getLogger('ObjectSourceBloc');

  final IObjectBrowserRepository _repository;
  final IProviderMetaRepository _providerMeta;

  /// The connection, from the page's route.
  final String connectionId;

  /// The object's path, from the page's route.
  final List<String> path;

  /// The object's kind id, from the page's route.
  final String kind;

  Future<void> _onRequested(ObjectSourceRequested event, Emitter<ObjectSourceState> emit) async {
    if (state is! ObjectSourceLoading) emit(const ObjectSourceLoading());
    final meta = await _providerMeta.providerMeta(connectionId);
    if (emit.isDone) return;
    final bool hasDetails;
    switch (meta) {
      case Failure(:final error):
        _fail(error, emit);
        return;
      case Success(:final data):
        hasDetails = data.objectKinds.any((declared) => declared.id == kind && declared.hasColumns);
    }
    final result = await _repository.source(connectionId, path: path, kind: kind);
    if (emit.isDone) return;
    switch (result) {
      case Success(:final data):
        emit(ObjectSourceLoaded(data, hasDetails: hasDetails));
      case Failure(:final error):
        _fail(error, emit, hasDetails: hasDetails);
    }
  }

  void _fail(AppError error, Emitter<ObjectSourceState> emit, {bool hasDetails = false}) {
    _log.warn('source not read: {}', [error.code ?? error.runtimeType]);
    emit(ObjectSourceFailure(error, hasDetails: hasDetails));
  }
}
