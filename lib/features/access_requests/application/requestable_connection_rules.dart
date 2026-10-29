import 'package:libredb_mobile/features/access_requests/domain/entities/requestable_connection.dart';

/// Why no level of a connection can be asked for.
enum ConnectionBlock {
  /// The user already has an open request for it.
  pending,

  /// The user already holds the highest level they could ask for.
  alreadyGranted,
}

/// The levels Platform knows: `read` and `write`. Platform's level is an opaque string, so any other held level is
/// read as covering both, which is the safe side: the form then does not offer a request Platform would refuse.
const accessLevelRead = 'read';
const accessLevelWrite = 'write';

/// What the request form lets the user ask for on a connection.
extension RequestableConnectionRules on RequestableConnection {
  /// Whether [level] can be asked for: nothing is open, the level is not held yet, and write needs the install's write
  /// credential. Platform decides in the end; this only keeps the form from offering what it would refuse.
  bool canAskFor(String level) {
    if (pendingRequestId != null) return false;
    final held = access?.level;
    return switch (level) {
      accessLevelRead => held == null,
      accessLevelWrite => hasWriteCredential && held != accessLevelWrite && (held == null || held == accessLevelRead),
      _ => false,
    };
  }

  /// Why the whole connection is closed to a request, or null when some level is open.
  ConnectionBlock? get blockedBy {
    if (pendingRequestId != null) return ConnectionBlock.pending;
    if (canAskFor(accessLevelRead) || canAskFor(accessLevelWrite)) return null;
    return access == null ? null : ConnectionBlock.alreadyGranted;
  }
}
