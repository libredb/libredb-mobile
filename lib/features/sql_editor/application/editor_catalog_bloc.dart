import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:libredb_mobile/core/logging/app_logger.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/shared/active_connection/active_catalog_cubit.dart';
import 'package:libredb_mobile/shared/active_connection/active_connection_cubit.dart';
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
/// listed. Studio refuses a statement on a server-level connection that names no database, so Run waits for one, and
/// waits until the engine is read.
///
/// A list that answers after [connectionId] stopped being the active connection, or after the session ended, chooses
/// nothing: the editor of the connection being left stays mounted until the next frame.
class EditorCatalogBloc extends Bloc<EditorCatalogEvent, EditorCatalogState> {
  EditorCatalogBloc({
    required this._containers,
    required this._providerMeta,
    required this._activeCatalog,
    required this._activeConnection,
    required this.connectionId,
    required this._onRequestedNotListed,
  }) : super(const EditorCatalogChecking()) {
    on<EditorCatalogRequested>(_onRequested, transformer: EventTransformers.dropConcurrent());
    on<EditorCatalogOpenRequested>(_onOpenRequested);
  }

  static final _log = AppLogger.getLogger('EditorCatalogBloc');

  final IContainersRepository _containers;
  final IProviderMetaRepository _providerMeta;
  final ActiveCatalogCubit _activeCatalog;
  final ActiveConnectionCubit _activeConnection;

  /// The connection, the active one the editor was built for.
  final String connectionId;

  /// Told the database an open request named that the server does not list, and the one used instead, null when
  /// none is.
  final void Function(String requested, String? used) _onRequestedNotListed;

  /// The database an open request named, which the default gives way to while the server lists it.
  String? _requested;

  Future<void> _onRequested(EditorCatalogRequested event, Emitter<EditorCatalogState> emit) async {
    final ProviderMeta meta;
    switch (await _providerMeta.providerMeta(connectionId)) {
      case Failure(:final error):
        _log.warn('provider meta not read: {}', [error.code ?? error.runtimeType]);
        emit(EditorCatalogMetaFailure(error: error));
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
        if (_activeConnection.state.connection?.id != connectionId) {
          // The list answered after the user left this connection or the session ended, while this editor is still
          // mounted: a choice now would make a database of a connection that is not open active, and store it for the
          // next sign-in. The databases are still listed, so the chip shows them if the connection opens again here.
          _requested = null;
          _log.info('the databases were listed after the connection closed, so none is chosen');
          emit(EditorCatalogListed(label: label, catalogs: listed));
          return;
        }
        // An open request that arrived while the databases were read wins over the default.
        final requested = _requested;
        _requested = null;
        final chosen = requested != null && listed.contains(requested)
            ? requested
            : defaultCatalog(listed: listed, wanted: wanted);
        if (chosen != null) _activeCatalog.choose(connectionId, chosen);
        emit(EditorCatalogListed(label: label, catalogs: listed));
        if (requested != null && !listed.contains(requested)) _onRequestedNotListed(requested, chosen);
    }
  }

  void _onOpenRequested(EditorCatalogOpenRequested event, Emitter<EditorCatalogState> emit) {
    switch (state) {
      case EditorCatalogListed(:final catalogs):
        if (catalogs.contains(event.catalog)) {
          _activeCatalog.choose(connectionId, event.catalog);
        } else {
          _onRequestedNotListed(event.catalog, _activeCatalog.catalogOf(connectionId));
        }
      case EditorCatalogNotUsed():
        break;
      case EditorCatalogChecking() || EditorCatalogMetaFailure() || EditorCatalogLoading() || EditorCatalogFailure():
        _requested = event.catalog;
    }
  }
}
