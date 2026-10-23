import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:libredb_mobile/core/logging/app_logger.dart';
import 'package:libredb_mobile/shared/active_connection/active_connection_store.dart';
import 'package:libredb_mobile/shared/models/studio_connection.dart';

part 'active_connection_state.dart';

/// The one connection Browse and SQL work on, which the user switches without going back to the connection list.
///
/// The connection is remembered on the device per signed-in subject, as a convenience only: a stored id that cannot be
/// read means no connection, and a choice the device refuses to store still applies until the session ends. A stored
/// connection opens again only when the first managed list of the session still holds it.
///
/// Every feature that works on the connection follows [stream], or [connectionIds] for the switches alone.
class ActiveConnectionCubit extends Cubit<ActiveConnectionState> {
  ActiveConnectionCubit({required this._store}) : super(const ActiveConnectionNone());

  static final _log = AppLogger.getLogger('ActiveConnectionCubit');

  final IActiveConnectionStore _store;

  /// The identity provider's subject of the signed-in user, once Studio named it.
  String? _subject;

  /// Counts the sessions, so a stored id read for one that has ended is never applied.
  int _session = 0;

  /// Whether a user is signed in for this session, named by Studio or not.
  bool _signedIn = false;

  /// The stored id, once it was read, until the first managed list decides whether it opens.
  String? _storedId;
  bool _storedIdRead = false;

  /// The last managed list Studio answered in this session.
  List<StudioConnection>? _listed;

  /// Whether the stored connection had its one chance to open in this session.
  bool _restoreDone = false;

  /// Whether the user chose a connection in this session, which a stored one read later never replaces.
  bool _chosen = false;

  /// Whether the user chose a connection before Studio named the subject to store it for.
  bool _choiceUnstored = false;

  /// The id of the active connection each time it changes, null when none is open.
  Stream<String?> get connectionIds => stream.map((state) => state.connection?.id).distinct();

  /// Reads the connection stored for [subject], who Studio says is signed in, and opens it once a managed list holds
  /// it. Null when Studio names no subject: nothing is then read or stored for the session.
  Future<void> signedIn(String? subject) async {
    if (_signedIn) return;
    _signedIn = true;
    if (subject == null) {
      _log.warn('Studio named no subject, so the active connection is not remembered on this device');
      _restoreDone = true;
      return;
    }
    _subject = subject;
    if (_choiceUnstored) {
      _choiceUnstored = false;
      final chosen = state.connection;
      if (chosen != null) _persist(chosen.id);
    }
    final session = _session;
    String? stored;
    try {
      stored = await _store.read(subject);
    } catch (e) {
      _log.warn('restore failed, no connection opens: {}', [e.runtimeType]);
    }
    if (isClosed || session != _session) return;
    _storedId = stored;
    _storedIdRead = true;
    _tryRestore();
  }

  /// Opens [connection], the user's choice, and stores it for the signed-in subject.
  void select(StudioConnection connection) {
    _chosen = true;
    emit(ActiveConnectionSelected(connection));
    if (_subject == null) {
      _choiceUnstored = !_signedIn;
      return;
    }
    _persist(connection.id);
  }

  /// The connection [connectionId] names in the last managed list Studio answered in this session, or null when that
  /// list does not hold it or none was answered yet.
  StudioConnection? listed(String connectionId) => switch (_listed) {
    final connections? => _byId(connections, connectionId),
    null => null,
  };

  /// Takes the managed list Studio just answered: the active connection vanishes when the list no longer holds it, and
  /// otherwise takes what Studio now says about it; the first list of a session decides whether the stored one opens.
  void connectionsListed(List<StudioConnection> connections) {
    _listed = connections;
    if (state case ActiveConnectionSelected(:final connection)) {
      final current = _byId(connections, connection.id);
      if (current == null) {
        _vanish(connection);
      } else if (current != connection) {
        emit(ActiveConnectionSelected(current));
      }
    }
    _tryRestore();
  }

  /// A feature got `studio.connection_not_available` for [connectionId]: when it is the active connection, it vanishes.
  void reportUnavailable(String connectionId) {
    if (state case ActiveConnectionSelected(:final connection) when connection.id == connectionId) {
      _vanish(connection);
    }
  }

  /// Closes the connection when the session ends; what the device stored stays for the subject's next sign-in.
  void clear() {
    _session++;
    _signedIn = false;
    _subject = null;
    _storedId = null;
    _storedIdRead = false;
    _listed = null;
    _restoreDone = false;
    _chosen = false;
    _choiceUnstored = false;
    if (state is! ActiveConnectionNone) emit(const ActiveConnectionNone());
  }

  void _tryRestore() {
    final listed = _listed;
    if (_restoreDone || !_storedIdRead || listed == null) return;
    _restoreDone = true;
    final storedId = _storedId;
    _storedId = null;
    if (_chosen || storedId == null) return;
    final stored = _byId(listed, storedId);
    if (stored == null) {
      _log.info('The stored connection is not in the managed list, so none opens');
      return;
    }
    emit(ActiveConnectionSelected(stored));
  }

  void _vanish(StudioConnection connection) {
    _log.info('The active connection {} is no longer available', [connection.id]);
    emit(ActiveConnectionVanished(connection));
    if (_subject != null) _persist(null);
  }

  Future<void> _persist(String? connectionId) async {
    final subject = _subject;
    if (subject == null) return;
    try {
      await _store.write(subject, connectionId);
    } catch (e) {
      _log.warn('the active connection was not stored, it applies until the session ends: {}', [e.runtimeType]);
    }
  }

  static StudioConnection? _byId(List<StudioConnection> connections, String id) {
    for (final connection in connections) {
      if (connection.id == id) return connection;
    }
    return null;
  }
}
