import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:libredb_mobile/core/logging/app_logger.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/shared/active_connection/active_catalog_cubit.dart';
import 'package:libredb_mobile/shared/active_connection/default_catalog.dart';
import 'package:libredb_mobile/shared/models/containers_repository.dart';
import 'package:libredb_mobile/shared/models/provider_meta.dart';
import 'package:libredb_mobile/shared/models/provider_meta_repository.dart';
import 'package:libredb_mobile/shared/utils/event_transformers.dart';

part 'editor_catalog_event.dart';
part 'editor_catalog_state.dart';

/// The databases the SQL editor offers to run in on [connectionId] when it is a server-level connection
/// (`catalogSessions`), read through the shared containers interface, so Browse's kept answer serves it.
///
/// Once listed, it makes the default the active database of [ActiveCatalogCubit], as Studio's web does on opening: the
/// one chosen in this session, else the one remembered on the device, while the server still lists it, else the first
/// listed. Studio refuses a statement on a server-level connection that names no database, so Run waits for one.
class EditorCatalogBloc extends Bloc<EditorCatalogEvent, EditorCatalogState> {
  EditorCatalogBloc({
    required this._containers,
    required this._providerMeta,
    required this._activeCatalog,
    required this.connectionId,
  }) : super(const EditorCatalogChecking()) {
    on<EditorCatalogRequested>(_onRequested, transformer: EventTransformers.dropConcurrent());
  }

  static final _log = AppLogger.getLogger('EditorCatalogBloc');

  final IContainersRepository _containers;
  final IProviderMetaRepository _providerMeta;
  final ActiveCatalogCubit _activeCatalog;

  /// The connection, the active one the editor was built for.
  final String connectionId;

  Future<void> _onRequested(EditorCatalogRequested event, Emitter<EditorCatalogState> emit) async {
    final ProviderMeta meta;
    switch (await _providerMeta.providerMeta(connectionId)) {
      case Failure(:final error):
        _log.warn('provider meta not read: {}', [error.code ?? error.runtimeType]);
        emit(EditorCatalogFailure(error: error));
        return;
      case Success(:final data):
        meta = data;
    }
    if (!meta.catalogSessions) {
      emit(const EditorCatalogNotUsed());
      return;
    }
    final label = meta.containerLevels.isEmpty ? null : meta.containerLevels.first.label;
    emit(EditorCatalogLoading(label: label));
    switch (await _containers.containers(connectionId)) {
      case Failure(:final error):
        _log.warn('databases not listed: {}', [error.code ?? error.runtimeType]);
        emit(EditorCatalogFailure(error: error, label: label));
      case Success(:final data):
        final listed = [for (final container in data.value) container.name];
        final wanted = _activeCatalog.catalogOf(connectionId) ?? await _activeCatalog.remembered(connectionId);
        if (isClosed) return;
        final chosen = defaultCatalog(listed: listed, wanted: wanted);
        if (chosen != null) _activeCatalog.choose(connectionId, chosen);
        emit(EditorCatalogListed(label: label, catalogs: listed));
    }
  }
}
