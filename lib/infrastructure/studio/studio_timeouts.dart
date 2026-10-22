/// How long the app waits for the answer of a Studio request that runs a statement or reaches a database host:
/// `/db/query`, `/db/multi-query`, `/db/transaction`, `/db/profile`, `/db/monitoring`, `/db/maintenance` and
/// `/db/test-connection`.
///
/// Studio lets a statement run for 60 seconds by default (`DEFAULT_QUERY_TIMEOUT` in libredb-studio
/// `src/lib/db/types.ts`) and cancels a run whose request is aborted (`src/lib/api/abort-cancel.ts`), so a phone that
/// gave up sooner would both fail and kill a statement Studio was still allowed to finish. The 15 second margin covers
/// Studio's own work around the statement and the network. Every other request keeps [ApiClient]'s 30 seconds.
const Duration studioStatementReceiveTimeout = Duration(seconds: 60 + 15);

/// How long the app waits to connect to Studio and for the answer of `GET /api/health` and `GET /api/ready`.
///
/// Both answer from Studio's memory and touch no database, so a Studio that has not answered in 10 seconds is treated
/// as unreachable rather than kept waiting for the 30 seconds of an ordinary request.
const Duration studioProbeTimeout = Duration(seconds: 10);
