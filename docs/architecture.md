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
| `lib/features/auth/` | Sign-in through Keycloak (the `oidc` mode, [oidc.md](oidc.md)) and `StudioIdentityRepository` for `GET /api/auth/me` |
| `lib/features/connections/` | The managed connections, the connection policy and the connection test |
| `lib/features/object_browser/` | Capabilities, containers, counts, objects, details, source, search and key scan |
| `lib/features/sql_editor/` | Statements, scripts, cancel and transactions |
| `lib/features/lifecycle/` | The maintenance and forced update check at start ([below](#maintenance-and-forced-updates)) |
| `lib/shared/models/studio_identity.dart` | Who Studio says the user is, with Studio's role, used across features |
| `lib/infrastructure/studio/` | What every Studio request shares: the error mapping and the session rule |
| `lib/infrastructure/http/` | `ApiClient` and its interceptor chain (auth, token refresh, retry, cache, logging, mock), described in [http-client.md](http-client.md) |

Each repository returns a `Result`: the entity, or an `AppError` with a translated `AppErrorCode`.
The readers in each feature's `data/models/` turn Studio's JSON into entities, throw a `FormatException` when a required field is missing, and leave out an optional field of an unexpected type, so a newer Studio that adds fields reads as before.

In mock mode (`main_local.dart`) `MockInterceptor` answers every request from `assets/mock/`, and `test/architecture/mock_asset_coverage_test.dart` fails when a repository method has no recorded answer.

### Maintenance and forced updates

At start the app reads `GET /app/config` under `PROD_API_URL`, an endpoint that needs no session (mock: `assets/mock/GET_app_config.json`).
Studio has no `/api/app/config` today, so against a real Studio the check fails open on every start and logs an error; only the mock answers it.
`LifecycleGate` (`lib/features/lifecycle/`) sits in the `MaterialApp` builder, around the session restore and the router, and shows a full-screen page in their place when the answer asks for one.

- `maintenanceMode: true` shows the maintenance page with the answer's `maintenanceMessage` (or a translated default), the `maintenanceEstimatedEnd` time in the user's language and time zone, and a retry button.
- A `minimumVersion` above the installed version shows the update page, which opens the `storeUrl` when it is an https link.
- The app checks again when it comes back to the foreground, at most once every 5 minutes (`LifecycleBloc.defaultRecheckInterval`).
- The check fails open: when the endpoint is missing or the request fails, the app opens normally and logs the failure as an error.
  An untrusted certificate is reported with `AppErrorCode.networkCertInvalid`.
  A failed re-check keeps a maintenance or update page the server already asked for, so a server error or a lost connection does not let the user skip a required update.
- A non-empty `featureFlags` map in the answer replaces the flags in `FeatureFlagService`.

## Sessions

1. "Sign in with SSO" runs the authorization code flow with PKCE in a Custom Tab (Android) or `ASWebAuthenticationSession` (iOS).
   The tokens go to the platform's secure storage.
2. `AuthInterceptor` adds the access token to every request as `Authorization: Bearer`.
3. When Studio refuses the token, `TokenRefreshInterceptor` refreshes it at Keycloak once and repeats the request; if that does not help, the session ends.
4. Logout ends the Keycloak session (RP-initiated logout) and deletes the app's tokens.
   Once [#18](https://github.com/libredb/libredb-mobile/issues/18) lands, the app first posts `POST /api/auth/logout`, so Studio writes a logout line in its audit trail as it does for a web sign-out.
   That revokes nothing: Studio keeps no state for a bearer session.

Which 401 starts a refresh is Studio's rule, in `isStudioSessionExpired`:

| Studio answers | The app |
| --- | --- |
| 401 `AUTH_REQUIRED` | refreshes the token and repeats the request once |
| 401 without a code (`/api/auth/me`'s `{"authenticated":false}`) | the same |
| 401 `AUTH_ERROR` (the database refused its credential) | shows the error; the session stays |
| 401 `LLM_AUTH` | the same; the AI routes are not used |
| 503 `IDENTITY_PROVIDER_UNAVAILABLE` | shows the error; the token stays |

`GET /api/auth/me` answers 401 without a code both for a refused token and when Studio cannot reach Keycloak, so a 401 there does not prove the session is over.
Today `TokenRefreshInterceptor` ends the session when the request still answers 401 after a refresh, whatever the code.
The rule [#12](https://github.com/libredb/libredb-mobile/issues/12) implements:

- A 401 without a code that comes back after a successful refresh leaves the session alone; the error reaches the screen, which offers a retry.
- A 401 `AUTH_REQUIRED` that comes back after a successful refresh ends the session, because Studio refused a token Keycloak has just issued.
- A refresh that Keycloak refuses ends the session, as before.

## Talking to Studio

Every request follows these rules:

- The base URL is `PROD_API_URL`, Studio's origin plus `/api`; the repositories use paths such as `/connections/managed`.
- Every `POST` sends `Content-Type: application/json` and no `Origin` header, which is how Studio's CSRF check lets a native client through.
- A managed connection is named in the body as `{"connectionId": "seed:<id>"}`, never inline; the app never sends or stores database credentials.
- Nothing that runs a statement is retried on its own: a statement may have changed data.
- The app waits 30 seconds for an answer, and 75 seconds (`studioStatementReceiveTimeout`) for the routes that run a statement or reach a database host: `/db/query`, `/db/multi-query`, `/db/transaction`, `/db/profile`, `/db/monitoring`, `/db/maintenance` and `/db/test-connection`.
  That is Studio's default statement timeout of 60 seconds plus a margin, because Studio cancels a run whose request the phone gives up on.
- Most `/api/db/*` requests spend a slot of the user's `query` request budget, 120 per minute by default, shared with the same user's Studio sessions in the browser: the object browser caches metadata per connection.
  See [Rate limit](#rate-limit) for which requests do.
- Requests stay well under 10 MiB, above which Studio truncates the body and reads it as malformed.

| Studio endpoint | Repository method | Answer |
| --- | --- | --- |
| `GET /api/auth/me` | `IStudioIdentityRepository.fetch` | `StudioIdentity` |
| `GET /api/connections/managed` | `IConnectionRepository.listManaged` | `List<StudioConnection>` |
| `GET /api/connections/policy` | `IConnectionRepository.fetchPolicy` | `ConnectionPolicy` |
| `POST /api/db/test-connection` | `IConnectionRepository.test` | `ConnectionTestResult` |
| `POST /api/db/provider-meta` | `IObjectBrowserRepository.providerMeta` | `ProviderMeta` |
| `POST /api/db/objects/containers` | `IObjectBrowserRepository.containers` | `List<ObjectContainer>` |
| `POST /api/db/objects/counts` | `IObjectBrowserRepository.counts` | `Map<String, KindCount>` |
| `POST /api/db/objects/list` | `IObjectBrowserRepository.list` | `List<DatabaseObject>` |
| `POST /api/db/objects/describe` | `IObjectBrowserRepository.describe` | `ObjectDetail` |
| `POST /api/db/objects/source` | `IObjectBrowserRepository.source` | `ObjectSource` |
| `POST /api/db/objects/search` | `IObjectBrowserRepository.search` | `List<DatabaseObject>` |
| `POST /api/db/keys/scan` | `IObjectBrowserRepository.scanKeys` | `KeyScanPage` |
| `POST /api/db/query` | `ISqlEditorRepository.run` | `QueryResult` |
| `POST /api/db/multi-query` | `ISqlEditorRepository.runScript` | `ScriptResult` |
| `POST /api/db/cancel` | `ISqlEditorRepository.cancel` | whether the engine stopped the run |
| `POST /api/db/transaction` | `beginTransaction`, `runInTransaction`, `commit`, `rollback`, `transactionStatus` | the state of the transaction |

### Rate limit

Studio counts requests per user in buckets, per Studio process (`src/lib/api/rate-limit.ts`).

- These spend no slot: `GET /api/connections/managed`, `GET /api/connections/policy`, `GET /api/auth/me`, `POST /api/auth/logout`, `GET /api/health`, `GET /api/ready` and `GET /api/db/health`.
- `POST /api/db/health`, `POST /api/db/provider-meta`, every other `/api/db/*` route, the object routes under `/api/db/objects` and the storage routes spend the shared `query` bucket.
  S-13, drafted for Studio and not filed yet, asks Studio to stop charging `provider-meta`.
- A refused request answers 429 with `Retry-After`, which reaches the caller as `studio.rate_limited`.

### The object tree

`provider-meta` describes the engine: how many container levels it has (none, a schema, or a database and its schemas), their names in the engine's words, and its object kinds.
Kind ids such as `table` or `collection` are opaque: their labels come from Studio, never from the app, so a new engine needs no app change.
The tree is containers, then `counts` for a container, then `list` for one kind, then `describe` or `source` for one object, as each kind's `hasColumns` and `hasSource` allow.
The object routes carry no `catalog` field: on a server-level connection the catalog is `container[0]` or `path[0]` (`src/app/api/db/objects/list/route.ts`).
Only the routes that run statements or read a connection's state take a `catalog` body field: query, multi-query, transaction, profile, monitoring, maintenance and its preview, `POST /api/db/health` and pool statistics.
Key-value engines page their keys with `scanKeys` until the cursor is `0`.

### Statements

- `run` sends one statement, with an optional page, bind values and a run id.
  Studio pages a SELECT only when it adds the row bound itself; `QueryPage.after` asks for the next page, and `pagination.hasMore` says whether there is one.
- `runScript` sends several statements, which Studio splits and runs in order, stopping at the first failure.
  It answers 200 even then, so a failed statement is part of the `ScriptResult`, not an error; it takes no bind values and has no paging.
  Deciding whether a text holds one statement or several is the editor's job (milestone M5).
- `cancel` stops a run by the id the app gave it, from `newQueryId`, a UUID: Studio checks no owner on a cancel, so the id must be unguessable.
  The cancelled run fails with `studio.query_cancelled`.
- A transaction's statements cannot be cancelled.
  Without governance Studio keeps one transaction per connection for every user of it, owned by the account that began it, and refuses others with `studio.transaction_not_owned` for up to five idle minutes.

### Errors

Studio's error body is `{error, code?, ...}`.
`ApiClient` keeps the HTTP status, the code, the `Retry-After` delay and the scrubbed `error` text on the exception, and `studioError` maps them, the code first and the status after:

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
| `RATE_LIMITED`, any 429 | `studio.rate_limited`, as a `RateLimitedError` with the delay |
| `TRANSACTION_NOT_OWNED` | `studio.transaction_not_owned` |
| `TRANSACTION_CREDENTIAL_CHANGED` | `studio.transaction_credential_changed` |
| an answer the app cannot read | `studio.unreadable_answer` |

A screen shows the translated message of the code.
The SQL editor also shows the database's own words, the `message` of the error, because a syntax error is what the user needs to read there.

## Governance

When Platform governs Studio, `fetchPolicy` answers `governance: true`, and:

- the connection list is the user's unexpired grants, for admins too;
- a connection that is not granted answers `studio.connection_not_available`;
- Studio answers `studio.governance_unavailable` while it cannot serve its copy of the grants, which the app shows as such, never as an empty list;
- every statement is recorded for Platform's audit log, which the app tells the user through the policy's `statementCapture`;
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

- Studio's `/api/auth/me` cannot tell a refused token from an unreachable identity provider (both 401).
- Studio refuses an access token that carries `nonce`; Keycloak 26.8.1 does not put it there, which the walkthrough in [studio.md](studio.md) confirmed.
- Studio cancels a run when its request is aborted (`src/lib/api/abort-cancel.ts`, used by `src/lib/api/editor-query.ts:135` and `src/app/api/db/multi-query/route.ts:297`).
  So a client receive timeout shorter than Studio's query timeout kills the statement on the server ([#15](https://github.com/libredb/libredb-mobile/issues/15)), and so may the app going to the background during a run (M5-09, in [#33](https://github.com/libredb/libredb-mobile/issues/33)).
  Whether a dropped mobile connection behind a proxy aborts the request is not verified until M5-03 (in [#33](https://github.com/libredb/libredb-mobile/issues/33)) does; the editor cancels explicitly.
- Granting a connection needs an API in Platform that does not exist yet (milestone M9).
- Native Sentry events and breadcrumbs on iOS are not scrubbed ([crash-reporting.md](crash-reporting.md)).
- Studio has no `/api/app/config`, so maintenance mode, forced updates and remote feature flags work only against the mock (milestone M6).

## Open questions

- Governance revocation: Studio compares the token's `iat` with the subject's `revoked_before` (`src/lib/local-accounts.ts:445-449, 479-484`).
  The app's token refresh produces a newer `iat`, so a refreshed token passes again unless Platform also ends the Keycloak session or revokes its refresh tokens.
