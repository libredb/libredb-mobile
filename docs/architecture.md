# Architecture

LibreDB Mobile is a thin client of LibreDB Studio.
Studio holds every database credential, opens every database connection and enforces who may use which connection; the app signs the user in, sends requests and shows the answers.
This page describes how the app is put together and the Studio contract it follows.
The contract was read from Studio's code at `dbfea263` (main, with the bearer channel of libredb/libredb-studio#1914); the rate limit, catalog, cancel and revocation notes were checked against main at `02dc2605`.

## The three parties

```text
                 ┌──────────────┐
                 │   Keycloak   │  realm with the clients libredb-studio (web) and libredb-mobile (public)
                 └──────┬───────┘
        sign in (PKCE)  │  verify the access token (JWKS)
           ┌────────────┴────────────┐
           │                         │
 ┌─────────┴─────────┐   bearer   ┌──┴───────────────┐   credentials   ┌───────────┐
 │  LibreDB Mobile   │ ─────────▶ │  LibreDB Studio  │ ──────────────▶ │ Databases │
 │  tokens only      │ ◀───────── │  connections,    │                 └───────────┘
 └───────────────────┘   JSON     │  queries, audit  │
                                  └────────┬─────────┘
                                           │ bridge views (governance mode only)
                                  ┌────────┴─────────┐
                                  │ LibreDB Platform │  grants, revocations, audit log
                                  └──────────────────┘
```

- **Keycloak** signs the user in.
  The app is the public client `libredb-mobile`: authorization code with PKCE, no client secret.
  Its access token carries the audience `libredb-studio-api` and the user's role.
- **Studio** accepts that access token as `Authorization: Bearer` when `OIDC_BEARER_AUDIENCE` is set.
  It checks the signature, the issuer, the audience, the client (`OIDC_BEARER_CLIENT_IDS`), the identity (`email` or `preferred_username`) and the role on every request, and refuses an ID token.
- **Platform**, when present, governs Studio: Studio's connections become the user's grants, every statement is recorded, and Platform can revoke a session.
  The app does not talk to Platform until milestone M9 ([roadmap.md](roadmap.md)).

Settings for each party are in [studio.md](studio.md).

## Inside the app

The app follows the feature-first clean architecture of [feature-first-clean-boundaries.md](feature-first-clean-boundaries.md): a page talks to a BLoC, the BLoC to use cases, the use cases to a repository interface, and the repository implementation to `ApiClient`.

| Place | What it holds |
| --- | --- |
| `lib/features/auth/` | Sign-in through Keycloak, the only sign-in ([oidc.md](oidc.md)), `StudioIdentityRepository` for `GET /api/auth/me` and the sign-out record at `POST /api/auth/logout`, and `StudioIdentityCubit`, which holds Studio's latest answer about the user for the shell and every feature |
| `lib/features/connections/` | The managed connections, the connection policy and the connection test |
| `lib/features/object_browser/` | Containers, counts, objects, details, source, search, key scan, and the rows and row count of an object |
| `lib/features/sql_editor/` | Statements, scripts, cancel and transactions |
| `lib/features/studio_status/` | Studio's liveness and readiness: the unreachable page and the wording of a governance outage ([below](#studio-reachability)) |
| `lib/shared/models/studio_identity.dart` | Who Studio says the user is, with Studio's role as the sealed `StudioRole`: `StudioAdminRole`, `StudioUserRole`, or `StudioUnknownRole` for a role this app does not know, which gets the least the app grants |
| `lib/shared/models/studio_connection.dart` | A connection Studio offers, read by the connection list, the active connection, the object browser and the SQL editor |
| `lib/shared/active_connection/` | `ActiveConnectionCubit`, the one connection Browse and SQL work on, which the top bar's switcher changes and every feature follows; it is remembered on the device per signed-in subject (a SHA-256 of the identity provider's `sub`), opens again only when the first managed list of the session still holds it, and vanishes with the message '<name> is no longer available' when a list no longer holds it or a feature gets `studio.connection_not_available` for it |
| `lib/shared/models/provider_meta.dart` | What the engine of a connection can do (`ProviderMeta`, `ContainerLevel`, `ObjectKind`, `KeyScanSpec`, `ProviderLabels`), read by the connections, the object browser, the SQL editor and the result view |
| `lib/shared/models/provider_meta_repository.dart` | `IProviderMetaRepository`, the one way a feature asks for `ProviderMeta` |
| `lib/shared/models/query_result.dart`, `query_page.dart`, `query_id.dart`, `vector_column.dart` | The shared statement models: `QueryResult` with its `QueryWarning`s and `VectorColumn`s, `appendResultPage` (Load more), `QueryPage` and `QueryPagination`, and `newQueryId`, read by the object browser, the SQL editor and the result view |
| `lib/shared/models/statement_repository.dart` | `IStatementRepository`, the one way a feature runs a statement and reads its `QueryResult` |
| `lib/shared/security/result_masking/` | The port of Studio's default result masking: the patterns, the mask functions, the role rules, `MaskingPolicy` and `maskResult` ([security.md](security.md#result-masking)) |
| `lib/shared/widgets/studio_role_scope.dart` | `StudioRoleScope`, the role Studio named for the user, or null before it has, which `AppShell` provides from `StudioIdentityCubit` so a feature builds its `MaskingPolicy` without importing the auth feature |
| `lib/shared/widgets/result_view/` | The result view of a statement (milestone M4), shared by the SQL editor and the object browser: `ResultViewBloc` holds a result its caller masked and the policy it was masked with, and fetches, masks and appends the next page through the caller's `loadPage` when Studio's grid would offer it; `ResultView` draws a card per row or a lazy table under a stats strip, or an empty state, with Load more under the rows; the card or table choice is a device setting, `ResultViewModeCubit` over `IResultViewModeStore` (`lib/infrastructure/storage/result_view_mode_preferences.dart`) |
| `lib/infrastructure/studio/` | What every Studio request shares: the error mapping, the session rule, `ProviderMetaRepository` with its reader, and `StatementRepository` with its reader `query_result_json.dart` |
| `lib/infrastructure/http/` | `ApiClient` and its interceptor chain (auth, token refresh, retry, cache, logging, mock), described in [http-client.md](http-client.md) |

A model that more than one feature reads lives in `lib/shared/models/`, never in one feature's `domain/`, because a feature must not import another feature's internals (`test/architecture/import_guard_test.dart`).
A repository that answers with such a model has its interface beside the model and its implementation in `lib/infrastructure/studio/`.
A widget that more than one feature shows lives in `lib/shared/widgets/`.

Each repository returns a `Result`: the entity, or an `AppError` with a translated `AppErrorCode`.
The readers in each feature's `data/models/` (and in `lib/infrastructure/studio/` for a shared model) turn Studio's JSON into entities, throw a `FormatException` when a required field is missing, and leave out an optional field of an unexpected type, so a newer Studio that adds fields reads as before.

In mock mode (`main_local.dart`) a debug-only double stands in for Keycloak ([oidc.md](oidc.md#mock-mode-without-keycloak)) and `MockInterceptor` answers every request from `assets/mock/`, and `test/architecture/mock_asset_coverage_test.dart` fails when a repository method has no recorded answer.

### Studio reachability

`StudioStatusGate` (`lib/features/studio_status/`) sits in the `MaterialApp` builder and tells an unreachable Studio apart from a failed sign-in or an expired session.

- `StudioStatusBloc` checks `GET /api/health` when the app starts, without waiting for the session restore, when the user retries, when the app comes back after more than 5 minutes in the background (`StudioStatusBloc.defaultRecheckAfter`), and when the device comes back online.
- A failed check shows the full-screen "Can't reach Studio" page, with the host of `PROD_API_URL` and a Retry, over the session restore and the router.
  They stay mounted underneath, offstage and without tickers, focus or semantics, so the open pages keep their state, unsaved input included.
  It fails on no connection (an offline device fails at once), a timeout of 10 seconds (`studioProbeTimeout`), an untrusted certificate (the page adds why), or an answer that is not Studio's.
  Both probes bypass the client's retries and circuit breaker (`bypassResilience`): one check sends one request, so 10 seconds is the whole wait, and a Retry reaches Studio as soon as it answers again.
- The check never touches the session: a Retry that reaches Studio shows the app again where it was, signed in as before.
  A governance outage shown before Studio stopped answering shows again, until a connection route answers again.
  The app is not held back while the check runs.
- Both endpoints need no session and spend no rate-limit slot, so the app sends them without a token (`publicEndpoints`).
- `GET /api/ready` only chooses the wording of a governance outage, whose trigger is a connection route's own 503 `GOVERNANCE_UNAVAILABLE` (`StudioGovernanceOutageReported`, sent by the connection list through `GovernanceStatus`).
  200 `degraded` and 503 `loading` read as "temporarily unavailable", and 503 `misconfigured` or `incompatible` as "Studio cannot serve connections right now", with Studio's `detail` shown to admins only (`StudioGovernanceNotice`).
  200 `degraded` never reads as healthy: a stale snapshot answers it while every connection route answers 503.
  A readiness that cannot be read still shows the outage, worded as temporary, and is logged.

### Offline

`ConnectivityCubit` (`lib/app/connectivity/`) follows the device's connectivity, and `AppConnectivityScope` passes it to every screen as the shared `OfflineStatus` (`lib/shared/widgets/offline_status.dart`), so a feature reads it without importing the app layer.

- `AppShell` shows a thin offline banner above every tab, which a screen reader announces as a live region.
- `ConnectivityInterceptor` refuses a request that would reach the network while the device is offline, and `studioError` reports it with `AppErrorCode.networkOffline`.
- A screen that holds loaded data keeps it on such a failure instead of showing an error, and `OfflineStaleMarker` shows it as "Offline: showing what was loaded at <time>", with the date before the time when the data was loaded on an earlier day.
  The connection list does this today; the browser levels and the result view follow the same rule.
- A pull to refresh while offline shows the banner's message and sends nothing.
- An action that needs Studio, such as Run or Check, is built with `OnlineOnlyAction`, which disables it offline and shows why.
- When the device comes back online, `OnReconnect` refreshes the visible screen once and, while the unreachable page is up, `AppConnectivityScope` checks Studio's liveness again, so that page clears without a Retry.
  A Studio that was answering is not checked again on reconnect, so one failed probe cannot cover a working screen.

## Sessions

1. "Sign in with SSO" runs the authorization code flow with PKCE in a Custom Tab (Android) or `ASWebAuthenticationSession` (iOS).
   The tokens go to the platform's secure storage.
   The sign-in then calls `GET /api/auth/me` and succeeds only on its 200; any other answer clears the stored tokens and shows why, so an account Studio refuses never opens the app.
   The role comes only from that answer (`StudioIdentity.role`): the app reads no role from a token, maps none and stores none.
2. `AuthInterceptor` adds the access token to every request as `Authorization: Bearer`.
3. When Studio refuses the token, `TokenRefreshInterceptor` refreshes it at Keycloak once and repeats the request.
   The session ends when the refresh fails at Keycloak, or when Studio answers the repeated request with 401 `AUTH_REQUIRED` (`isStudioSessionRefused`).
4. Logout ends the Keycloak session (RP-initiated logout) and deletes the app's tokens.
   Once [#18](https://github.com/libredb/libredb-mobile/issues/18) lands, the app first posts `POST /api/auth/logout`, so Studio writes a logout line in its audit trail as it does for a web sign-out.
   That revokes nothing: Studio keeps no state for a bearer session.

Which 401 starts a refresh is Studio's rule, in `isStudioSessionExpired`, and which 401 after the refresh ends the session is the rule of `isStudioSessionRefused`:

| Studio answers | The app |
| --- | --- |
| 401 `AUTH_REQUIRED` | refreshes the token and repeats the request once; a second 401 `AUTH_REQUIRED` ends the session |
| 401 without a code (`/api/auth/me`'s `{"authenticated":false}`, Studio before libredb-studio#1922) | refreshes the token and repeats the request once; a second 401 without a code shows the error with a retry, and the session stays |
| a failed refresh at Keycloak (expired or revoked refresh token) | ends the session |
| 401 `AUTH_ERROR` (the database refused its credential) | shows the error; the session stays |
| 401 `LLM_AUTH` | the same; the AI routes are not used |
| 503 `IDENTITY_PROVIDER_UNAVAILABLE`, on any route and from libredb-studio#1922 on also on `GET /api/auth/me` | shows the error as transient with the screen's retry; no refresh, the token stays |
| 403 `BEARER_NO_ROLE` or `BEARER_NO_IDENTITY` (from libredb-studio#1922 on) | no refresh, the session stays; signed in, the shell covers every screen with the refusal page, which offers Retry and Logout; at sign-in the sign-in is refused |
| 401 `AUTH_REQUIRED` on `POST /api/auth/logout` (from libredb-studio#1922 on) | refreshes the token and posts the sign-out record again, within the sign-out's 3 seconds; the sign-out goes on either way |

The rule after a refresh ([#12](https://github.com/libredb/libredb-mobile/issues/12)):

- A 401 without a code that comes back after a successful refresh leaves the session alone; the error reaches the screen, which offers a retry.
- A 401 `AUTH_REQUIRED` that comes back after a successful refresh ends the session, because Studio refused a token Keycloak has just issued.
- A refresh that Keycloak refuses ends the session, as before.

## Talking to Studio

Every request follows these rules:

- The base URL is `PROD_API_URL`, Studio's origin plus `/api`; the repositories use paths such as `/connections/managed`.
- Every `POST` sends `Content-Type: application/json` and no `Origin` header, which is how Studio's CSRF check lets a native client through.
- A managed connection is named in the body as `{"connectionId": "seed:<id>"}`, never inline; the app never sends or stores database credentials.
- Nothing that runs a statement is retried on its own: a statement may have changed data.
- The app waits 30 seconds for an answer, and longer for the routes that run a statement or reach a database host, because Studio cancels a run whose request the phone gives up on.
  `/db/query` and `/db/transaction` wait the connection's query timeout plus 15 seconds, `/db/multi-query` waits without a limit, and `/db/profile`, `/db/monitoring`, `/db/maintenance` and `/db/test-connection` wait 75 seconds (`studioStatementReceiveTimeout`), Studio's default statement timeout of 60 seconds plus the margin.
  [Statements](#statements) records why.
- Most `/api/db/*` requests spend a slot of the user's `query` request budget, 120 per minute by default, shared with the same user's Studio sessions in the browser: the object browser caches metadata per connection.
  See [Rate limit](#rate-limit) for which requests do.
- Requests stay well under 10 MiB, above which Studio truncates the body and reads it as malformed.

| Studio endpoint | Repository method | Answer |
| --- | --- | --- |
| `GET /api/auth/me` | `IStudioIdentityRepository.fetch` | `StudioIdentity` |
| `POST /api/auth/logout` | `IStudioIdentityRepository.recordSignOut` | none; Studio only writes its logout audit line |
| `GET /api/health` | `IStudioStatusRepository.liveness` | whether Studio answers |
| `GET /api/ready` | `IStudioStatusRepository.readiness` | `StudioReadiness`, the 503 answers included |
| `GET /api/connections/managed` | `IConnectionRepository.listManaged` | `ManagedConnections` (`StudioConnection` list and `cacheHint`) |
| `GET /api/connections/policy` | `IConnectionRepository.fetchPolicy` | `ConnectionPolicy` |
| `POST /api/db/test-connection` | `IConnectionRepository.test` | `ConnectionTestResult` |
| `POST /api/db/provider-meta` | `IProviderMetaRepository.providerMeta` | `ProviderMeta` |
| `POST /api/db/objects/containers` | `IObjectBrowserRepository.containers` | `List<ObjectContainer>` |
| `POST /api/db/objects/counts` | `IObjectBrowserRepository.counts` | `Map<String, KindCount>` |
| `POST /api/db/objects/list` | `IObjectBrowserRepository.list` | `List<DatabaseObject>` |
| `POST /api/db/objects/describe` | `IObjectBrowserRepository.describe` | `ObjectDetail` |
| `POST /api/db/objects/source` | `IObjectBrowserRepository.source` | `ObjectSource` |
| `POST /api/db/objects/search` | `IObjectBrowserRepository.search` | `List<DatabaseObject>` |
| `POST /api/db/keys/scan` | `IObjectBrowserRepository.scanKeys` | `KeyScanPage` |
| `POST /api/db/query` | `IStatementRepository.run`, which `ISqlEditorRepository.run` calls | `QueryResult` |
| `POST /api/db/multi-query` | `ISqlEditorRepository.runScript` | `ScriptResult` |
| `POST /api/db/cancel` | `ISqlEditorRepository.cancel` | whether the engine stopped the run |
| `POST /api/db/transaction` | `beginTransaction`, `runInTransaction`, `commit`, `rollback`, `transactionStatus` | the state of the transaction; `TransactionEnd` for `commit` and `rollback` |

### Rate limit

Studio counts requests per user in buckets, per Studio process (`src/lib/api/rate-limit.ts`).

- These spend no slot: `GET /api/connections/managed`, `GET /api/connections/policy`, `GET /api/auth/me`, `POST /api/auth/logout`, `GET /api/health`, `GET /api/ready` and `GET /api/db/health`.
- `POST /api/db/health`, `POST /api/db/provider-meta`, every other `/api/db/*` route, the object routes under `/api/db/objects` and the storage routes spend the shared `query` bucket.
  Studio declined S-13, which asked it to stop charging `provider-meta`, so the session-long `CachedProviderMetaRepository` is what keeps that cost down.
- `CachedProviderMetaRepository` keeps each connection's provider-meta in memory for the session, and `CachedObjectBrowserRepository` keeps the containers, counts, lists and describe answers for 10 minutes; source, search and key pages are always read afresh.
  `app_dependencies.dart` hands every feature the cached ones.
  Two callers asking for the same answer while its request is in flight share it, and a failure, a 429 included, is returned without touching the entry that was there.
  A pull to refresh passes `refresh: true`, which reads afresh and replaces the entry.
- `SchemaChangeNotifier.statementSucceeded` drops a connection's browser answers after a statement that matches the engine's `schemaRefreshPattern`, then tells the open screens on `changes`.
  `invalidate` and `invalidateContainer` drop answers on demand, and `evictExpired` drops the answers past their time when the user switches connection.
- Both caches are emptied when the session ends, and an answer still on its way is stored only while the session generation it was sent under has not ended and no invalidation covering it ran since it was sent, so it never refills a cache after a sign-out or brings back a dropped table.
  Nothing is written to disk.
- A refused request answers 429 with `Retry-After`, which reaches the caller as `studio.rate_limited`.
- `POST /api/db/test-connection` spends a slot and opens a connection to the database, so the app checks a connection only when the user taps Check in its details sheet, never on the list or on open, and drops a second tap while a check runs.
  Like Studio, it does not check a connection whose `provider-meta` declares `resumesBilledCompute`, since the check would wake compute the engine bills for, unless the user chooses Check anyway.

### The object tree

`provider-meta` describes the engine: how many container levels it has (none, a schema, or a database and its schemas), their names in the engine's words, and its object kinds.
Kind ids such as `table` or `collection` are opaque: their labels come from Studio, never from the app, so a new engine needs no app change.
Its `labels` give the engine's words for what a screen shows (Collection, document, Find Documents); each is optional in the app, and a screen that finds one missing uses its own translated wording.
`ProviderMeta.refreshesSchema` tests a statement against Studio's `schemaRefreshPattern`, case-insensitively as Studio does, and answers false for a pattern Dart cannot compile.
The tree is containers, then `counts` for a container, then `list` for one kind, then `describe` or `source` for one object, as each kind's `hasColumns` and `hasSource` allow.
The object routes carry no `catalog` field: on a server-level connection the catalog is `container[0]` or `path[0]` (`src/app/api/db/objects/list/route.ts`).
Only the routes that run statements or read a connection's state take a `catalog` body field: query, multi-query, transaction, profile, monitoring, maintenance and its preview, `POST /api/db/health` and pool statistics.
Key-value engines page their keys with `scanKeys` until the cursor is `0`.

### Statements

- `run` sends one statement, with an optional page, bind values and a run id.
  Every feature sends it through `IStatementRepository`, so the app has one `/db/query` call; the SQL editor's `run` delegates to it.
  Studio pages a SELECT only when it adds the row bound itself; `QueryPage.after` asks for the next page, and `pagination.hasMore` says whether there is one.
  `appendResultPage` appends that page to the rows on screen by Studio's own rule (`src/lib/results/append-page.ts`).
  `database`, sent only when set and always as a JSON number, names the numbered database a key was walked in; Studio refuses it with a 400 on an engine that scans no keys, so only a Redis key read sends it.
- The object browser's View rows and Count rows run the statements Studio's own generators write (`generateTableQuery` and `generateCountQuery`), ported to `PreviewStatementGenerator`, through `IStatementRepository`: the preview with a page of 50 rows and no row bound in its text, in the path's `catalog` on a server-level connection, and the count once per tap.
  Neither is ever retried by itself, after a failure or a schema change; only the user's pull, retry or tap runs one again.
  An engine whose preview the app does not write yet (a declared query dialect, `previewProjection`, `previewTimeWindow`, `containerNameSpelling: "engine"`, Couchbase, or a query language other than `sql` and `json`) shows View rows disabled and offers no count.
  The rows page shows the database's own words for `studio.query_error`, as the editor does, on screen only.
- A tap on a key in the key browser follows Studio's `onOpenKey`: an engine with a key-browser kind (etcd's `key`, Firestore's `document`) opens that kind's source for the path `[key]` and runs nothing; Redis runs the read Studio's key browser writes for the type the key's page read, ported to `RedisKeyReadGenerator`, or `TYPE <key>` when the page named none of the seven types it reads.
  The read carries `database` when the walked container is all digits, and a key ending in `:*` is read like any other, where Studio scans it as a prefix group.
  After a `TYPE` answer only the user's 'Read value' runs the typed read; a `(nil)` or `(empty list)` answer with `rowCount: 0`, or `TYPE` answering `none`, says the key no longer exists.
- The fields of a result that report lost or incomplete data (`pagination` with its `wasLimited`, `warnings`, and `openTransaction`, which Studio sends only as `rolled-back`) are read strictly in every reader that builds a `QueryResult`: present but malformed fails the read, so the screen shows a failure instead of hiding that rows or notices are missing.
- `runScript` sends several statements, which Studio splits and runs in order, stopping at the first failure.
  It answers 200 even then, so a failed statement is part of the `ScriptResult`, not an error; it takes no bind values.
  A page given to it is sent as `options` and bounds the last statement when that is a SELECT, but Studio answers no paging for a script, so there is no next page.
  Deciding whether a text holds one statement or several is the editor's job (milestone M5).
- The SQL editor ([#113](https://github.com/libredb/libredb-mobile/issues/113)) sends one statement through `run`, whole, with a fresh run id, and never sends it again by itself.
  A text that `InterimWriteCheck` reads as several statements is refused on the phone with a message to run one at a time, as is a text over 1,000,000 characters, since Studio bounds the text of a console engine only.
  Any other text the check flags runs only after the write confirmation, and so does each Load more of it, because every page runs the whole statement again on Studio; the text sent is the one confirmed.
  A `studio.query_error` shows the database's own words under the editor and places the cursor at `details.position`, which counts characters from 1 and is converted to a UTF-16 offset.
  The rolled-back notice advises the engine's commit keyword, `EXEC` on Redis and `COMMIT` elsewhere, as Studio's web does.
- After a successful statement the editor calls `SchemaChangeNotifier.statementSucceeded`.
  Decided in #113 for [#88](https://github.com/libredb/libredb-mobile/issues/88) item 3: when provider-meta cannot be read after a successful statement, the connection's browser answers are dropped and `changes` is told all the same, and the failure is logged by its code, because a needless reload costs one request while a stale tree shows a table that no longer exists.
- `cancel` stops a run by the id the app gave it, from `newQueryId`, a UUID: Studio checks no owner on a cancel, so the id must be unguessable.
  The cancelled run fails with `studio.query_cancelled`.
- A transaction's statements cannot be cancelled.
  Without governance Studio keeps one transaction per connection for every user of it, owned by the account that began it, and refuses others with `studio.transaction_not_owned` for up to five idle minutes.
  On a server-level connection it keeps one per database, so `commit`, `rollback` and `transactionStatus` name the `catalog` the transaction began in; without it Studio finds no open transaction.
- Studio answers a commit `{"status": "committed"}` and a rollback `{"status": "rolled_back"}`, both 2xx and only after the engine ended the transaction; a commit or rollback the engine refused is an error answer (`src/app/api/db/transaction/route.ts`).
  So a 2xx is a `Success` whatever its body: `TransactionEnd.confirmed` when the body names that end, `TransactionEnd.unreadableAnswer` when it does not, and the transaction is over either way, so the UI never offers Commit again.
  Only a `Failure` leaves the transaction open.

#### Statement timeouts

Studio cancels a statement whose request is aborted (`src/lib/api/abort-cancel.ts`), so a phone that gives up sooner than Studio would both fail and cancel a statement Studio was still allowed to finish.
Decided in [#88](https://github.com/libredb/libredb-mobile/issues/88):
- `/db/query` and `/db/transaction` wait the connection's query timeout plus 15 seconds.
  The managed list carries `queryTimeout` in milliseconds when the connection sets its own or governance sends its runtime setting `query.timeoutMs` (`src/lib/governance/visible.ts:105-106`), and the reader keeps it only when it is a positive number.
  `ConnectionQueryTimeouts` holds the timeouts of the last list read; `IConnectionRepository.listManaged` replaces it and the statement repositories read it, so no caller passes a timeout.
  A connection without one, or one the last list did not name, waits 75 seconds, Studio's default of 60 (`DEFAULT_QUERY_TIMEOUT`, `src/lib/db/types.ts:55`) plus the margin.
- `/db/multi-query` sets no receive timeout (option (b) of #88): Studio gives each statement of a script the connection's query timeout (`src/app/api/db/multi-query/route.ts:335-353`), so a script may run for its statement count times that, which the phone cannot count before Studio's statement analysis (S-06).
  Any finite limit would cut a script Studio may still finish and cancel it through the abort bridge (`:296-297`), leaving its first statements committed and the rest not run; Studio's web sets none either (`appFetch`, `src/lib/config/base-path.ts:144-150`).
  `runScript` sends `receiveTimeout: Duration.zero`, which Dio 5 reads as none, since null would keep the client's 30 seconds.
  Cancel ([#116](https://github.com/libredb/libredb-mobile/issues/116)) and the backgrounding rule ([#118](https://github.com/libredb/libredb-mobile/issues/118)) end a script the user gives up on, and the editor shows the elapsed time while one runs ([#117](https://github.com/libredb/libredb-mobile/issues/117)).
- None of these requests is ever sent twice, and no statement text is logged.

### Errors

Studio's error body is `{error, code?, ...}`.
`ApiClient` keeps the HTTP status, the code, the `Retry-After` delay, the scrubbed `error` text and, on a 400, `details.position` (a whole number or a string of digits, else none) on the exception, and `studioError` maps them, the code first and the status after:

| Studio code | `AppErrorCode` |
| --- | --- |
| `AUTH_REQUIRED` | `auth.invalid_access_token` |
| `AUTH_ERROR` (401) | `studio.database_auth` |
| `AUTH_ERROR` (403), `CONNECTION_NOT_FOUND` | `studio.connection_not_available` |
| `PERMISSION_DENIED` | `studio.permission_denied` |
| `CUSTOM_CONNECTIONS_DISABLED` | `studio.custom_connections_disabled` |
| `QUERY_ERROR` | `studio.query_error` |
| `QUERY_CANCELLED` | `studio.query_cancelled` |
| `CONFIG_ERROR` | `studio.config_error` |
| `TIMEOUT_ERROR` | `studio.timeout` |
| `CONNECTION_ERROR`, `POOL_EXHAUSTED` | `studio.database_unreachable` |
| `GOVERNANCE_UNAVAILABLE`, `AUDIT_UNAVAILABLE` | `studio.governance_unavailable` |
| `IDENTITY_PROVIDER_UNAVAILABLE` | `studio.identity_provider_unavailable` |
| `BEARER_NO_ROLE` (403, from libredb-studio#1922 on) | `studio.account_has_no_role` |
| `BEARER_NO_IDENTITY` (403, from libredb-studio#1922 on) | `studio.account_has_no_identity` |
| `RATE_LIMITED`, any 429 | `studio.rate_limited`, as a `RateLimitedError` with the delay |
| `TRANSACTION_NOT_OWNED` | `studio.transaction_not_owned` |
| `TRANSACTION_CREDENTIAL_CHANGED` | `studio.transaction_credential_changed` |
| any 413, which only a console engine's text bound answers | `studio.statement_too_large` |
| an answer the app cannot read | `studio.unreadable_answer` |

A sign-in that `GET /api/auth/me` refuses with any other `AuthError`, a 401 that reached the caller, shows `studio.account_refused`.
A screen shows the translated message of the code.
The SQL editor and the object browser's rows and key value pages also show the database's own words, the `message` of the error, because a syntax error or a refused read is what the user needs to read there.

## Governance

When Platform governs Studio, `fetchPolicy` answers `governance: true`, and:

- the connection list is the user's unexpired grants, for admins too;
- a connection that is not granted answers `studio.connection_not_available`;
- Studio answers `studio.governance_unavailable` while it cannot serve its copy of the grants, which the app shows as such, never as an empty list;
- every statement is recorded for Platform's audit log, which the app tells the user through the policy's `statementCapture`;
- an empty list says that no database has been granted yet and that an administrator gives access, as Studio's web client does.

The connection list follows grant changes while it is open (`ConnectionListBloc`, [#24](https://github.com/libredb/libredb-mobile/issues/24)):

- It asks for `GET /api/connections/managed` again every `cacheHint`, clamped to 5 to 60 seconds as Studio's web client does, and at once when the app comes back to the foreground, but only while the list is on screen, the app is in the foreground and the device is online.
  Each new list asks for the policy again (`ConnectionPolicyCubit.refresh`), which keeps the policy it had when that fails.
  Neither request spends a rate-limit slot.
- A 503 `GOVERNANCE_UNAVAILABLE` is `ConnectionListUnavailable`: the rows loaded before stay greyed under the outage notice, or the notice covers the page with a Retry on a cold start, and the list asks again every 10 seconds until Studio answers.
  The page reports the outage and its end through the shared `GovernanceStatus`, which `AppShell` backs with `StudioStatusBloc`, so readiness words the notice.
  A retry that fails before it reaches governance, such as a 429, a 503 `IDENTITY_PROVIDER_UNAVAILABLE` or a 500, keeps the rows greyed and the outage, and a 429 makes the next retry wait as long as Studio asked.
  Each page's first list reports governance as answering, so an outage left by a page closed during it ends there.
- Another failure of a refresh, such as a 429 or a 503 `IDENTITY_PROVIDER_UNAVAILABLE`, keeps the rows with `StudioErrorBanner` and the timer running; on a cold start it is the failure page with a Retry.
- An `AuthError`, such as the 403 `BEARER_NO_ROLE`, drops the rows and stops the timer until the user retries, because Studio would refuse and audit every tick the same way.
- While `statementCapture` is `full`, a line under the app bar says that statements are recorded in full in the server's query log.
- each user has their own transactions.

Grants refer to the Keycloak subject, so the app must sign in to the same realm as Studio's web sign-in.

Studio masks sensitive columns in results only in the browser (`src/lib/data-masking.ts`); `POST /api/db/query` answers raw rows.
The app therefore applies the same masking rules before it shows a row (M4-03, in [#32](https://github.com/libredb/libredb-mobile/issues/32)).

## Security

- The phone holds Keycloak tokens in secure storage and nothing else: no database credential, no connection the server does not manage.
- Studio sends the credentials of an unmanaged seed connection in the connection list; the app's reader does not read them.
- The HTTP log carries method, path, status and body length; bodies are logged only in verbose mode, which is off by default, and with secrets masked.
  The repositories never log statement text or database error text.
- Certificate pinning is built in and off; milestone M6 configures it and Sentry for the release build.
  Screen capture protection is built in, and no screen uses it yet.
  [security.md](security.md) describes them, the token storage and the inactivity sign-out, and [crash-reporting.md](crash-reporting.md) what a crash report may carry.

## Known gaps

- Under governance, Studio still refuses a session as 401 when a route cannot read its account registry (`getSession`, `src/lib/auth.ts:81-86` at libredb-studio c9989a6b5), which the app reads as a refused token.
- Studio refuses an access token that carries `nonce`; Keycloak 26.8.1 does not put it there, which the walkthrough in [studio.md](studio.md) confirmed.
- Studio cancels a run when its request is aborted (`src/lib/api/abort-cancel.ts`, used by `src/lib/api/editor-query.ts:135` and `src/app/api/db/multi-query/route.ts:297`).
  So a client receive timeout shorter than Studio's query timeout kills the statement on the server ([#15](https://github.com/libredb/libredb-mobile/issues/15); [Statement timeouts](#statement-timeouts) says how the app avoids it), and so may the app going to the background during a run (M5-09, in [#33](https://github.com/libredb/libredb-mobile/issues/33)).
  Whether a dropped mobile connection behind a proxy aborts the request is not verified until M5-03 (in [#33](https://github.com/libredb/libredb-mobile/issues/33)) does; the editor cancels explicitly.
- Granting a connection needs an API in Platform that does not exist yet (milestone M9).
- Native Sentry events and breadcrumbs on iOS are not scrubbed ([crash-reporting.md](crash-reporting.md)).
- Studio offers no maintenance mode and no minimum app version, so the app has no maintenance or forced update gate; milestone M7 brings the gate back when Studio offers one.

## Open questions

- Governance revocation: Studio compares the token's `iat` with the subject's `revoked_before` (`src/lib/local-accounts.ts:445-449, 479-484`).
  The app's token refresh produces a newer `iat`, so a refreshed token passes again unless Platform also ends the Keycloak session or revokes its refresh tokens.
