# Roadmap

LibreDB Mobile is a native client for LibreDB Studio on Android and iOS.
It signs in through Keycloak and works with the databases Studio offers the user: browse them, look inside them, and run SQL.
Studio stays the only place that holds credentials and talks to the databases; the phone holds a Keycloak session and nothing else.

The order below follows what a user needs first.
Each milestone ends with a working app on Android and iOS, verified against a real Studio (see [studio.md](studio.md)).
How the app talks to Studio is in [architecture.md](architecture.md).

## Status

Each milestone from M2 on is a GitHub milestone with an epic issue that lists its children.
The children of M3 to M9 are filed as issues when their milestone starts.

| Milestone | Status | Epic |
| --- | --- | --- |
| M0 Foundation | Done | |
| M1 Studio API layer | Done | |
| M2 Connection list | In progress | [#8][e8] |
| M3 Object browser | Planned | [#31][e31] |
| M4 Result grid and data preview | Planned | [#32][e32] |
| M5 SQL editor | Planned | [#33][e33] |
| M6 Release | Planned | [#34][e34] |
| M7 Editor power tools | Planned | [#35][e35] |
| M8 Admin on the go | Planned | [#36][e36] |
| M9 Grant a connection | Planned, needs Platform v1 | [#37][e37] |

The first store release (M6) comes before the admin and Platform work, so a Studio or Platform change that has not shipped does not hold it back.
No Studio prerequisite blocks M2 to M6.
Where a child needs a Studio change, the milestone ships an interim version built on the phone, and the child that uses the Studio change follows when Studio ships it.
The Studio and Platform changes are drafted and not filed yet; each epic names the ones it needs.

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

The first real screen after sign-in: which databases can I use?
Epic [#8][e8], end-to-end walkthrough [#30][i30].

- Align the HTTP layer with Studio first: the session rule on `/api/auth/me`, the retry and cache defaults, and a receive timeout longer than Studio's query timeout.
- Remove the template features and the jwt sign-in mode, and move the cross-feature Studio models to `lib/shared`.
- An app shell of three tabs (connections, browse, SQL) with a profile sheet, as Studio's own small-screen layout does.
- The connection list from the managed connections and the policy, with the governance, empty and offline states, a connection check with a status chip, the active connection and a switcher.
- Favorites and recent connections kept on the device.

## M3 Object browser

Look inside a connection, read-only, on the Browse tab.
Epic [#31][e31], end-to-end walkthrough M3-99 (listed in the epic).

- Containers, then the kinds and their counts, then the objects of one kind, then an object's columns, indexes, foreign keys and source.
- Search across the objects of a connection, and a key browser for Redis.
- Metadata is cached per connection, because every object route spends the user's shared request budget.
- Postgres and Redis join `tool/studio-dev` for recorded answers; the other engines are covered by hand-written mocks.

## M4 Result grid and data preview

Show rows on a phone, before the editor exists, by previewing objects from the browser.
Epic [#32][e32], end-to-end walkthrough M4-99 (listed in the epic).

- A card per row with a stats strip, a compact table, load more, and a row detail with copy.
- Cell rendering rules for NULL, documents, binary values and big numbers.
- Client-side masking with Studio's role rules, since Studio masks results only in the browser.
- View and count the rows of an object, and open a Redis key's value, from statements generated on the phone.

## M5 SQL editor

Type and run statements on a phone, on the SQL tab.
Epic [#33][e33], end-to-end walkthrough M5-99 (listed in the epic).

- Run a statement with a fail-closed write confirmation, and cancel it.
- An editor input sized for a phone, a catalog picker for server-level connections, and an honest answer when the app goes to the background during a run.
- Statement history on the device, and open a statement from history or from the object browser.
- Script runs and a confirmation driven by Studio's statement analysis follow when Studio ships that endpoint.

## M6 Release

Ship the first store release of M2 to M5.
Epic [#34][e34]; its end-to-end check is the full walkthrough on a physical Android phone and on iOS (M6-04).

- Remove the start-up check that reads `/api/app/config`, a route Studio does not have.
- Certificate pinning and Sentry for the release build, with the native scrubber on iOS, since sentry-cocoa records events and breadcrumbs unmasked ([crash-reporting.md](crash-reporting.md)).
- Screen capture protection on data screens, an app lock, and a way to remove the app's data.
- Store listings, signing and a release pipeline.

## M7 Editor power tools

The later features from the surveys, each shippable on its own after the first release.
Epic [#35][e35]; each child is checked on its own.

- Interactive transactions, a sandbox mode, EXPLAIN with a plan tree, bound parameters and several drafts.
- Sort, columns, filter, export and charts in the result view, and a per-table relationship view.
- Saved queries and favorites synced from Studio's user storage, and a maintenance and minimum-version gate from Studio, when Studio offers them.

## M8 Admin on the go

Read-only diagnostics and a few guarded actions for a Studio admin on call.
Epic [#36][e36], end-to-end walkthrough M8-99 (listed in the epic).

- An admin section with a route guard and the governance status.
- Fleet health, the health of one connection and its monitoring dashboard.
- Terminate a session, and per-object maintenance behind Studio's preview.
- Recent Studio activity.

## M9 Grant a connection

An admin gives a user read or write access to a connection from the phone, and reads the governed audit.
Epic [#37][e37], end-to-end walkthrough M9-99 (listed in the epic).

Grants live in LibreDB Platform, and Platform changes them only through server actions behind its web session today.
This milestone waits for Platform v1 to offer an API that accepts the Keycloak access token:

- List, set and revoke the grants of a connection, with a level and an expiry.
- Read the governed query audit log.
- The same checks, license seats and audit as the web console, under its own audience, such as `libredb-platform-api`, so a token meant for Studio cannot change grants.

Studio alone cannot do this: without Platform it gives connections to roles from an operator's seed file, not to people.

## Not planned

These stay out of the app; Studio's web UI serves them.

- Typing database credentials on the phone, or adding, editing or importing a connection that only the phone knows.
- The AI assistant and the agent of Studio.
- Editing an object's source, and the create table form.
- Schema diff, schema snapshots and migration statements.
- Whole-database maintenance, pool statistics, and the operator settings for seeds, discovery, thresholds and masking.
- MCP and its tokens.
- Studio's local account features: password, TOTP and passkey sign-in, launch links and account management.
  The app signs in through Keycloak only.
- Data import from files and the test data generator.
- Push notifications and alerting; M8 reads diagnostics on demand.
- Tablet layouts, for now: the first releases target phones.
- Web and desktop builds of this app.

[e8]: https://github.com/libredb/libredb-mobile/issues/8
[i30]: https://github.com/libredb/libredb-mobile/issues/30
[e31]: https://github.com/libredb/libredb-mobile/issues/31
[e32]: https://github.com/libredb/libredb-mobile/issues/32
[e33]: https://github.com/libredb/libredb-mobile/issues/33
[e34]: https://github.com/libredb/libredb-mobile/issues/34
[e35]: https://github.com/libredb/libredb-mobile/issues/35
[e36]: https://github.com/libredb/libredb-mobile/issues/36
[e37]: https://github.com/libredb/libredb-mobile/issues/37
