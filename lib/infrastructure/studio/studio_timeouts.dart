import 'package:libredb_mobile/shared/models/studio_connection.dart';

/// How long the app waits for the answer of a Studio request that runs a statement or reaches a database host:
/// `/db/query` and `/db/transaction` on a connection without its own query timeout ([ConnectionQueryTimeouts]),
/// `/db/profile`, `/db/monitoring`, `/db/maintenance` and `/db/test-connection`. `/db/multi-query` waits without a
/// limit, because Studio gives each statement of a script its own timeout.
///
/// Studio lets a statement run for 60 seconds by default (`DEFAULT_QUERY_TIMEOUT` in libredb-studio
/// `src/lib/db/types.ts`) and cancels a run whose request is aborted (`src/lib/api/abort-cancel.ts`), so a phone that
/// gave up sooner would both fail and kill a statement Studio was still allowed to finish. The 15 second margin
/// ([studioStatementMargin]) covers Studio's own work around the statement and the network. Every other request keeps
/// `ApiClient`'s 30 seconds.
const Duration studioStatementReceiveTimeout = Duration(seconds: 60 + 15);

/// What the app waits beyond Studio's query timeout for the answer of a statement, as in
/// [studioStatementReceiveTimeout].
const Duration studioStatementMargin = Duration(seconds: 15);

/// The query timeout Studio sent for each managed connection, which `/db/query` and `/db/transaction` wait for.
///
/// `IConnectionRepository.listManaged` replaces it with every list it reads, and the statement repositories read it,
/// so no caller passes a timeout. A connection allowed 120 seconds waits 135; one Studio sent none for, or one the last
/// list did not name, waits [studioStatementReceiveTimeout]. It holds no secret and is never written to disk.
class ConnectionQueryTimeouts {
  Map<String, Duration> _byId = const {};

  /// Keeps the query timeout of each of [connections] and forgets every other.
  void replaceAll(Iterable<StudioConnection> connections) {
    _byId = {for (final connection in connections) connection.id: ?connection.queryTimeout};
  }

  /// How long a statement on [connectionId] is waited for: its query timeout plus [studioStatementMargin].
  Duration statementReceiveTimeout(String connectionId) => switch (_byId[connectionId]) {
    final timeout? => timeout + studioStatementMargin,
    null => studioStatementReceiveTimeout,
  };
}

/// How long the app waits to connect to Studio and for the answer of `GET /api/health` and `GET /api/ready`.
///
/// Both answer from Studio's memory and touch no database, so a Studio that has not answered in 10 seconds is treated
/// as unreachable rather than kept waiting for the 30 seconds of an ordinary request. The probes are sent once, without
/// the client's retries, so this is the whole wait of one check.
const Duration studioProbeTimeout = Duration(seconds: 10);
