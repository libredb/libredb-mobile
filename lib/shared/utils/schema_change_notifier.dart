import 'dart:async';

import 'package:libredb_mobile/core/logging/app_logger.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/shared/models/provider_meta_repository.dart';

/// Tells the object browser that a statement may have changed a connection's schema, as Studio's web tree learns it:
/// the statement matches the engine's `schemaRefreshPattern` (`ProviderMeta.refreshesSchema`).
///
/// The SQL editor's run (`EditorRunBloc`), which runs what the user typed, calls [statementSucceeded] after each
/// successful run; the shared statement repository does not, since a preview, a count and a key read change no schema.
/// A match drops the connection's browser answers through [invalidateConnection] first, and then sends the connection
/// id on [changes], so an open browser screen that reloads reads afresh.
class SchemaChangeNotifier {
  SchemaChangeNotifier({required this._providerMeta, required this.invalidateConnection});

  final IProviderMetaRepository _providerMeta;

  /// Drops the browser answers kept for a connection.
  final void Function(String connectionId) invalidateConnection;

  final _changes = StreamController<String>.broadcast();

  static final _log = AppLogger.getLogger('SchemaChangeNotifier');

  /// The id of each connection whose schema a statement may have changed, after its answers were dropped.
  Stream<String> get changes => _changes.stream;

  /// Whether [statement], which ran without an error on [connectionId], may have changed the schema; when it may, the
  /// connection's browser answers are dropped and [changes] is told.
  ///
  /// The engine's pattern comes from provider-meta. When provider-meta cannot be read, the statement may have changed
  /// the schema all the same, so the connection's answers are dropped and [changes] is told anyway, and the failure,
  /// logged by its code, is returned (#88 item 3, decided in #113): a needless reload costs a request, a stale tree
  /// shows a dropped table.
  Future<Result<bool>> statementSucceeded(String connectionId, String statement) async {
    final meta = await _providerMeta.providerMeta(connectionId);
    switch (meta) {
      case Failure(:final error, :final stackTrace):
        _log.warn('cannot tell whether a statement changed the schema, dropping the connection\'s answers: {}', [
          error.code ?? error.runtimeType,
        ]);
        _changed(connectionId);
        return Failure(error, stackTrace: stackTrace);
      case Success(:final data):
        if (!data.refreshesSchema(statement)) return const Success(false);
        _changed(connectionId);
        return const Success(true);
    }
  }

  void _changed(String connectionId) {
    invalidateConnection(connectionId);
    _changes.add(connectionId);
  }

  Future<void> dispose() => _changes.close();
}
