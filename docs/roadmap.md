# Roadmap

LibreDB Mobile is a native client for LibreDB Studio on Android and iOS.
It signs in through Keycloak and works with the databases Studio offers the user: browse them, look inside them, and run SQL.
Studio stays the only place that holds credentials and talks to the databases; the phone holds a Keycloak session and nothing else.

The order below follows what a user needs first.
Each milestone ends with a working app on Android and iOS, verified against a real Studio (see [studio.md](studio.md)).
How the app talks to Studio is in [architecture.md](architecture.md).

## Status

| Milestone | Status |
| --- | --- |
| M0 Foundation | Done |
| M1 Studio API layer | Done |
| M2 Connection list | Planned |
| M3 Object browser | Planned |
| M4 SQL editor | Planned |
| M5 Grant a connection (admin) | Planned, needs Platform v1 |
| M6 Release | Planned |

## M0 Foundation

Done in libredb/libredb-mobile#1, with libredb/libredb-studio#1914 and libredb/libredb-platform#22.

- The app identity is `org.libredb.mobile` on Android and iOS.
- Sign-in through Keycloak as the public client `libredb-mobile`, with PKCE, refresh and logout that ends the Keycloak session.
- Studio accepts the Keycloak access token as a bearer (`OIDC_BEARER_AUDIENCE`).
- The Platform installer creates the Keycloak client when `mobile.enabled` is set.
- A first Studio call: the list of managed connections.
- A local Studio and Keycloak over TLS in `tool/studio-dev`, and an emulator CA script.

## M1 Studio API layer

A typed Dart client for the Studio endpoints the next milestones need, with no new screens.

- One place that reads Studio's error body and maps its codes to the app's error codes.
- The session ends only on a 401 `AUTH_REQUIRED`; a 401 `AUTH_ERROR` (a wrong database password) leaves the session alone instead of refreshing the token.
- `429` with `Retry-After` reaches the caller as a typed error, and no request that changes data is retried on its own.
- Repositories for the session (`/api/auth/me`), connections, the object browser and the SQL editor, each with mock answers and tests.

Done when every repository has tests against recorded Studio answers and one smoke run against the local Studio passes.
The answers in `test/fixtures/studio/` were recorded from Studio main in `tool/studio-dev` on the SQLite sample, which has no transactions: the transaction methods are tested against hand-written answers only, until the local stack has an engine with transactions.

## M2 Connection list

The first real screen: which databases can I use?

- The user's name and role from `/api/auth/me` in the shell.
- Connections grouped by environment and group, with search, engine icons and a production badge.
- Pull to refresh, and the governance states: a snapshot Studio cannot serve (503) is shown as such, never as an empty list.
- A connection health check before opening it.

## M3 Object browser

Look inside a connection, read-only.

- Containers (databases, schemas, keyspaces), then the objects in one (tables, views, functions, collections) with their counts.
- An object's details: columns with types, keys, indexes, and the source of a view or function.
- Search across the objects of a connection.
- Key scan for key-value engines.
- Metadata is cached per connection, because tree browsing shares the user's request budget with everything else in Studio.

## M4 SQL editor

Run a statement and read the result on a phone.

- An editor sized for a phone, with the connection's dialect, and the statement history kept on the device.
- Results in pages, loaded on demand, with column types and the row count.
- Cancel a running statement.
- Several statements in one run, each with its own result.
- A confirmation before a statement that writes, and a visible production badge on the editor.
- Later: an interactive transaction (begin, run, commit or roll back) and EXPLAIN.

## M5 Grant a connection (admin)

An admin gives a user read or write access to a connection from the phone.

Grants live in LibreDB Platform, and Platform changes them only through server actions behind its web session today.
This milestone needs Platform v1 to offer a small API that accepts the Keycloak access token:

- List the tenant's connections, search the directory, list the grants of a connection.
- Create or change a grant (subject, level, expiry) and revoke it.
- The same checks, license seats and audit as the web console, with the change marked as coming from the mobile app.
- Its own audience, such as `libredb-platform-api`, so a token meant for Studio cannot change grants.

Studio alone cannot do this: without Platform it gives connections to roles from an operator's seed file, not to people.

## M6 Release

- The full walkthrough on a physical Android phone and on iOS.
- Certificate pinning and Sentry configured for the release build.
  Sentry on iOS needs the native scrubber first, since sentry-cocoa records events and breadcrumbs unmasked ([crash-reporting.md](crash-reporting.md)).
- A decision on the start-up app config check: a Studio endpoint for it, or its removal, since Studio has no `/api/app/config` today.
- Store listings, signing and a release pipeline.

## Not planned

- Typing database credentials on the phone, or connections that only the phone knows.
- The AI assistant and the agent of Studio.
- Web and desktop builds of this app; Studio's own web UI serves those.
