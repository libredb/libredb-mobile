import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:libredb_mobile/core/logging/app_logger.dart';
import 'package:libredb_mobile/shared/active_connection/active_catalog_store.dart';

part 'active_catalog_state.dart';

/// The database statements run in on the active connection when it is a server-level one (`catalogSessions`), as
/// Studio's web keeps one active database per connection.
///
/// Browse makes a database active when the user opens it, and the SQL editor when the user picks one or when it picks
/// the default on opening (`defaultCatalog`). The choice is remembered on the device per signed-in subject and
/// connection, as a convenience only: a stored value that cannot be read means none, and a choice the device refuses to
/// store still applies until the connection switches. A switch to another connection, or a closed one, clears it, and
/// so does the end of the session.
class ActiveCatalogCubit extends Cubit<ActiveCatalogState> {
  ActiveCatalogCubit({required this._store, required Stream<String?> connectionIds})
    : super(const ActiveCatalogNone()) {
    _connectionIds = connectionIds.listen(_connectionChanged);
  }

  static final _log = AppLogger.getLogger('ActiveCatalogCubit');

  final IActiveCatalogStore _store;
  late final StreamSubscription<String?> _connectionIds;

  /// The identity provider's subject of the signed-in user, once Studio named it.
  String? _subject;

  /// The active database of [connectionId], or null when none is active on it.
  String? catalogOf(String connectionId) => switch (state) {
    ActiveCatalogChosen(connectionId: final id, :final catalog) when id == connectionId => catalog,
    ActiveCatalogChosen() || ActiveCatalogNone() => null,
  };

  /// Remembers choices for [subject], who Studio says is signed in; null when Studio names none, and then nothing is
  /// read or stored for the session.
  void signedIn(String? subject) {
    _subject = subject;
    if (subject == null) _log.warn('Studio named no subject, so the active database is not remembered on this device');
  }

  /// Makes [catalog] the active database of [connectionId] and stores it for the signed-in subject.
  void choose(String connectionId, String catalog) {
    if (catalogOf(connectionId) == catalog) return;
    emit(ActiveCatalogChosen(connectionId: connectionId, catalog: catalog));
    unawaited(_persist(connectionId, catalog));
  }

  /// The database stored on this device for the signed-in subject on [connectionId], or null for none, before Studio
  /// named a subject, or when the stored value cannot be read.
  Future<String?> remembered(String connectionId) async {
    final subject = _subject;
    if (subject == null) return null;
    try {
      return await _store.read(subject, connectionId);
    } catch (e) {
      _log.warn('the remembered database was not read: {}', [e.runtimeType]);
      return null;
    }
  }

  /// Forgets the active database and the subject when the session ends; what the device stored stays for the
  /// subject's next sign-in.
  void clear() {
    _subject = null;
    if (state is! ActiveCatalogNone) emit(const ActiveCatalogNone());
  }

  void _connectionChanged(String? connectionId) {
    if (connectionId != null && catalogOf(connectionId) != null) return;
    if (state is! ActiveCatalogNone) emit(const ActiveCatalogNone());
  }

  Future<void> _persist(String connectionId, String catalog) async {
    final subject = _subject;
    if (subject == null) return;
    try {
      await _store.write(subject, connectionId, catalog);
    } catch (e) {
      _log.warn('the active database was not stored, it applies until the connection switches: {}', [e.runtimeType]);
    }
  }

  @override
  Future<void> close() async {
    await _connectionIds.cancel();
    return super.close();
  }
}
