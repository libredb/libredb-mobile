import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:libredb_mobile/core/logging/app_logger.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/object_browser/domain/entities/object_source.dart';
import 'package:libredb_mobile/features/object_browser/domain/repositories/object_browser_repository.dart';
import 'package:libredb_mobile/shared/utils/event_transformers.dart';

part 'object_source_event.dart';
part 'object_source_state.dart';

/// The definition of the object at [path] of [connectionId], of [kind].
///
/// Source is never kept: each open and each retry reads it from Studio. Nothing here logs its text.
class ObjectSourceBloc extends Bloc<ObjectSourceEvent, ObjectSourceState> {
  ObjectSourceBloc({required this._repository, required this.connectionId, required this.path, required this.kind})
    : super(const ObjectSourceLoading()) {
    on<ObjectSourceRequested>(_onRequested, transformer: EventTransformers.restart());
  }

  static final _log = AppLogger.getLogger('ObjectSourceBloc');

  final IObjectBrowserRepository _repository;

  /// The connection, from the page's route.
  final String connectionId;

  /// The object's path, from the page's route.
  final List<String> path;

  /// The object's kind id, from the page's route.
  final String kind;

  Future<void> _onRequested(ObjectSourceRequested event, Emitter<ObjectSourceState> emit) async {
    if (state is! ObjectSourceLoading) emit(const ObjectSourceLoading());
    final result = await _repository.source(connectionId, path: path, kind: kind);
    if (emit.isDone) return;
    switch (result) {
      case Success(:final data):
        emit(ObjectSourceLoaded(data));
      case Failure(:final error):
        _log.warn('source not read: {}', [error.code ?? error.runtimeType]);
        emit(ObjectSourceFailure(error));
    }
  }
}
