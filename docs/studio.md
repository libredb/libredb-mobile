# Running the app against LibreDB Studio

The app talks to [LibreDB Studio](https://github.com/libredb/libredb-studio) as its backend.
It signs in to Keycloak itself, as the public client `libredb-mobile` with the authorization code flow and PKCE, and sends Keycloak's access token to Studio as `Authorization: Bearer`.
Studio accepts that token through its bearer channel for native clients, which `OIDC_BEARER_AUDIENCE` turns on (Studio's `docs/OIDC.md`, "Bearer access tokens for native clients").
The sign-in itself, the app's only one, is described in [oidc.md](oidc.md).

The bearer channel came with libredb/libredb-studio#1914, which Studio 1.1.0 is the first release to carry; Studio 1.0.0 does not have it.

## What Studio and Keycloak need

In Keycloak, next to Studio's own confidential client:

- A public client `libredb-mobile`: client authentication off, standard flow only, direct access grants off, PKCE method `S256`.
- Redirect URI and post-logout redirect URI `org.libredb.mobile:/oauth2redirect`.
- An Audience mapper on that client that puts Studio's API audience, for example `libredb-studio-api`, into the access token only.
  It must differ from Studio's own client id.
- The role claim in the access token, where Studio maps it under its own `OIDC_ROLE_CLAIM`; the app reads the role only from Studio's `GET /api/auth/me`.

In Studio:

```env
OIDC_BEARER_AUDIENCE=libredb-studio-api
OIDC_BEARER_CLIENT_IDS=libredb-mobile
```

Under LibreDB Platform the installer creates all of this when `mobile.enabled` is set in `libredb.yaml`.

The app is built with:

```env
OIDC_ISSUER=https://keycloak.example.com/realms/libredb
OIDC_CLIENT_ID=libredb-mobile
PROD_API_URL=https://studio.example.com/api
```

Studio's API lives under `/api`, so `PROD_API_URL` ends with it and the repositories use paths such as `/connections/managed`.
A prod build without `PROD_API_URL` stops at start with `ProdApiUrlConfigError`.
Beside it, `STUDIO_CERT_PINS` and `OIDC_CERT_PINS` pin the public keys of Studio's and Keycloak's hosts, each a comma-separated list of at least two base64 SHA-256 pins; both are empty by default, which keeps the system trust store.
How to read the pins, the backup-pin rule, the rotation and the Caddy key reuse they need are in [security.md](security.md#certificate-pinning).
In a Platform install Studio's role claim is `libredb_roles` instead of `realm_access.roles`; the app's build does not change.

## Try it locally

`tool/studio-dev/docker-compose.yml` starts Keycloak 26.8.1 and Studio behind Caddy, which serves both over TLS with its own local CA, because Studio refuses an issuer that is not https:

| Address | Service |
| --- | --- |
| `https://localhost:8443` | Keycloak, realm `libredb`; admin console at `/admin/` with `kcadmin` / `kcadmin` |
| `https://localhost:9443` | Studio; the app's API is `https://localhost:9443/api` |
| `https://localhost:9444` | The governed Studio, with `--profile governed` only ([Governed Studio](#governed-studio)) |
| `https://localhost:9445` | LibreDB Platform, with `--profile platform` only; its bearer API is `https://localhost:9445/api/v1` ([Platform](#platform)) |

The realm has the users `admin` / `admin` (realm role `admin`, client role `libredb:admin`) and `user` / `user` (realm role `user`, client role `libredb:user`), and gives access tokens a 60 second life, so a walkthrough also exercises the refresh.
`norole` / `norole` holds no role at all, so Studio refuses it: the sign-in stays on the login page with the refusal, and nothing is stored.
`admin2` / `admin2` and the disabled account `disabled` are there for Platform ([Platform](#platform)).
The stack needs Docker Compose v2.24.0 or newer.
The stack is unfit for production on purpose: `start-dev` with the embedded H2 store, a self-signed CA, and committed passwords and client secret.

Studio runs the 1.1.0 release image, `ghcr.io/libredb/libredb-studio:1.1.0`, pinned by its digest in the compose file, so no local build is needed.
To try a local build of Studio instead, such as one of its main branch, set `STUDIO_IMAGE` to that image on the `up` command.
Start the stack and build the app against it:

```shell
docker compose -f tool/studio-dev/docker-compose.yml up -d --wait
fvm flutter run --target lib/main/main_prod.dart --dart-define-from-file=tool/studio-dev/studio-dev.env
docker compose -f tool/studio-dev/docker-compose.yml down -v
```

The last command removes the stack with all its state, its CA included.
A first start on an empty volume runs the database seeds, which on a loaded host can take over two minutes; the database healthchecks allow 120 seconds for that before a failed check counts, so `up --wait` waits instead of failing.

### Android emulator

The app's own requests trust only the system CA store, so the stack's CA has to go there.
`tool/studio-dev/trust-android-emulator.sh` does that and forwards ports 8443, 9443, 9444 and 9445 with `adb reverse`, so the emulator's `localhost` reaches the stack and the issuer stays `https://localhost:8443/...`:

```shell
tool/studio-dev/trust-android-emulator.sh            # or pass the adb serial, such as emulator-5554
```

It needs `adb root`, so use an emulator image without Google Play (a "Google APIs" image) at API level 33 or lower; Android 14 and later read the system store from an APEX module, where the script does not work.
The script changes nothing on the image: it mounts a copy of the store over the original, so run it again after every emulator boot and after `docker compose down -v`.

### iOS simulator

The simulator shares the host's loopback, so it needs no port forwarding.
Add the CA to the booted simulator's trust store:

```shell
docker compose -f tool/studio-dev/docker-compose.yml cp ca-export:/ca/root.crt studio-dev-ca.crt
xcrun simctl keychain booted add-root-cert studio-dev-ca.crt
```

This step was not run, since the stack was verified on Linux.

### What the walkthrough shows

1. "Sign in with SSO" opens Keycloak in a Custom Tab (Android) or `ASWebAuthenticationSession` (iOS).
2. After the sign-in the app asks Studio's `GET /api/auth/me` and opens the connection list only on its 200; `norole` / `norole` stays on the login page with "Studio did not accept this sign-in.", and nothing is stored.
3. The connection list shows what Studio offers the user: the seeds of [Postgres seeds](#postgres-seeds) and [Redis seed](#redis-seed) and Studio's sample connections (the SQLite one only to `admin`).
   That request carries the access token, so the list proves the bearer channel.
4. A minute later the access token has expired: Studio answers the next request with 401, and the app refreshes at Keycloak and repeats it.
5. Logout ends the Keycloak session as well, and the app is back on the login page.

How far this was verified:

| Platform | Status |
| --- | --- |
| Android emulator, API 30 Google APIs image | Walked through as above with Studio built from libredb/libredb-studio#1914 at `d8d1b4970`: sign-in, the connection list, the refresh after expiry and the logout all worked |
| Android emulator, API 30 Google APIs image, Studio main `dbfea26` | The Keycloak-only sign-in of #11: `admin` and `user` land on the connection list, `norole` is refused at sign-in with `studio.account_refused` and a relaunch finds no session, and the logout ends the Keycloak session |
| Android emulator, API 30 Google APIs image, Studio main `c9989a6b5` (with libredb-studio#1922) | The refusals of #29: `norole` is refused at sign-in with `studio.account_has_no_role`; once the realm role of `user` is removed and the access token refreshed, a relaunch shows the refusal page after one 403 `BEARER_NO_ROLE` per route and no further request; Retry after the role is back and the token has expired refreshes once and opens the app; with Keycloak stopped and Studio restarted, the connection list shows `studio.identity_provider_unavailable` and the session stays |
| iOS simulator | Not run |

## M2 walkthrough

The end-to-end walkthrough of milestone M2 (#30) was run on 2026-10-23 from `main` at `49c52ef`, built with Flutter 3.47.7 as a debug APK of `main_prod.dart`, once with `studio-dev.env` (the plain Studio) and once with `studio-dev-governed.env` (the governed Studio).
The stack ran `libredb-studio:main-c9989a6` (Studio main `c9989a6b5`, with libredb/libredb-studio#1922) and Keycloak 26.8.1 with the `governed` profile, and the device was the Android emulator 37.2.12 with the AVD `libredb-dev-api30`: API 30 Google APIs image, Android 11, `sdk_gphone_x86_64`, after `tool/studio-dev/trust-android-emulator.sh`.
Every step was walked through as `user` / `user`.

| Step | Plain Studio | Governed Studio |
| --- | --- | --- |
| 1. Sign in; profile; settings | Passed: the SSO sign-in lands on the connection list; the profile sheet shows `user@example.com` (Studio's username) and the role User, with no governance chip; Settings opens | Passed: the same, and the profile sheet shows "Governed by LibreDB Platform" |
| 2. Groups, Turkish i search, badges, offline | Passed: "Dev databases" (4) and "Other" (1); `REDİS` finds Dev Redis; airplane mode shows the offline banner and "Offline: showing what was loaded at ..." over the kept list, and both go when it ends | Passed: "Sales" (2) under the statement capture note; `PRODUCTİON` finds Sales (production); Sales (production) carries the red PROD badge and the "Read only" lock of the read grant; the offline banner as on the plain Studio |
| 3. Governance source stopped | Not applicable: the plain Studio has no governance | Passed: within 30 seconds of `stop governance-source` the list shows "Connection access is temporarily unavailable. The list updates by itself once it is back." over greyed rows that take no tap; within 25 seconds of `start governance-source` the banner goes and the rows open again |
| 4. Check, switcher, relaunch | Passed: the check of Dev Postgres reads "Reachable, 8 ms"; the app-bar switcher marks the active connection and switches from Dev Postgres to Dev Redis; after a force stop the app opens with Dev Redis active | Passed: the check of Sales (production) reads "Reachable, 13 ms"; the switcher switches from Sales (development) to Sales (production), whose app bar shows PROD and the lock; after a restart of the whole emulator the app opens with Sales (production) active |
| 5. Grant revoked | Not applicable | Passed with a note: with Sales (production) active, the grant of `user` was deleted as in [Revoking a grant](#revoking-a-grant); the Connections tab then dropped the connection and showed "Sales (production) is no longer available", Browse said "Pick a connection first", and the connection came back once the grant was inserted again |
| 6. Sign out | Passed: the app is back on the login page and Studio logged an audit line with `"event":"logout"`, `"outcome":"success"`, `"actor":"user@example.com"` and `"route":"POST /api/auth/logout"` | Passed: the governed Studio logged an audit line with the same fields |

The note on step 5: the list asks Studio again only while the Connections tab is in the foreground, and Browse and SQL send no request to Studio yet, so while Browse was open the revoked connection stayed in its app bar for more than a minute, and the message came at the next list answer, on the return to the Connections tab.
That is the trigger #26 asks for; once Browse and SQL send requests (M3), the 404 `CONNECTION_NOT_FOUND` of the first one ends the connection there as well.

The emulator's keyboard (Gboard, English) types neither `İ` nor `ı`, so the Turkish search terms were copied in Chrome from a page served to the emulator and pasted from Gboard's clipboard.
The emulator process exited once in the middle of step 4 on the governed Studio, with only graphics errors in its log; after a cold boot and `trust-android-emulator.sh` the walkthrough went on from the relaunch.

The iOS simulator was not run, since the walkthrough ran on Linux, so no step is verified on iOS.

## M3 walkthrough

The end-to-end walkthrough of milestone M3 (#60) was run on 2026-10-23 from `main` at `ae78729`, built with Flutter 3.47.7 as a debug APK of `main_prod.dart`, once with `studio-dev.env` (the plain Studio) and once with `studio-dev-governed.env` (the governed Studio).
The stack ran `libredb-studio:main-c9989a6` (Studio main `c9989a6b5`) and Keycloak 26.8.1 with the `governed` profile, and the device was the Android emulator 37.2.12 with the AVD `libredb-dev-api30`: API 30 Google APIs image, Android 11, `sdk_gphone_x86_64`, after `tool/studio-dev/trust-android-emulator.sh`.
Steps 1 to 6 and 8 were walked through as `admin` / `admin` on the plain Studio, since only `admin` is offered the SQLite sample, and step 7 as `user` / `user` on the governed Studio.

| Step | Result |
| --- | --- |
| 1. Containers and kinds | Passed: Sample (Employees) opens on its kinds (Tables 6, Views 2, Indexes 0, Triggers 0); Dev Postgres lists the schemas `public` and `sales`; Dev Postgres server lists the databases `app`, `archive` and `postgres`, and `app` its schemas |
| 2. Object list and detail | Passed: the filter `ord` on the tables of `public` shows "2 of 4 match" (`order_items`, `orders`); `orders` shows its columns with the key mark on `id`, the indexes `orders_pkey` and `orders_customer_id_idx`, and the foreign key `customer_id`, "References customers.id", which opens `customers` |
| 3. Source, copy and share | Passed: the Source tab of the view `sales.order_totals` and the source page of the function `sales.order_total(bigint)` show Studio's text with "Regenerated by Studio, not the stored text"; Copy all says "Copied" and both texts were in Gboard's clipboard; Share opens Android's share sheet with the text |
| 4. Search | Passed: `ord` on Dev Postgres finds the tables, sequences and trigger of `public` and the view and function of `sales`, grouped by schema, and a match opens its detail; on Dev Postgres server the search page says "Search is not available on this connection; browse instead" |
| 5. Redis key browser | Passed: database 1, pattern `user:*`: the first page holds 499 keys, Load more 996, Load all ends at 1,203 with no more pages; Stop during Load all (with a network delay, below) shows "Stopping after this page" and the walk stops at the end of the page; with no pattern, the folders `session:` and `2:` open in place onto `events` (list) and `log` (stream) |
| 6. No 429 | Passed: 70 seconds of browsing back and forth over kinds, tables, `orders` and the source of `order_totals` sent 8 requests to Studio (4 of them `source`, which is never cached), and neither Studio logged a `rate_limit_exceeded` audit line during the whole walkthrough |
| 7. Governed, grant revoked | Passed: Sales (production), under its "Read only" lock, opens the database `sales` on the kinds of `public`, then `public.orders` with its columns; once the grant of `user` was deleted as in [Revoking a grant](#revoking-a-grant), the next request (a pull to refresh on `orders`) answered `studio.connection_not_available`, the app went to the Connections tab with "Sales (production) is no longer available", and Browse said "Pick a connection first" |
| 8. Offline | Passed: airplane mode on the loaded tables of `public` keeps the list with "Offline: showing what was loaded at 8:04 AM" under the offline banner; a level not loaded before says "No internet connection. Check your network and try again." with Retry; once airplane mode ends the banner and the marker go |

Also walked through:

- The read-only seed: Dev Postgres (read-only role) shows `public.orders` with its columns and indexes, no key mark on `id`, and "Studio lists no foreign keys." on the Foreign keys tab, because Studio before 1.1.0 hid the keys from a role that does not own the table (see [Postgres seeds](#postgres-seeds)); Studio 1.1.0 shows them, as the check below records.
  Before 1.1.0, the read grant of Sales (production) showed `public.orders` without a key mark on `id` for the same reason.
- Exclusion constraints: the seed then held none, so the table `sales.room_bookings`, with `EXCLUDE USING gist (during WITH &&)`, was created in `app` as `app_owner` during the walkthrough; its Indexes tab lists `room_bookings_during_excl` and, under "Exclusion constraints", its definition.

The local Studio answers a key-scan page in a few milliseconds, so Load all ended before Stop could be tapped; for the Stop check the `redis` container was given a 1.5 second network delay (`tc qdisc add dev eth0 root netem delay 1500ms`, from a container sharing its network namespace with `NET_ADMIN`), removed again afterwards.
The view's row in the search read "View · 0 B", the size Studio before 1.1.0 sent for a view; the check on Studio 1.1.0 below reads "View".

Found during the walkthrough and logged for the backlog, none of which fails a step:

- At start the app asked Studio for an app config, a route Studio does not have, without a token, and Studio answered 401; [#102](https://github.com/libredb/libredb-mobile/issues/102) removed that check.
- Under a pattern, the key browser's "Scanned n of the t keys this database holds" counts the matching keys, so a finished walk of `user:*` reads "Scanned 1203 of the 1207 keys this database holds".
- A Browse level that failed offline loads again only on Retry after airplane mode ends, while the connection list recovers by itself.
- The Postgres seed has no exclusion constraint, which is why the table above was added by hand.

The iOS simulator was not run, since this Linux host has none and CI builds Android only, so no step is verified on iOS, #57's share sheet included; #91 tracks the iOS walkthrough.

### Studio 1.1.0 check

The paths of the M3 walkthrough that Studio 1.1.0 changed were checked again on 2026-10-24 (#222), with a debug APK of `main_prod.dart` and `studio-dev.env` from the branch of #222, against the stack on the pinned 1.1.0 image from a fresh volume, on the AVD `libredb-dev-api33` (API 33 Google APIs image) after `tool/studio-dev/trust-android-emulator.sh`, signed in as `admin` / `admin`:

| Path | Result |
| --- | --- |
| Read-only seed, `public.orders` | Passed: Dev Postgres (read-only role) marks `id` as the primary key, and the Foreign keys tab lists `customer_id`, "References customers.id", as the owner's seed does |
| Search `ord` on Dev Postgres | Passed: the view `order_totals` reads "View" with no size, while `orders` reads "Table · 48 KB" |
| Search over too many places | Passed: with 150 empty schemas added to `app`, the search `order` shows "Too many places to search. Pick object kinds to narrow the search." with a chip per kind (Tables, Views, Materialized Views, Sequences, Functions, Procedures, Triggers) and no Retry; Tables sends the term again with `kinds: ["table"]` and lists `order_items` and `orders`, with the Tables chip picked |

## M4 walkthrough

The end-to-end walkthrough of milestone M4 (#100) was run on 2026-10-23 from `main` at `3efd6d6`, built with Flutter 3.47.7 as a debug APK of `main_prod.dart` with `studio-dev.env`.
The stack ran `libredb-studio:main-c9989a6` (Studio main `c9989a6b5`), Keycloak 26.8.1, Postgres 17 and Redis 8.10, started from a fresh volume, so `sales.ledger` held its 100 rows.
The device was the Android emulator 37.2.12 with the AVD `libredb-dev-api33`: API 33 Google APIs image, Android 13, `sdk_gphone64_x86_64`, KVM, after `tool/studio-dev/trust-android-emulator.sh`.
Step 1 was walked through as `user` / `user` and as `admin` / `admin`, every other step as `user` / `user`.
For steps 6, 9 and 10 the `postgres` container logged every statement with its database (`ALTER SYSTEM SET log_statement = 'all'` and a `log_line_prefix` with `%d`, then `pg_reload_conf()`), which `down -v` removes with the volume.

| Step | Result |
| --- | --- |
| 1. Masked columns | Passed: View rows on `public.customers` shows `email` as `a**@e**********` and `g****@e**********` and `card_number` as `****-****-****-1111`, with the lock, for `user` and for `admin`, in the cards, the row detail and the table header; a NULL stays `NULL` |
| 2. Cell types | Passed: `public.column_types` shows `bigint` `9007199254740993` and `numeric` `12345678901234.123456` with every digit, `jsonb` as `{"b":{"c":true}}` in a cell and pretty-printed in the row detail, `bytea` as `\xdeadbeef`, and `null_value` as the muted italic `NULL`; the table cuts some headers, #126 |
| 3. Paging, modes, rotation | Passed: `sales.ledger` opens on 50 rows with the `limited` chip and the order notice; Load 50 more gives 100 rows, after which Studio offers no more and the chip, the notice and the button go; cards and table switch, and the table mode was still chosen after the app was relaunched; the rotation ran later, once the app rotated (#127, PR #179), and kept the 100 rows, the view mode and the position with no new statement in the Postgres log; the table scrolls past its last row and column, #125, and cuts `entry 10` to `entry …`, #126 |
| 4. Row detail and copy | Passed: the sheet swipes from "Row 1 of 100" to row 3 and back; Copy value of a clear field and of a masked field and Copy row as JSON in the sheet, and Copy value of a masked cell in the table's long-press menu, say "Copied", and Android 13's clipboard preview shows only dots each time; pasted into a text field, the masked `email` gives `a**@e**********` and the row gives its JSON with both masked values |
| 5. Count | Passed: Count rows on `public.orders` reads "4 rows" |
| 6. Server-level seed | Passed: View rows on `app.public.orders` of Dev Postgres server shows its 4 rows, and the Postgres log shows `SELECT * FROM app.public.orders LIMIT 51;` in the database `app` |
| 7. Read-only role | Passed: the describe of `public.orders` through Dev Postgres (read-only role) marks no key, and Count rows ("4 rows") and View rows (4 rows) run as `studio_reader` |
| 8. Redis values | Passed: in database 1 the string `cache:greeting`, the JSON text of `user:2:profile` (pretty-printed), the hash `user:2`, the list `session:2:events`, the set `user:2:roles`, the sorted set `cache:leaderboard` and the stream `session:2:log` open from the key browser; the hash's `email` field shows `grace@example.com` in clear; after `redis-cli -n 1 DEL cache:greeting` in the `redis` container, the still listed key opens on "This key no longer exists. Pull to read it again." |
| 9. Offline | Passed: airplane mode on the loaded `sales.ledger` rows keeps them under the offline banner with "Offline: showing what was loaded at 2:24 PM"; a pull says "No internet connection", and neither the Postgres log nor Studio's log has a line from it; View rows (long-press menu and detail heading), Count rows (rows page and detail heading) and Load 50 more are disabled with "Needs an internet connection"; a loaded Redis value page behaves the same way |
| 10. No 429, one run per tap | Passed: 2 minutes 25 seconds of four rounds over the tables of `public`, View rows on `customers`, the detail of `orders`, its Count rows and View rows sent 12 statements for 12 taps, each once in the Postgres log; Studio logged no `rate_limit_exceeded` and no 429 during the whole walkthrough |

Notes:

- Read value, offered only for a key the key browser lists without a type, was not reached: Studio's scan gave every key of the seed its type, so its offline state is covered only by #99's widget test.
- When the 60 second access token had expired, Studio answered a `POST /api/db/query` with 401 and an audit line `permission_denied`, `bearer_token_invalid`; the app refreshed and repeated the request, and the Postgres log still shows that statement once, since Studio refuses the token before it runs anything.
- With the emulator's default host GPU, Chrome's Custom Tab drew the Keycloak page on this API 33 image as broken shapes; the walkthrough ran with `emulator -avd libredb-dev-api33 -gpu swiftshader_indirect`, which draws it correctly and still uses KVM.

Defects found, each filed and linked from #100:

- #125: the rows page and the key value page scroll past their content in both directions and do not spring back after a pull.
- #126: a table column sized to its content cuts its header or its longest value by a few pixels.
- #127: the app was locked to portrait, so the rotation checks of #96 and #100 could not run; PR #179 lets phones rotate and ran them.

No Studio defect was found.

The iOS simulator was not run, since this Linux host has none and CI builds Android only (`.github/workflows/build_and_test.yml:83-84`), so no step is verified on iOS, the clipboard expiry and local-only flag of #97 included; #91 tracks the iOS walkthrough on macOS.

## M5 walkthrough

The end-to-end walkthrough of milestone M5 (#124) was run on 2026-10-23 from `main` at `50eb6e2`, built with Flutter 3.47.7 as a debug APK of `main_prod.dart` with `studio-dev.env`.
The stack ran `libredb-studio:main-c9989a6` (Studio main `c9989a6b5`), Keycloak 26.8.1, Postgres 17.6 and Redis 8.10, started from a fresh volume.
The device was the Android emulator 37.2.12 with the AVD `libredb-dev-api33`: API 33 Google APIs image, Android 13, `sdk_gphone64_x86_64`, KVM, started with `-gpu swiftshader_indirect`, after `tool/studio-dev/trust-android-emulator.sh`, with the app's data cleared before the first sign-in.
Steps 1 to 8 were walked through as `user` / `user`, the second account of step 8 and steps 9 and 10 as `admin` / `admin`.
The `postgres` container logged every statement with its database (`log_statement = 'all'`, as in the M4 walkthrough), and `adb logcat` recorded the whole session from the emulator's boot to its end.

| Step | Result |
| --- | --- |
| 1. Rows, Load more, database words | Passed: `SELECT * FROM orders` on Dev Postgres runs without asking and shows its 4 rows; `orders` has no masked column, so `SELECT * FROM customers` was run too and shows `email` as `a**@e**********` and `card_number` as `****-****-****-1111`, each marked as masked; no seeded table holds more than a page, so Load more was checked on `SELECT n, n * 2 AS twice FROM generate_series(1, 2500) AS n`, whose first page holds Studio's 500 rows with "Studio bounded this result", and Load 500 more gives 1,000 rows; `SELEC 1` asks (its first word is not a read), then shows "The database says" and `syntax error at or near "SELEC"`; `SELECT 1 FRM orders o` shows `syntax error at or near "orders"` and a typed character lands right before `orders`, so the cursor sits at Postgres's position |
| 2. Write confirmation | Passed: `DELETE FROM orders WHERE false` asks with "May change data: DELETE on line 1" and every line of the text; on Prod Postgres the sheet shows PROD and Run stays disabled for an empty field and for `prod postgres`, and runs once "Prod Postgres" is typed; on Dev Postgres (read-only role), `seed:dev-postgres-readonly`, the confirmed DELETE shows "The database did not allow this. You may lack a privilege on this object." (`studio.permission_denied`), Postgres logged `permission denied for table orders` for `studio_reader`, and the session stays; Load more of `SELECT n FROM generate_series(1, 2500) AS n -- note: update`, which asks with "UPDATE on line 1", shows the sheet again before the next page, and on Prod Postgres with an empty name field each time |
| 3. Lone `BEGIN` | Passed: it asks, and after the run shows "This statement left a transaction open, and Studio rolled it back, so its changes were discarded. Add COMMIT to keep them." |
| 4. Timeouts, cancel, script | Passed: `SELECT pg_sleep(45)` shows "1 row, 45,005 ms"; `SELECT pg_sleep(70)` shows "The database did not answer in time." (`studio.timeout`) and Postgres logged `canceling statement due to statement timeout` 60.000 s after the statement, before the phone's own 75 s; Cancel during `SELECT pg_sleep(30)` was tapped at 23:12:40.048Z, Postgres logged `canceling statement due to user request` at 23:12:40.078Z, a screenshot 2 s after the tap shows "Cancelled", and `pg_stat_activity` held no active `pg_sleep(30)`; `SELECT pg_sleep(40); SELECT pg_sleep(40)` asks with "Runs more than one statement", shows "Running for 0:23" while it runs, and ends with Statement 1 at 40,041 ms and Statement 2 at 40,022 ms, both on screen about 80 s after the confirmation |
| 5. Scripts and selection | Passed: `SELECT 1 AS a;`, `SELECT * FROM missing_table;`, `SELECT 3 AS c` on three lines shows Statement 1 succeeded, Statement 2 failed with `relation "missing_table" does not exist` and "1 statement not run", and Postgres logged no `SELECT 3 AS c`; `SELECT 1 AS a;`, `SELECT 2 AS b;`, `DELETE FROM orders WHERE false` asks with "May change data: DELETE on line 3" and "Runs more than one statement", needs "Prod Postgres" on Prod Postgres, and ends with Statement 3 at 0 rows; with `SELECT 22 AS second_one` selected out of two statements, Run selection runs only that one, without asking, which is the only statement Postgres logged |
| 6. Backgrounding | Passed, Android kept the socket: with `SELECT pg_sleep(20)` running, the home screen for 60 s and the return show "1 row, 20,021 ms"; with the confirmed `UPDATE orders SET note = note FROM (SELECT pg_sleep(20)) AS s WHERE orders.id = 1` the return shows "1 row affected"; neither interrupted message appeared, since no request dropped, so they are covered only by #118's widget tests and by the iOS run in #91 |
| 7. Editing and drafts | Passed: the accessory row types `(`, `*`, `)` and `;` into the text, scrolls to Tab, Undo and Redo, and Undo and Redo remove and restore the `;`; keywords are bold and numbers muted; Dev Postgres keeps `SELECT count(*) FROM orders;` across a tab change to Browse and back, across a switch to Prod Postgres (which shows its own draft) and back, and across a force stop and relaunch |
| 8. History and accounts | Passed: with "All connections" on and the search `Prod`, the history lists the three Prod Postgres runs; tapping the `generate_series` one while Dev Postgres was active asks "Replace the editor's text?", and Replace makes Prod Postgres the active connection with the text in the editor, and Postgres logged no statement; after a sign-out, `admin` sees "No statements yet" with "All connections" on and an empty editor on Prod Postgres; signed in again, `user` finds both the history and the Prod Postgres draft; found #167 |
| 9. Open in editor, catalog | Passed: 'Open in editor' in the long-press menu of `public.customers` opens the SQL tab with `SELECT * FROM public.customers;`, sends nothing (no new line in the Postgres log), and the text runs without asking (3 rows); on Dev Postgres server the editor shows the chip "Database: app", its sheet "Run statements in" lists `app`, `archive` and `postgres`, and after picking `archive`, `SELECT current_database() AS db, count(*) AS n FROM orders_2025` runs in the database `archive`, as the Postgres log shows |
| 10. Offline | Failed for Cancel, #164: with airplane mode on, Run is disabled with "Needs an internet connection", as is View rows in the Browse long-press menu, and 'Open in editor' still opens its statement; but while `SELECT pg_sleep(30)` runs, Cancel stays enabled with no reason, and a tap shows "No internet connection. Check your network and try again." and offers Stop waiting, while the statement runs on |
| 11. Device log | Passed: the 98,656 lines of `adb logcat` hold none of the 27 statement, database error and history texts searched for (among them `FROM orders`, `generate_series`, `SELEC 1`, `pg_sleep`, `missing_table`, `orders_2025`, `syntax error`, `permission denied`, `statement timeout`); the only matches, `BEGIN` and `does not exist`, are lines of system processes, and the app's 200 lines carry only routes, error codes such as `studio.query_error` and `studio.timeout`, and request outcomes |

Notes:

- The SQL tab's top bar reads only "SQL" and never names the active connection, so a statement that runs without asking, or the switch that a History entry of another connection makes, happens on a connection the page does not show; filed as #163.
- Android kept the socket of a backgrounded run, and removing the `adb reverse` rule during the background did not drop the open connection either, so the interrupted outcomes of #118 were not reached on the device.
- `DELETE FROM orders WHERE false` changes no row and shows "Query returned no data", since the write headline counts only a positive row count; filed as #168.

Defects found, each filed and linked from #124:

- #163: the SQL tab's top bar does not name the active connection.
- #164: offline, the editor's Cancel stays enabled and fails with "No internet connection".
- #167: opening a History entry of another connection with Replace asks against the text on screen and replaces that connection's saved draft, which the user never saw.
- #168: a write that changed no row shows "Query returned no data".

No Studio defect was found.

The iOS simulator was not run, since this Linux host has none and CI builds Android only (`.github/workflows/build_and_test.yml:83-84`), so no step is verified on iOS; the M5 steps were added to #91, which tracks the iOS walkthrough on macOS.

## Postgres seeds

The default stack also runs `postgres`, Postgres 17 loaded by `tool/studio-dev/postgres/seed.sql`, and Studio reads `tool/studio-dev/seed-connections.yaml` through `SEED_CONFIG_PATH` beside its built-in samples:

| Connection | Environment, group | What it opens |
| --- | --- | --- |
| `seed:dev-postgres`, "Dev Postgres" | `development`, `Dev databases` | The database `app`, so the tree starts at its schemas |
| `seed:dev-postgres-server`, "Dev Postgres server" | `staging`, `Dev databases` | The whole server, so the tree starts at its databases (`app`, `archive`, `postgres`) and a request names the database in `catalog` |
| `seed:dev-postgres-readonly`, "Dev Postgres (read-only role)" | `development`, `Dev databases` | The database `app` through a role that may only read |
| `seed:dev-postgres-prod`, "Prod Postgres" | `production`, `Dev databases` | The database `app` as `seed:dev-postgres` opens it, marked as production, so the editor's write confirmation asks for the typed name |

`app` holds the schemas `public` and `sales`:

- `public.customers`, `public.orders` and `public.order_items`, with primary keys, the foreign keys `orders.customer_id` and `order_items.order_id`, and the index `orders_customer_id_idx`.
- Columns of `bytea`, `numeric`, `bigint` and `jsonb`, rows with many NULLs, and the `email` and `card_number` columns the masking work of M4 masks.
- `public.column_types`, one row of every column type a query result renders.
- The view `sales.order_totals`, the function `sales.order_total(bigint)`, the procedure `sales.mark_shipped(bigint)` and the trigger `orders_touch_updated_at` on `public.orders`.
- `sales.ledger`, exactly 100 rows, so pages of 50 rows end with a full page that has no more and an empty page past it.
- `sales.room_bookings`, with the exclusion constraint `room_bookings_during_excl` (`EXCLUDE USING gist (during WITH &&)`), which the Indexes tab lists under "Exclusion constraints".

`archive` holds one table, so the server-level seed lists more than one database.
The first two seeds sign in as `app_owner`, which owns every object, and the third as `studio_reader`, which may only read and owns nothing.
Studio 1.1.0 reads a table's keys from `pg_catalog`, which every role that can see the table reads, so its describe of `public.orders` names the same keys through the third seed as through the first.
Studio before 1.1.0 read them from `information_schema` views, which show foreign keys only to the owner, and named none through the third seed.
Both passwords are only in the compose file, and every seed is managed, so `GET /api/connections/managed` sends neither.
A server-level seed exists only without governance: a governed Studio refuses it at admission with `SERVER_LEVEL_NOT_ALLOWED`.

## Redis seed

The default stack also runs `redis`, Redis 8.10 with a password and no persistence, which the one-shot `redis-seed` service loads from `tool/studio-dev/redis/seed.redis` before Studio starts.
Studio offers it as `seed:dev-redis`, "Dev Redis" (`development`, `Dev databases`), managed like the Postgres seeds, so its password stays in the compose file.
The seed names no database, so a request without `database` reads database 0, and the tree lists the server's 16 numbered databases.

Databases 0 and 1 each hold one key of every type the key browser reads, under `user:*`, `session:*` and `cache:*`:

| Type | Database 0 | Database 1 |
| --- | --- | --- |
| string | `cache:greeting` | `cache:greeting` |
| string holding JSON | `user:1:profile` | `user:2:profile` |
| hash | `user:1` | `user:2` |
| list | `session:1:events` | `session:2:events` |
| set | `user:1:roles` | `user:2:roles` |
| sorted set | `cache:leaderboard` | `cache:leaderboard` |
| stream | `session:1:log` | `session:2:log` |

Database 1 also holds 1,200 strings `user:0001` to `user:1200`, so a walk of `user:*` there takes several pages; it holds 1,207 keys in all.
A stream entry has a fixed id, so a recorded read of it does not change with the clock.
`redis-seed` exits non-zero on any reply but `OK`, a number or a stream id, and when databases 0 and 1 do not hold 7 and 1,207 keys, so Studio never starts on an empty Redis.

## Governed Studio

The compose profile `governed` adds a second Studio in governance mode beside the first one, so the governed answers the app depends on can be recorded from a real Studio.
Studio's `docs/GOVERNANCE.md` is the contract it follows.

| Address or service | What it is |
| --- | --- |
| `https://localhost:9444` | The governed Studio; the app's API is `https://localhost:9444/api` |
| `governance-source` | Postgres 17 holding the `bridge` schema a control plane would publish, seeded by `tool/studio-dev/governed/governance-source.sql` |
| `governed-db` | Postgres 17 holding Studio's storage, which governance mode keeps in Postgres, and the `sales` database the governed connections open |

No control plane runs: the seed holds the published bridge objects directly, built from Studio's own manifest.
It grants the realm's users by their Keycloak `sub`, which the realm import fixes to `a0000000-0000-4000-8000-000000000001` for `admin` and `a0000000-0000-4000-8000-000000000002` for `user`:

| Connection | Environment, group | `admin` | `user` |
| --- | --- | --- | --- |
| `sales-dev`, "Sales (development)" | `development`, `Sales` | write | write |
| `sales-prod`, "Sales (production)" | `production`, `Sales` | write | read |

The runtime setting `queryLog.statementCapture` is `full`, so the policy answers `statementCapture: "full"`.
Sign in as `admin` / `admin` or `user` / `user`, as on the first Studio.

Start the stack with the profile and build the app against the governed Studio:

```shell
docker compose -f tool/studio-dev/docker-compose.yml --profile governed up -d --wait
fvm flutter run --target lib/main/main_prod.dart --dart-define-from-file=tool/studio-dev/studio-dev-governed.env
docker compose -f tool/studio-dev/docker-compose.yml --profile governed down -v
```

Pass `--profile governed` to `down` as well, or the profile's containers and volumes stay behind.
On the Android emulator, `tool/studio-dev/trust-android-emulator.sh` also forwards port 9444.

### Revoking a grant

The seed writes the tables behind the bridge views, whose triggers notify Studio, so a change takes effect within a second:

```shell
docker compose -f tool/studio-dev/docker-compose.yml --profile governed exec governance-source \
  psql -U postgres -d governance -c "DELETE FROM bridge.grants_v1_source WHERE subject = 'a0000000-0000-4000-8000-000000000002' AND connection_id = 'sales-prod'"
```

After it, `user`'s managed list holds only `sales-dev`, and a request naming `seed:sales-prod` answers 404 `CONNECTION_NOT_FOUND`.
Insert the row again to give the grant back:

```shell
docker compose -f tool/studio-dev/docker-compose.yml --profile governed exec governance-source \
  psql -U postgres -d governance -c "INSERT INTO bridge.grants_v1_source (subject, connection_id, level, expires_at, downgraded, granted_at) VALUES ('a0000000-0000-4000-8000-000000000002', 'sales-prod', 'read', NULL, false, now())"
```

An insert into `bridge.session_revocations_v1_source` ends a user's sessions the same way.

### Making the snapshot unavailable

Stop the governance source:

```shell
docker compose -f tool/studio-dev/docker-compose.yml --profile governed stop governance-source
```

The governed Studio reloads every 5 seconds and serves its last snapshot for at most 15 seconds, so within about 15 seconds `GET /api/connections/managed` answers 503 `GOVERNANCE_UNAVAILABLE`.
`docker compose ... --profile governed start governance-source` brings it back, and the next reload answers again.
The app's connection list shows the outage over its greyed rows, or full screen on a cold start, and comes back by itself within 10 seconds of the next answer; walked through on the Android emulator, API 30 Google APIs image, with Studio main `c9989a6` as `user`.

### Regenerating the seed

`tool/studio-dev/governed/generate.ts` writes `governance-source.sql`, `governed-db.sql` and `keyring.json` from a checkout of Studio, with Studio's own fixture builder and test sealer; never edit those files by hand:

```shell
bun tool/studio-dev/governed/generate.ts ../libredb-studio
```

Every key and password in them is derived from a fixed label and protects nothing, so a second run writes the same bytes.
Run it again when Studio publishes a new governance contract.

### Docker Hub on this machine

Where the stored Docker Hub credentials are rejected, pulls of `postgres`, `redis` and `caddy` fail even though the images are public.
Point `DOCKER_CONFIG` at an empty directory for the command, so Docker pulls anonymously:

```shell
mkdir -p /tmp/empty-docker-config
DOCKER_CONFIG=/tmp/empty-docker-config docker compose -f tool/studio-dev/docker-compose.yml --profile governed up -d --wait
```

### Recorded answers

`test/fixtures/studio/managed_governed.json`, `policy_governed.json` and `governance_unavailable.json` are recorded as `user` with a `libredb-mobile` access token, and `admin_governance.json` as `admin`, from Studio 1.1.0 (see [Recording Studio answers](#recording-studio-answers)).
The seed in `tool/studio-dev/governed/` was generated from Studio `02dc26057`, and Studio 1.1.0 admits it unchanged.
`managed_governed.json` carries each connection's grant level as `access` (libredb-studio#1922): `write` on `sales-dev` and `read` on `sales-prod`.
`ready_governed.json` is the governed Studio's `GET /api/ready`, and `ready_degraded.json` the same about 20 seconds after `governance-source` was stopped; both are recorded without a token, as are `health.json` and `ready.json` from the first Studio.
`test/infrastructure/studio/recorded_studio_answers_test.dart` reads them.
The app was also walked through on the Android emulator (API 30 Google APIs image) against the governed Studio: the SSO sign-in as `user` and the connection list with both granted connections.

## Platform

The compose profile `platform` adds LibreDB Platform 1.3.0 in self-hosted mode beside Studio and Keycloak, so the Platform answers the app depends on can be recorded from a real Platform.
Platform's `docs/api/v1.md` is the contract of its bearer API, and `docs/deploy/platform-runtime.md` the one of its variables.

| Address or service | What it is |
| --- | --- |
| `https://localhost:9445` | Platform's web console; the app's Platform API is `https://localhost:9445/api` and the bearer routes are under `/api/v1` |
| `platform-db` | PostgreSQL 18 holding Platform's database `libredb`, bootstrapped by `tool/studio-dev/platform/postgres/` |
| `platform-migrate` | The image's `migrate` command, run once before Platform starts: preflight, migrations and seed |
| `libredb-platform` | The image's `serve` command, in Caddy's network namespace on port 3002, healthy once `/api/health/ready` answers 200 |

Platform runs the 1.3.0 release image, `ghcr.io/libredb/libredb-platform:1.3.0`, pinned by its digest in the compose file; `PLATFORM_IMAGE` overrides it for both Platform services.
The image is published for `linux/amd64` only, so an arm64 host runs it under emulation.
`tool/studio-dev/platform/postgres/bootstrap.psql` and `init/01-bootstrap.sh` are byte-identical copies of `docker/postgres/` of libredb-platform `v1.3.0` (`0a84fa7`), unchanged since `v1.1.0`; copy them again from the tag of a new Platform release, never edit them.
`platform-db` has no named volume, so `down -v` starts it empty.

Start the stack with the profile and build the app against it:

```shell
docker compose -f tool/studio-dev/docker-compose.yml --profile platform up -d --wait
fvm flutter run --target lib/main/main_prod.dart --dart-define-from-file=tool/studio-dev/studio-dev-platform.env
docker compose -f tool/studio-dev/docker-compose.yml --profile platform down -v
```

Pass `--profile platform` to `down` as well, or the profile's containers stay behind.
`postgres:18` comes from Docker Hub, so on this machine use the `DOCKER_CONFIG` workaround of [Docker Hub on this machine](#docker-hub-on-this-machine).
`tool/studio-dev/studio-dev-platform.env` holds the defines of `studio-dev.env` plus `PLATFORM_API_URL=https://localhost:9445/api`; `studio-dev.env` itself has no `PLATFORM_API_URL`, so a default dev build offers no Platform entry for a Platform that is not running.
On the Android emulator, `tool/studio-dev/trust-android-emulator.sh` also forwards port 9445.

### The license

Platform in self-hosted mode needs a license, and verifies it against the keys built into the image and, when the license lists hosts, against the host of `AUTH_URL`, here `localhost`.
`libredb-platform` reads `PLATFORM_LICENSE` from two env files: the committed `tool/studio-dev/platform-license.placeholder.env` first, then the gitignored `tool/studio-dev/platform-license.local`, which wins when it exists.
The placeholder `no-license-in-tool-studio-dev` verifies as `LICENSE_MALFORMED`: Platform still starts, in state `invalid`, and logs one warn line "License invalid, no seat can be added" with `state` `invalid` and `code` `LICENSE_MALFORMED`.
Without a license no account can take an admin seat, so an admin's first call of any `/api/v1` route answers 403 `LICENSE_INVALID`, and the web console refuses the sign-in too; only the refusals of [Platform answers](#platform-answers) can be recorded.

A license that lists the host `localhost`, or no host, goes into the local file with a command that never prints it, such as:

```shell
printf 'PLATFORM_LICENSE=%s\n' "$(tr -d '\n' < ~/libredb-licenses/free-mobile-dev-localhost.license)" > tool/studio-dev/platform-license.local
docker compose -f tool/studio-dev/docker-compose.yml --profile platform up -d --wait --force-recreate libredb-platform
```

Platform reads it when `serve` starts, and then logs "License active".
Never commit the local file, and never paste a license into an issue, a pull request, a log or a fixture; never run `docker compose config` while the local file exists, because it prints the merged environment.
A license that names another host, such as a hosted Platform's, fails here with `LICENSE_HOST_MISMATCH`.

### Realm additions

The realm import carries what Platform's installer would create (`installer/src/keycloak/desired.ts`), and keeps every role, client and mapper both Studios use:

- Client `libredb`, with every flow off, holds the client roles `admin` and `user`, declared under `roles.client.libredb`.
- The flat claim `libredb_roles` carries a user's `libredb` client roles, through a client role mapper on `libredb-mobile` and on `libredb-platform`, in the ID token, the access token and userinfo.
  The mapper sits on each client rather than in a `libredb-roles` client scope, because a realm import that names any client scope gets none of Keycloak's built-in scopes, which put `sub`, `email` and `preferred_username` into every token.
- `libredb-mobile` gains a second audience mapper, so its access token carries `libredb-platform-api` beside `libredb-studio-api`.
- Client `libredb-platform` is confidential, with the standard flow, PKCE S256, the redirect `https://localhost:9445/api/auth/callback/keycloak`, the post-logout redirect `https://localhost:9445/login`, refresh tokens on and a service account.
  The service account `service-account-libredb-platform` holds the `realm-management` roles `view-users` and `view-clients`, which Platform reads the directory with.
- `admin` holds `libredb:admin` and `user` holds `libredb:user`; `norole` holds no LibreDB role.
- `admin2` / `admin2` (id `a0000000-0000-4000-8000-000000000004`) holds the realm role `admin` and `libredb:admin`, a second admin for Platform's admin seat limit.
- `disabled` (id `a0000000-0000-4000-8000-000000000005`) holds `libredb:user` and is disabled, so it cannot sign in, for the directory's `enabled` flag.

Every client keeps Full Scope Allowed on, so neither the `libredb` roles nor the service account's roles need scope mappings.
The decoded access token of `tool/studio-dev/access-token.sh admin` carries `aud` with `libredb-studio-api` and `libredb-platform-api`, `azp` `libredb-mobile`, `libredb_roles: ["admin"]`, `sub`, `email` and `preferred_username`; the token of `norole` has no `libredb_roles`.
Studio still reads `realm_access.roles`, so it signs in `admin`, `user` and `norole` as before.

## Recording Studio answers

The answers under `test/fixtures/studio/` are recorded with curl against the running stack, with an access token of the `libredb-mobile` client that `tool/studio-dev/access-token.sh` gets the way the app does, through Keycloak's login form with PKCE.
The token lives 60 seconds, so fetch a new one for each batch:

```shell
token=$(tool/studio-dev/access-token.sh admin)
record() { # record <fixture> <route> [json body], a POST when a body is given
  local body=()
  if [ -n "${3:-}" ]; then body=(-H 'Content-Type: application/json' --data "$3"); fi
  curl -sk -o "test/fixtures/studio/$1.json" -w "$1 %{http_code}\n" "https://localhost:9443/api$2" \
    -H "Authorization: Bearer $token" "${body[@]}"
}
```

Every answer was recorded again on 2026-10-24 from Studio 1.1.0, the image the compose file pins, in one run from a fresh volume with the `governed` profile, in the order of this section, as `admin` unless a step names another user.
Compared with the earlier recordings from Studio main (`dbfea263` and `c9989a6b5`), only these answers changed beyond timestamps, execution times, latencies, token ids and the subject of `admin`, which the realm import now fixes:

- `describe_postgres_orders_readonly.json` carries the primary key and the foreign key, the same answer the owner gets, because Studio 1.1.0 reads keys from `pg_catalog`.
- `search_postgres.json` sends no `sizeBytes` for the view `sales.order_totals`, which Studio before 1.1.0 sent as 0.
- `managed.json` is recorded as `user`, because the stack now holds the Postgres and Redis seeds beside the samples; it lists them and the LibreDB sample, without the SQLite sample only `admin` may open.
- The key-scan pages split the keys differently, as every Redis start does.

The answers of the SQLite sample, `health.json` and `ready.json`, the first ones recorded:

```shell
health() { curl -sk -o "test/fixtures/studio/$1.json" -w "$1 %{http_code}\n" "https://localhost:9443/api$2"; }
health health /health
health ready /ready
record me /auth/me
record policy /connections/policy
record test /db/test-connection '{"connectionId":"seed:sqlite-embedded-sample"}'
record meta /db/provider-meta '{"connectionId":"seed:sqlite-embedded-sample"}'
record containers /db/objects/containers '{"connectionId":"seed:sqlite-embedded-sample"}'
record counts /db/objects/counts '{"connectionId":"seed:sqlite-embedded-sample","container":[]}'
record list /db/objects/list '{"connectionId":"seed:sqlite-embedded-sample","container":[],"kind":"table"}'
record search /db/objects/search '{"connectionId":"seed:sqlite-embedded-sample","term":"emp"}'
record describe /db/objects/describe '{"connectionId":"seed:sqlite-embedded-sample","path":["department"],"kind":"table"}'
record query /db/query '{"connectionId":"seed:sqlite-embedded-sample","sql":"SELECT * FROM employee","options":{"limit":2,"offset":0}}'
record queryparams /db/query '{"connectionId":"seed:sqlite-embedded-sample","sql":"SELECT ? AS answer","params":[42],"options":{"offset":0}}'
record queryerror /db/query '{"connectionId":"seed:sqlite-embedded-sample","sql":"SELECT * FORM employee","options":{"offset":0}}'
record multi /db/multi-query '{"connectionId":"seed:sqlite-embedded-sample","sql":"SELECT 1 AS a; SELECT * FORM x; SELECT 3 AS c","options":{"offset":0}}'
record cancel /db/cancel '{"connectionId":"seed:sqlite-embedded-sample","queryId":"7d1c2a52-0000-4000-8000-000000000001"}'
record txstatus /db/transaction '{"connectionId":"seed:sqlite-embedded-sample","action":"status"}'
token=$(tool/studio-dev/access-token.sh user) && record managed /connections/managed
```

The Postgres answers:

```shell
record managed_postgres /connections/managed
record meta_postgres /db/provider-meta '{"connectionId":"seed:dev-postgres"}'
record meta_postgres_server /db/provider-meta '{"connectionId":"seed:dev-postgres-server"}'
record containers_postgres /db/objects/containers '{"connectionId":"seed:dev-postgres"}'
record containers_postgres_server /db/objects/containers '{"connectionId":"seed:dev-postgres-server"}'
record containers_postgres_catalog /db/objects/containers '{"connectionId":"seed:dev-postgres-server","parent":["app"]}'
record counts_postgres /db/objects/counts '{"connectionId":"seed:dev-postgres","container":["public"]}'
record list_postgres /db/objects/list '{"connectionId":"seed:dev-postgres","container":["public"],"kind":"table"}'
record describe_postgres_orders /db/objects/describe '{"connectionId":"seed:dev-postgres","path":["public","orders"],"kind":"table"}'
record source_postgres_view /db/objects/source '{"connectionId":"seed:dev-postgres","path":["sales","order_totals"],"kind":"view"}'
record source_postgres_function /db/objects/source '{"connectionId":"seed:dev-postgres","path":["sales","order_total(bigint)"],"kind":"function"}'
record search_postgres /db/objects/search '{"connectionId":"seed:dev-postgres","term":"ord"}'
record query_types_postgres /db/query '{"connectionId":"seed:dev-postgres","sql":"SELECT * FROM public.column_types","options":{"limit":50,"offset":0}}'
record query_page_postgres_first /db/query '{"connectionId":"seed:dev-postgres","sql":"SELECT * FROM sales.ledger;","options":{"limit":50,"offset":0}}'
record query_page_postgres_second /db/query '{"connectionId":"seed:dev-postgres","sql":"SELECT * FROM sales.ledger;","options":{"limit":50,"offset":50}}'
record query_page_postgres_third /db/query '{"connectionId":"seed:dev-postgres","sql":"SELECT * FROM sales.ledger;","options":{"limit":50,"offset":100}}'
record describe_postgres_orders_readonly /db/objects/describe '{"connectionId":"seed:dev-postgres-readonly","path":["public","orders"],"kind":"table"}'
record describe_postgres_room_bookings /db/objects/describe '{"connectionId":"seed:dev-postgres","path":["sales","room_bookings"],"kind":"table"}'
```

The row previews and counts of #98 were recorded the same way, from a fresh volume, with the statements the app's generator writes:

```shell
record query_preview_postgres_customers /db/query '{"connectionId":"seed:dev-postgres","sql":"SELECT * FROM public.customers;","options":{"limit":50,"offset":0}}'
record query_count_postgres_customers /db/query '{"connectionId":"seed:dev-postgres","sql":"SELECT COUNT(*) AS row_count\nFROM public.customers;","options":{"offset":0}}'
record query_preview_postgres_server_orders /db/query '{"connectionId":"seed:dev-postgres-server","sql":"SELECT * FROM app.public.orders;","options":{"limit":50,"offset":0},"catalog":"app"}'
record query_catalog_postgres_server /db/query '{"connectionId":"seed:dev-postgres-server","sql":"SELECT current_database()","options":{"limit":50,"offset":0},"catalog":"archive"}'
record query_preview_postgres_readonly_customers /db/query '{"connectionId":"seed:dev-postgres-readonly","sql":"SELECT * FROM public.customers;","options":{"limit":50,"offset":0}}'
record query_count_postgres_readonly_customers /db/query '{"connectionId":"seed:dev-postgres-readonly","sql":"SELECT COUNT(*) AS row_count\nFROM public.customers;","options":{"offset":0}}'
```

The SQL editor's answers of #113 were recorded the same way, from a fresh volume, after `seed:dev-postgres-prod` joined the seeds, together with `managed_postgres.json` above, which lists it:

```shell
record queryerror_postgres /db/query '{"connectionId":"seed:dev-postgres","sql":"SELEC 1","options":{"offset":0}}'
record query_begin_postgres /db/query '{"connectionId":"seed:dev-postgres","sql":"BEGIN","options":{"offset":0}}'
record query_update_postgres /db/query '{"connectionId":"seed:dev-postgres","sql":"UPDATE public.orders SET status = status WHERE id <= 2","options":{"offset":0}}'
```

`queryerror_postgres.json` carries `details.position` as the string `"1"`, as node-postgres reports it, and `query_begin_postgres.json` answers `openTransaction: "rolled-back"`.
Studio (at `c9989a6b5` and at 1.1.0) refuses `readOnly: true` on a Postgres seed (`READ_ONLY_ENFORCED.postgres` is false in `src/lib/db/compatibility.ts`, and the seed file then fails to load), so `seed:dev-postgres-readonly` is not marked read only; a confirmed `DELETE FROM orders WHERE false` there answers 403 `PERMISSION_DENIED` from the role's grants.

The cancel answers of #116 were recorded against a running `SELECT pg_sleep(30)`, with the cancel posted two seconds after the run while its request was still open; the run's request writes its 499 when the cancel lands:

```shell
record query_cancelled_postgres /db/query '{"connectionId":"seed:dev-postgres","sql":"SELECT pg_sleep(30)","options":{"offset":0},"queryId":"7d1c2a52-0000-4000-8000-00000000000b"}' &
sleep 2
record cancel_postgres /db/cancel '{"connectionId":"seed:dev-postgres","queryId":"7d1c2a52-0000-4000-8000-00000000000b"}'
wait
```

`cancel_postgres.json` answers `{"cancelled":true}` and `query_cancelled_postgres.json` the 499 `QUERY_CANCELLED`.
A cancel posted after the run's request was dropped answers `{"cancelled":false}`, because Studio's abort bridge had already stopped the run.

The script answers of #117 were recorded the same way, from a fresh volume, with the first page the editor sends for a script:

```shell
record multi_postgres /db/multi-query '{"connectionId":"seed:dev-postgres","sql":"SELECT 1 AS a; SELECT * FROM nope; SELECT 3 AS c","options":{"offset":0},"queryId":"7d1c2a52-0000-4000-8000-000000000117"}'
record multi_postgres_rows /db/multi-query '{"connectionId":"seed:dev-postgres","sql":"SELECT 1 AS a; SELECT 2 AS b","options":{"offset":0},"queryId":"7d1c2a52-0000-4000-8000-000000000118"}'
```

`multi_postgres.json` stops at the failed second statement, so `executedCount` is 2 of 3, and neither answer carries `pagination`.
In the same run `SELECT pg_sleep(40); SELECT pg_sleep(40)` answered both statements after 80 seconds, a dollar-quoted `CREATE FUNCTION` with a `;` in its body ran as one statement, and `/db/cancel` posted two seconds into `SELECT pg_sleep(30); SELECT pg_sleep(30)` answered `{"cancelled":true}` while the script answered 200 with its first statement failed as `Query was cancelled` and the second not run.

The three `query_page_postgres_*.json` pages were recorded from a fresh volume.
The first answers `hasMore: true`; the second answers `hasMore: false`, since Studio asks for one row past the page and that row is missing; the third, past the last row, has no rows and pins the append of an empty page.

The Redis answers were recorded as `admin` from the same image.
The key-scan pages walk `user:*` in database 1 with Studio's default batch: the first page is asked without a cursor, every later page with the cursor of the page before, and `keyscan_next.json` is the second page and `keyscan_last.json` the one whose cursor is back at `0`.
`keyscan_requests.json` keeps the body each of the three was asked with, so a test can check that they chain.
Redis picks a random hash seed at every start, so a re-recording gets other cursors and splits the keys into pages differently.
The test expects exactly three pages, which this recording gave; a re-recording that takes another number of pages needs the test adjusted along with the fixtures.

```shell
record meta_redis /db/provider-meta '{"connectionId":"seed:dev-redis"}'
record containers_redis /db/objects/containers '{"connectionId":"seed:dev-redis"}'
record counts_redis /db/objects/counts '{"connectionId":"seed:dev-redis","container":["1"]}'
scan='{"connectionId":"seed:dev-redis","pattern":"user:*","database":1}'
requests='{}'
page=0
while :; do
  page=$((page + 1))
  case $page in 1) name=keyscan_first ;; 2) name=keyscan_next ;; *) name=keyscan_page ;; esac
  record "$name" /db/keys/scan "$scan"
  requests=$(jq --arg name "$name" --argjson body "$scan" '.[$name] = $body' <<<"$requests")
  cursor=$(jq -r .cursor "test/fixtures/studio/$name.json")
  if [ "$cursor" = 0 ]; then break; fi
  scan=$(jq -c --arg cursor "$cursor" '.cursor = $cursor' <<<"$scan")
done
mv test/fixtures/studio/keyscan_page.json test/fixtures/studio/keyscan_last.json
jq '.keyscan_last = .keyscan_page | del(.keyscan_page)' <<<"$requests" > test/fixtures/studio/keyscan_requests.json
```

One typed read per key type in database 1, each the statement Studio's key browser generates for that type (`REDIS_COMMANDS` in Studio's `src/lib/query-generators.ts`), for the key reads of #32:

```shell
read_key() { # read_key <fixture> <command>
  record "$1" /db/query "$(jq -nc --arg sql "$2" '{connectionId: "seed:dev-redis", sql: $sql, database: 1}')"
}
read_key query_redis_string 'GET cache:greeting'
read_key query_redis_json 'GET user:2:profile'
read_key query_redis_hash 'HGETALL user:2'
read_key query_redis_list 'LRANGE session:2:events 0 -1'
read_key query_redis_set 'SMEMBERS user:2:roles'
read_key query_redis_zset 'ZRANGE cache:leaderboard 0 -1 WITHSCORES'
read_key query_redis_stream 'XRANGE session:2:log - + COUNT 100'
```

The transaction answers come from one database of the server-level seed, recorded after every other Postgres answer because the `UPDATE` changes a row:

```shell
record txbegin /db/transaction '{"connectionId":"seed:dev-postgres-server","action":"begin","catalog":"app"}'
record txquery /db/transaction '{"connectionId":"seed:dev-postgres-server","action":"query","sql":"UPDATE public.orders SET status = '"'"'paid'"'"' WHERE id = 2","options":{"limit":50,"offset":0},"catalog":"app"}'
record txcommit /db/transaction '{"connectionId":"seed:dev-postgres-server","action":"commit","catalog":"app"}'
```

The pair limit of the object search needs more container and kind pairs than the seed holds, so 150 empty schemas are added to `app` for these two answers and dropped after them; 152 schemas of 7 kinds are 1,064 pairs, over Studio's 1,000:

```shell
pg() { docker compose -f tool/studio-dev/docker-compose.yml exec -T postgres psql -q -U postgres -d app -v ON_ERROR_STOP=1 -c "$1"; }
pg "DO \$\$ BEGIN FOR i IN 1..150 LOOP EXECUTE format('CREATE SCHEMA pair_limit_%s AUTHORIZATION app_owner', lpad(i::text, 3, '0')); END LOOP; END \$\$;"
record search_postgres_pair_limit /db/objects/search '{"connectionId":"seed:dev-postgres","term":"ord"}'       # 400 INVENTORY_PAIR_LIMIT
record search_postgres_kinds /db/objects/search '{"connectionId":"seed:dev-postgres","term":"ord","kinds":["table","view"]}'
pg "DO \$\$ BEGIN FOR i IN 1..150 LOOP EXECUTE format('DROP SCHEMA pair_limit_%s', lpad(i::text, 3, '0')); END LOOP; END \$\$;"
```

`search_postgres_pair_limit.json` carries the code `INVENTORY_PAIR_LIMIT` with `limit` 1000 and `pairs` 1064, from Studio 1.1.0 on; Studio before it answered the same 400 without a code.

The governed answers come from the governed Studio at `https://localhost:9444/api`, with `record` pointed there:

```shell
health ready_governed /ready                                    # with health() pointed at port 9444 as well
token=$(tool/studio-dev/access-token.sh user) && record managed_governed /connections/managed
token=$(tool/studio-dev/access-token.sh user) && record policy_governed /connections/policy
token=$(tool/studio-dev/access-token.sh admin) && record admin_governance /admin/governance
docker compose -f tool/studio-dev/docker-compose.yml --profile governed stop governance-source
sleep 20
health ready_degraded /ready
token=$(tool/studio-dev/access-token.sh user) && record governance_unavailable /connections/managed  # 503 GOVERNANCE_UNAVAILABLE
```

The refusals of `GET /api/auth/me` and the sign-out, last, from the first Studio:

```shell
token=$(tool/studio-dev/access-token.sh norole) && record me_norole /auth/me     # 403 BEARER_NO_ROLE
token=$(tool/studio-dev/access-token.sh admin) && record logout /auth/logout '{}'
token=$(tool/studio-dev/access-token.sh user) && sleep 100 && record me_expired /auth/me
docker compose -f tool/studio-dev/docker-compose.yml stop keycloak
docker compose -f tool/studio-dev/docker-compose.yml restart libredb-studio
record me_idp_unavailable /auth/me                                                # with a token fetched before the stop
```

`me_expired.json` is the 401 `AUTH_REQUIRED` of a token past its 60 seconds and Studio's 30 second clock tolerance, sent with `WWW-Authenticate: Bearer error="invalid_token"`.
`me_idp_unavailable.json` is the 503 `IDENTITY_PROVIDER_UNAVAILABLE` of a Studio restarted while Keycloak is stopped, so it has no signing keys cached to check the token with.

`test/infrastructure/studio/recorded_studio_answers_test.dart` reads every one of them.

### Platform answers

The answers under `test/fixtures/platform/` are recorded the same way from the `platform` profile, with `record_platform`, which sends the token only when `token` is set and passes any further arguments to curl:

```shell
record_platform() { # record_platform <fixture> <route under /api/v1> [more curl arguments, such as -X PUT --data ...]
  local fixture=$1 route=$2 args=()
  shift 2
  if [ -n "${token:-}" ]; then args=(-H "Authorization: Bearer $token"); fi
  curl -sk -o "test/fixtures/platform/$fixture.json" -w "$fixture %{http_code}\n" "https://localhost:9445/api/v1$route" \
    "${args[@]}" "$@"
}
```

The refusals of `GET /api/v1/me` were recorded on 2026-10-25 from Platform 1.3.0, the image the compose file pins, from a fresh volume with the placeholder license, in this order:

```shell
token= && record_platform me_no_token /me                                                  # 401 BEARER_INVALID
token=$(tool/studio-dev/access-token.sh user) && record_platform me_not_admin /me        # 403 ADMIN_ROLE_REQUIRED
token=$(tool/studio-dev/access-token.sh norole) && record_platform me_norole /me         # 403 ADMIN_ROLE_REQUIRED
token=$(tool/studio-dev/access-token.sh admin) && record_platform me_license_invalid /me  # 403 LICENSE_INVALID
token=$(tool/studio-dev/access-token.sh admin) && sleep 95 && record_platform me_expired /me  # 401 BEARER_INVALID
PLATFORM_API_AUDIENCE= docker compose -f tool/studio-dev/docker-compose.yml --profile platform up -d --wait libredb-platform
token=$(tool/studio-dev/access-token.sh admin) && record_platform me_api_disabled /me     # 404 API_DISABLED
docker compose -f tool/studio-dev/docker-compose.yml --profile platform up -d --wait libredb-platform
token=$(tool/studio-dev/access-token.sh admin)
docker compose -f tool/studio-dev/docker-compose.yml --profile platform stop keycloak
docker compose -f tool/studio-dev/docker-compose.yml --profile platform restart libredb-platform
record_platform me_idp_unavailable /me      # 503 IDENTITY_PROVIDER_UNAVAILABLE, with the token fetched before the stop
docker compose -f tool/studio-dev/docker-compose.yml --profile platform up -d --wait
```

`me_expired.json` is the answer to a token past its 60 seconds and Platform's 30 second clock tolerance.
`me_api_disabled.json` comes from Platform recreated with `PLATFORM_API_AUDIENCE` empty, which turns the bearer API off; the plain `up` after it turns it on again.
`me_idp_unavailable.json` comes from Platform restarted while Keycloak is stopped, so it has no signing keys cached and Caddy answers its discovery read with 502.
`test/infrastructure/platform/recorded_platform_answers_test.dart` reads every one of them.
