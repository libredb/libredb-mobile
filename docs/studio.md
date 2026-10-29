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

#### The development AVDs and their screen lock

The checks against this stack use two AVDs on a Google APIs x86_64 image; Chrome opens the Keycloak sign-in in a Custom Tab on both, but the two differ in their Chrome and their screen lock:

| AVD | Image | Chrome | Screen lock |
| --- | --- | --- | --- |
| `libredb-dev-api30` | `system-images;android-30;google_apis;x86_64`, Android 11 | 83, the system app under `/product/app/Chrome` | None |
| `libredb-dev-api33` | `system-images;android-33;google_apis;x86_64`, Android 13 | 109, an update under `/data/app` over the system Chrome-Stub | PIN `1111` |

`libredb-dev-api33` carries the PIN because the app lock checks of [#195](https://github.com/libredb/libredb-mobile/issues/195) run on it, and the app lock asks for the device's screen lock.
After a boot its user stays `RUNNING_LOCKED` until the PIN is entered, and while it is locked the credential-encrypted storage is closed.
The Chrome update under `/data/app` is not aware of direct boot, so until the unlock Android resolves no activity for a web link: `am start -a android.intent.action.VIEW -d https://example.com` opens nothing, the app's "Sign in with SSO" finds no browser for the Custom Tab, and `am start` of the app itself can answer "Activity class does not exist".
The browser is not missing; unlock the user once after every boot of `libredb-dev-api33`, before the trust script or the app:

```shell
adb -s emulator-5554 shell am get-started-user-state 0   # RUNNING_LOCKED until the PIN is entered
adb -s emulator-5554 shell input keyevent 82
adb -s emulator-5554 shell input text 1111
adb -s emulator-5554 shell input keyevent 66
adb -s emulator-5554 shell am get-started-user-state 0   # RUNNING_UNLOCKED
adb -s emulator-5554 shell cmd package resolve-activity --brief -a android.intent.action.VIEW -c android.intent.category.BROWSABLE -d https://example.com
```

The last command names `com.android.chrome/com.google.android.apps.chrome.IntentDispatcher` once the user is unlocked.
To remove the PIN from an unlocked AVD for good, run `adb -s emulator-5554 shell locksettings clear --old 1111`; `locksettings set-pin 1111` sets it again before an app lock check.

`libredb-dev-api30` boots `RUNNING_UNLOCKED` and resolves Chrome for a web link with no unlock, so it needs none of these steps.
An app lock check on it, such as the recents check below Android 13 in #195, first sets a PIN with `locksettings set-pin 1111`, and from then on its user stays `RUNNING_LOCKED` after each boot until the PIN is entered, as on `libredb-dev-api33`, until `locksettings clear --old 1111` removes it.

Checked on 2026-10-25 (#258) with the stack on the pinned Studio 1.1.0 image and a debug APK of `main_prod.dart` with `studio-dev.env`: on `libredb-dev-api33` the steps above unlock the user, `https://example.com` then opens in Chrome, and after the trust script "Sign in with SSO" opens the Keycloak page `https://localhost:8443` in a Custom Tab and the sign-in as `user` / `user` lands on the connection list.
On `libredb-dev-api30`, `https://example.com` opens in Chrome right after the boot, and "Sign in with SSO" opens the same Keycloak page.

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
  #419 locks portrait again on 2026-10-29, on every form factor, so step 3's rotation above describes a build that no longer exists and nothing re-runs it; what still exercises the kept state is a window the system resizes, which [The landscape half of step 3 and the rotation of step 7 are withdrawn](#the-landscape-half-of-step-3-and-the-rotation-of-step-7-are-withdrawn-419) describes.

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

## M6 walkthrough against the Railway deployment

The first run of #196's steps against a real deployment rather than a local stack, on 2026-10-28 from `main` at
`01f1cee`, built with Flutter 3.47.7 as a debug APK of `main_prod.dart` with
`--dart-define=PROD_API_URL=https://studio-dev.libredb.org/api`,
`--dart-define=OIDC_ISSUER=https://auth-dev.libredb.org/realms/libredb` and
`--dart-define=OIDC_CLIENT_ID=libredb-mobile`.
The device was the Android emulator with the AVD `libredb_lab_api30`: API 30 Google APIs image, Android 11,
`sdk_gphone64_arm64`. The account was `studio-user1`, which holds the Studio role `User`.

`mobile-docs/google-play-steps.md` J.2 is what sets the target: *"Kalan adımları Mobile ekibi test telefonunda
Railway'e karşı çalıştırır"*. This run is that, on an emulator rather than the test phone, so the two steps that
need real hardware — the fingerprint unlock and the Sentry event — are not in it.

| Step | Result |
| --- | --- |
| 1. Sign in; role; governance chip | Passed: the custom tab opens `auth-dev.libredb.org` with a valid certificate and no interstitial, the Keycloak form signs in, and the app lands on the connection list. The profile sheet shows `studio-user1@example.com`, the role **User**, and the chip "Governed by LibreDB Platform". No Platform entry, which is right for a Studio-only account |
| 3. Connection list | Passed: four connections under the group "Samples" — Periodic Table, Postgres Air, Titanic and Wikipedia Embeddings — each with the DEV badge and the "Read only" lock, and the DEV environment chip above them |
| 4. Reopening | Passed in part: after the app was sent to the background and started again, `SessionCubit` restored the stored token (`restore: token found for studio`) and opened on the connection list with Titanic still marked active and listed under "Recent". The connection check and the switcher were not exercised |
| 5. Browse | Passed: Titanic's `public` schema reads Tables 1 and every other kind 0; the tables list shows `passenger` with **1,309 rows · 408 KB**; the table page shows the real columns with `passengerid` marked as the key, the types, the nullable markers and the Indexes and Foreign keys tabs; "View rows" opens the rows |
| 7. Editor | Passed in part: the editor binds to the active connection and shows its DEV badge and lock. A statement that the analysis cannot classify raised the confirmation sheet, which named the connection, the environment and "May change data: SELSELECT on line 1" before offering Cancel and Run — the written confirmation of #196/7, working. A clean statement was not run to a result, for the reason in the notes |
| 10. Nothing leaks to logcat | Passed: 19,114 lines of `adb logcat` taken after the sign-in, the browse and two editor runs hold **no** `Bearer` token, no `access_token`, `refresh_token` or `id_token`, no password, and no statement text. The app's own lines name screens and outcomes only: a failed run reads `StatementRepository : run failed: studio.query_error`, the code and not the database's message |

Also confirmed, outside the numbered steps:

- **Screen capture protection.** Every screen that shows data refuses `adb shell screencap`: the file comes back
  empty on the rows view and on the editor once it holds a result, and is normal on the connection list and the
  schema page. That is the prod-only `screenCaptureProtection` of step 50, measured rather than argued.
- **The product's mark ships.** The login screen draws the brand mark of `BrandMark` rather than a Material glyph,
  and the onboarding flow's four panels render with the adoption figures from `assets/adoption.json`.

### What this run did not cover, and why

- **Steps 2, 6, 8 and 9.** The app lock needs a device credential and a fingerprint enrolled on real hardware;
  masked fields and `Load more` need a table with a masked column, which the sample connections do not have;
  revoking a grant needs a Platform admin to revoke one while the app is open; "Remove my data" and the sign-out
  were left for a run that does not end on a shared deployment's session.
- **A statement run to a result.** Driving the editor through `adb shell input` proved unreliable: the text field
  kept its earlier contents through a long `KEYCODE_DEL` run, so the statement that reached Studio was
  `selselect 1` and came back `studio.query_error`. That is this run's fault and not the app's — and the
  confirmation sheet above is the evidence that the editor reached Studio and that the analysis ran. A result row,
  a cancel, a script and the history belong to the test-phone run, where a person types.
- **Step 11 (prod: the certificate pins).** The pins are a prod-build concern and this was a debug build.

### The lab VM was not this walkthrough's target

The first attempt ran against the Lima VM `libredb-lab` and could not complete a sign-in; the reasons are recorded
in #393. The lab has since been brought up to a state where it does carry a sign-in, which is the walkthrough
below.

## M6 walkthrough against the Lima lab

The same steps against the Lima VM `libredb-lab`, on 2026-10-28, built with Flutter 3.47.7 as a debug APK of
`main_local.dart` with its own defaults — `https://sso.lab.test/realms/libredb`, `https://studio.lab.test/api` and
`https://libredb.lab.test/api`. The device was the Android emulator with the AVD `libredb_lab_api30`: API 30 Google
APIs image, so `adb root` works and the CA can go into the system store. The account was `mobile-test`, which holds
the Keycloak client role `libredb:user` and a `read` grant on the lab's one connection.

The Railway run above could not drive the editor to a result, so that is what this one is for.

### What the lab needed first

The lab could not carry a mobile sign-in as it stood, and none of the four reasons was a property of the app. Each
was measured rather than assumed, and the first one hid the next three.

| What blocked it | What it was | What was done |
| --- | --- | --- |
| The edge certificates | The installer issues leaf certificates for 825 days. Every browser refuses a leaf valid longer than 398, so the Keycloak form never loaded | Re-issued the three edge leaves from the kept internal CA at 397 days, with the same keys, so nothing that already trusts the CA had to change |
| Studio's bearer channel | The lab's Studio build has no `OIDC_BEARER_*` anywhere in its server bundle, so no configuration could make it answer a bearer request | Put the lab on Studio 1.1.0 — the digest `tool/studio-dev` pins — and set `OIDC_BEARER_AUDIENCE=libredb-studio-api` and `OIDC_BEARER_CLIENT_IDS=libredb-mobile` |
| Platform's bearer API | Platform 1.0.1 has no `/api/v1` at all; `/api/v1/me` answered 404 `API_DISABLED` once it did | Put the lab on Platform 1.3.0 and set `PLATFORM_API_AUDIENCE` and `PLATFORM_API_CLIENT_IDS`. 1.3.0 ships no arm64 image, so both Platform services declare `platform: linux/amd64` and run under the VM's Rosetta. Every database was dumped before the one migration this brought |
| The realm | No `libredb-mobile` client, and no user holding both the Studio role and a grant | Created the client from the definition in `tool/studio-dev/docker-compose.yml`, which carries the two audience mappers and the `libredb_roles` mapper; created `mobile-test`, gave it `libredb:user`, and granted it the connection through Platform's own `PUT /api/v1/connections/{id}/grants/{subject}` |

**All four are hand changes to the VM, and the durable fix is the installer's.** `tool/installer-lab/libredb.yaml.example`
already describes what the lab wants — `mobile.enabled: true`, and `tls.mode: provided` so the owner's own chain is
served instead of an 825 day internal one — but the installer binary in the VM predates that schema and rejects the
key `mobile` outright, so the configuration cannot simply be adopted. Upgrading the installer, not patching the
containers, is what makes this reproducible.

### What the installer must do, and whose it is

Read on 2026-10-29 from the installer binary the lab was installed with, `/opt/libredb/bin/libredb-installer`. It is
a Bun single-file executable that keeps its own sources readable, so every claim below is a quotation from it rather
than a guess. Nothing on the lab was changed: the commands were `version`, `validate` on a throwaway configuration in
`/tmp`, `openssl s_client` against the edge, an unauthenticated `GET` of the realm's authorization endpoint, and
`grep` over the binary's strings.

**The version is the whole of it.** `libredb-installer version` prints `libredb-installer 1.0.0` / `release 1.0.0`.
`tool/installer-lab/libredb.yaml.example` is written for installer 1.3.0, and 1.0.0 has no `mobile` section in its
schema at all — not a reserved name, not a validation rule, but a key that does not exist. `src/config/schema.ts`
builds the root object from `head`, `mode`, `tail` and `docker` and closes it with `.strict()`, and `tail` is
`endpoints`, `tls`, `postgres`, `keycloak`, `platform`, `images`, `network`, `backups`, `bridge` — no `mobile`. Zod's
`unrecognized_keys` is what comes back, measured on a configuration that is otherwise the example's:

```
$ libredb-installer validate -c /tmp/probe.yaml
invalid configuration:
  (root): Unrecognized key: "mobile"
                                     # exit 2; the same file with the mobile block removed validates, exit 0
```

**What a lab would need at birth.** The working definition is the realm block of `tool/studio-dev/docker-compose.yml`
and the bearer variables beside it. Against what installer 1.0.0 produces, the difference is:

| What is needed | What installer 1.0.0 does |
| --- | --- |
| A public client `libredb-mobile`, standard flow only, PKCE `S256`, `org.libredb.mobile:/oauth2redirect` as redirect and post-logout URI | Creates two clients and no third: `desiredKeycloak` in `src/keycloak/desired.ts` returns `appClients: [libredb-studio, libredb-platform]`. Its one factory, `appClient()`, hard-codes `publicClient: false` with `clientAuthenticatorType: "client-secret"`, so it cannot express a public client even if a third entry were added |
| Two `oidc-audience-mapper` mappers on that client, for `libredb-studio-api` and `libredb-platform-api` | Has no audience mapper of any kind: `audience`, `oidc-audience-mapper` and `included.custom.audience` appear nowhere in the binary |
| A `libredb_roles` client-role mapper reaching that client's tokens | Present, but only as the client scope `libredb-roles`, added to each app client's `defaultClientScopes`. A `libredb-mobile` the installer does not create gets no scope, so no `libredb_roles` claim |
| `OIDC_BEARER_AUDIENCE` and `OIDC_BEARER_CLIENT_IDS` on Studio | Neither string is in the binary. `STUDIO_ENV` in `src/contracts/studio.ts` carries `OIDC_CLIENT_ID` and `OIDC_ROLE_CLAIM` and no bearer key, and `renderEnv` builds the file from `Object.keys(descriptors)`, so an `apply` rewrites `/opt/libredb/env/studio.env` and drops anything added by hand |
| `PLATFORM_API_AUDIENCE` and `PLATFORM_API_CLIENT_IDS` on Platform | Neither string is in the binary either, and release 1.0.0 pins Platform 1.0.1, which has no `/api/v1` to enable |
| A leaf certificate a browser accepts, 398 days or fewer | `src/tls/leaf.ts` opens `var LEAF_VALIDITY_DAYS = 825;` — a constant with no configuration path, used by `issueLeaf` for every generated leaf |

**The certificate half is configurable today, the client half is not.** `tls.mode: provided` is already in 1.0.0's
`tls` enum and validates there, so a lab given the owner's own chain never meets the 825 day leaf. Only
`tls.mode: generated` is capped at 825, and it is the mode the lab was installed in. A `mobile` client has no such
escape: no key, no flag, no `--set` reaches it. The one documented path around it is `keycloak.mode: external` with
`provisioning: manual`, where `libredb-installer keycloak export` hands the site the realm objects and the site
configures its own realm — which is a different installation, not a lab born working.

**An `apply` would undo less than feared, and it was worth measuring.** The Keycloak planner has no `delete-client`
and no `delete-user` action; its only removals are `delete-mapper` and `remove-optional-scope`, both scoped to the
objects it owns. `foreignObjects` walks `[desired.roleClient, ...desired.appClients]` and `desired.users` only, so
`libredb-mobile` and `mobile-test` are invisible to it and survive. The TLS plan would keep the hand-reissued leaves
too: `planLeaf` re-issues only when a leaf is missing, uncovered, unreadable, off the CA, or inside
`RENEW_BEFORE_DAYS = 30` of expiry, and the three edge leaves measured
`notBefore=Oct 28 14:47:01 2026 GMT`, `notAfter=Nov 29 14:47:01 2027 GMT` — 397 days, 396 of them left. What an
`apply` does undo is the container half: the rendered `/opt/libredb/compose.yaml` goes back to release 1.0.0's
digests (Studio `sha256:0cb0177d…`, Platform `sha256:b42e3467…`, against the live `sha256:e91183de…` and
`sha256:e53ca9b8…`) and loses the `platform: linux/amd64` lines, and the env files lose the four bearer variables.

**This is not ours to fix.** Nothing above is in this repository. The ask, for whoever owns the installer:

1. Keep the `mobile` section of the 1.3.0 schema, and let the installer in a lab be one that has it — the lab's is
   1.0.0 and rejects the key. For this repository's purposes `mobile.enabled: true` must produce the public client,
   both audience mappers, the `libredb_roles` claim, and the bearer variables on Studio and Platform, since a phone
   that gets the client but not the audience is refused by Studio instead of by Keycloak.
2. Cap `LEAF_VALIDITY_DAYS` at 398 or fewer for `tls.mode: generated`. 825 days was the ceiling before September
   2020; every browser has enforced 398 since, and installing the CA does not lift it, so a generated lab is unreachable
   through a browser and therefore unable to carry an OIDC sign-in. `tls.mode: provided` is the only way around it
   today, and it asks the owner for a chain a lab should not need.

Until a lab is born with both, `docs/studio.md` above is the hand procedure, and this repository can do nothing but
record it.

### Results

| Step | Result |
| --- | --- |
| 1. Sign in; role; governance chip | Passed: the custom tab loaded Keycloak on `sso.lab.test` with no interstitial, the form signed in, and the app landed on the connection list. The profile sheet shows `mobile-test@lab.test`, the role **User**, the chip "Governed by LibreDB Platform", and a "Switch to Platform" entry |
| 2. The app lock | Passed, on the emulator: the switch is disabled while the device has no screen lock and says so — "Set a screen lock on this device to turn this on". With a PIN set it becomes live; turning it on raises the system's own prompt first, so the lock cannot be enabled by someone who cannot already unlock the phone. With the delay set to **Hemen** the app came back from the background locked — "LibreDB kilitli", offering **Kilidi aç** and **Çıkış Yap** — and a fingerprint unlocked it to the screen it had left. The emulator holds both a credential and an enrolled print, so none of this needed a phone |
| 3. Connection list | Passed: one connection, "Deneme DVD Rental" / `dvdrental`, under the group "Deneme" with its count, carrying the LOCAL badge and the "Read only" lock, with the LOCAL environment chip above it |
| 5. Browse | Passed: the schema `public`, then 15 tables, 7 views, 0 materialized views, 13 sequences, 9 functions, 0 procedures and 15 triggers — the same counts `POST /api/db/objects/counts` answers. The table list carries each table's row count and size (`actor` 200 rows · 72 KB, `film` 1000 rows) |
| 4. The check, the switcher, reopening and the offline strip | Passed: a long press on the connection opens its sheet, whose **Check** sent `POST /api/db/test-connection` and came back `online, 3 ms, 0 warnings`. The switcher is a sheet of its own with its own search, the environment chip and the active connection marked. Sent to the background and brought back, the app returned to the schema list it was on. In aeroplane mode the system strip reads "No internet connection" and the app's own, under the bar, reads **"Offline: showing what was loaded at 7:44 PM"** — it names the time the cached answers are from. Turning the radio back on, `ConnectivityService` logged `wifi` and the screens recovered without a retry |
| 6. Masked fields, `Load more` and the clipboard | Passed: `customer` of the DVD Rental sample opened at **50 rows, 7 ms** beside a `limited` chip and a line that says what the limit costs — "Without an ORDER BY the engine may return rows that repeat or are skipped between pages." `Load 50 more` took it to **100 rows**. `email` carries a lock beside its name and reads `j********@s****************`, in the card and in the row detail, **as `user` and as `admin` alike**: `shouldMask` gives an admin the config's own flag, the lab's Studio has masking on, and no screen offers the toggle or the reveal before M7-13 (#35) — so the two roles agreeing is the rule working, not the test failing. The row detail is "Row 1 of 100" with each field's name, type and value, a copy beside each and "Copy row as JSON" above. Copying the masked field copies **the mask**: `fieldCopyText` returns the masked string for a masked column, and it goes out through `SensitiveClipboard`, which marks the clip `EXTRA_IS_SENSITIVE` — a flag this emulator cannot show, since it hides the preview only on Android 13 and later and this is API 30 |
| 7. Editor | Passed: `select count(*) as films from film` ran to **1 row, 8 ms**, the list view showed `1000` and the table view the column `films` of type `bigint`; `select title from film limit 3` to **3 rows, 1 ms** of real titles. The editor's own keyboard row (`; , ( ) * ' " =`) appears above the system keyboard. A deliberately broken statement answered "The statement failed." with the engine's text and the app's note that Studio added `LIMIT 501`, so a position the error names may be in that clause. **History** holds each run with its connection, status, row count, duration and time, behind All / Succeeded / Failed and a search. A **script** of two statements and a **write** raised the confirmation sheet together: "May change data: UPDATE on line 1", "Runs more than one statement", and the lock line below. Cancel left the text as it was, and the **draft** survived leaving the tab and coming back. A `select pg_sleep(20)` turned Run into **Cancel**, which sent `POST /api/db/cancel -> 200` and left a quiet "Cancelled" line rather than an error. A `select pg_sleep(15)` started, the app sent to the background two seconds later and brought back seven seconds after that, answered **1 row, 15,022 ms** — the request outlived the app's own foreground |
| 8. Revoking a grant | Passed: with the app open, Platform's `DELETE /api/v1/connections/{id}/grants/{grantId}` answered 204, and the connection list emptied to "No databases have been granted to you yet. Ask an administrator for access." — the empty state, not an error. Granting it again brought the connection back on the list's own 10 second poll, with no pull to refresh. The connection was on the list rather than open, so the message for a connection that disappears under the user was not the one this exercised |
| 9. "Remove my data" and the sign-out | Passed: the dialog names what goes (drafts, statement history, starred and recent connections, the last open connection, the collapsed sections) and what stays (language, theme, result view, app lock), and says the sign-out follows. Confirming posted `POST /api/auth/logout -> 200`, cleared the target, the tokens and the cached responses, and the router redirected to `/login` with `SessionUnauthenticated`. The provider session went with it: the user's remaining Keycloak sessions were all from this walkthrough's own API calls at the Docker gateway address, none from the emulator |
| 10. Nothing leaks to logcat | Passed: of 443 lines the app wrote across the whole run, none carries statement text, an access token, an e-mail address or a database error text, and the only line that comes near one reads `fetch: role user, bearer [REDACTED]` |

### What this run did not cover, and why

- **Step 11 and the prod steps.** This was a debug build of `main_local.dart`, which carries no certificate pins and
  no `screenCaptureProtection`.

### The landscape half of step 3 and the rotation of step 7 are withdrawn (#419)

#196's step 3 asks for the connection list "in landscape with the keyboard up" and its step 7 for a rotation during a
result. Since 2026-10-29 the app is held upright on every form factor, in all three places — the bootstrap, the
Android manifest and both keys of `Info.plist` ("Orientation" in [architecture.md](architecture.md)) — so no device
reaches either state by turning, and neither part is run as a rotation again. What replaces them is the same two
checks in a window the system sizes rather than the app, since that ignores the lock: the connection list in a
split-screen window short enough for the rail, with the keyboard up, and a split-screen resize over a result. A
full-screen tablet is not the replacement — it never reports the short layout, measured in "Orientation".
The rest of both steps is unchanged — the list's groups, search, badges, read-only markers, stars and recents, and the
editor's run, error position, cancel, script, typed confirmation, history and drafts.

### The prod steps, from a release build

Steps 1 and 11 of #196 need a release build, which the lab run was not, so they were taken separately on
2026-10-28: `fvm flutter build apk --release --target lib/main/main_prod.dart`, installed on the same emulator.
The build needs no secret — `android/app/build.gradle.kts` falls back to the debug key when the upload signing
values are absent, and says which key it used: *"Release build signed with the debug key."*

| Step | Result |
| --- | --- |
| 1. A release build carries no DEBUG banner | Passed: the welcome screen and the login page draw no ribbon in the corner, which a debug build does |
| 11. The certificate pins are valid | **Not applicable to a shipping build, which is the finding.** `docs/release.md` lists `STUDIO_CERT_PINS` and `OIDC_CERT_PINS` as "No; pinning ships off", and `AppConfig.prod` reads them from defines that default to empty — so a store build carries no pin and there is nothing for this step to verify. What the run does show is that the launch health check reached `https://studio-dev.libredb.org/api/health` and the login page opened with no "Studio is unreachable" state; that is TLS against the public chain, not a pin. Verifying a pinned build means setting the two variables and rebuilding, which is a different exercise and belongs to whoever decides to turn pinning on |

Two things worth recording from the same build, neither of them a step:

- The login page of a prod release offers **only** "Sign in with SSO". The Platform entry is absent, which is what
  `docs/release.md` says the store build does until M12-P passes — the first time that has been seen rather than
  read. The version label reads `v1.0.0+1`.
- A release build prints none of the app's own log lines to logcat, so the health call cannot be read there. That is
  the hygiene working, and it is also why the health check is read from the screen rather than from the log.
- The first answer written for step 11 was wrong and is worth leaving a trace of: the quiet login page was read as
  the pins having matched. There were no pins. A page that does not say "unreachable" proves the request succeeded
  and nothing about how it was trusted, and the difference is the whole point of the step.

### The screenshot step, from the same release build

Step 9's screen-capture half, taken on 2026-10-28 against `studio-dev.libredb.org` with the release APK and the
demo account `studio-user1` that `mobile-docs/google-play-steps.md` D sets up. The earlier note here said the step
needed an account this run did not have; the account was written down the whole time, and so was where its password
lives.

| What | Result |
| --- | --- |
| A screenshot of a result | **Blocked**: `adb exec-out screencap` wrote a **0 byte** file on the rows of `periodic_table` (118 rows). The login page, by contrast, screenshots normally at 123 KB — which is the design, not a gap |
| The recent-apps preview | **Carries nothing**: the card is blank, with the app's mark above it and no trace of the rows behind. On this launcher it draws white rather than black; what matters is that none of the data is in it |

The protection is a lease that value areas take, not a flag over the app, and the areas are more than an earlier
note here listed: the result view and the row detail sheet as well as the script result, the audit event and audit
log pages, the key-value page, the object source view and the browse database words. That is why the login page is
capturable and a result is not.

### Setting a device credential signs the session out

Worth knowing before it is reported as a bug. Giving the emulator its first PIN, so the app lock could be turned on
at all, dropped the session: the app came back to the login page. The tokens are kept in the Android keystore, and
Android invalidates keystore entries when the lock screen credential changes, so the store comes back empty and
`SessionCubit` reads it as unauthenticated. That is the keystore protecting the token rather than the app losing it,
and the same thing happens to anyone who sets, changes or removes a screen lock.

### Driving the statement field from `adb`

The Railway run above could not clear the editor and blamed itself without saying why. The reason is worth writing
down, because it will cost the next person the same hour: `KEYCODE_MOVE_END` moves to the end of the **visual
line**, not of the text, so in a field whose text wraps, a run of `KEYCODE_DEL` deletes to the start of that line
and then stops — the field looks stuck. `KEYCODE_FORWARD_DEL` is what clears the rest. Read the field back from
`uiautomator dump` between batches rather than counting characters, and read it with a pattern that cannot miss
("the text of the `EditText` node"), not one built from words you expect to still be there.

### A read grant executed writes and DDL

Driving `POST /api/db/query` with `mobile-test`'s token, on a connection whose Platform record says
`hasWriteCredential: false` and whose grant is `read`, every one of `insert`, `update`, `delete`, `create table` and
`drop table` answered 200, and the table the `create` named really appeared in the database. Platform's audit
recorded the first of them as `statementType: DDL`, `accessLevel: read`, `status: success` — so the access level was
known and the statement ran anyway. The table was dropped again and the sample is back to its 15.

This is Studio's behaviour, not the app's: the app showed the connection as "Read only", which is what Studio's own
`access: read` told it. It is written down here because the walkthrough is what found it.

## The mock walkthrough

Run once, on 2026-10-28, as a debug APK of `main_mock.dart` on the same emulator. It is written down because it is
the only run of it there will be: mock answers from `assets/mock/*.json` and reaches no server, so what passes here
is evidence about the app's own screens and about the fixtures, and evidence about nothing else. Every later
walkthrough goes against the lab.

What it showed that the lab cannot, because the lab has one connection, one engine and a `User`:

| What | Result |
| --- | --- |
| Sign-in | The mock provider signs in without a form — `MockSignInDependencies`, which only this entry point carries. The profile sheet reads `admin@example.com`, the role **Administrator**, the chip "Governed by LibreDB Platform" |
| The connection list | Five connections over four groups and four environments, in SQL Server, MongoDB, MySQL and Oracle, each with its engine's icon. A governance banner above them: "Statements you run are recorded in full in this server's query log." The PROD row carries a red badge, a red stripe down its left edge and the "Read only" lock, and keeps all three into the app bar of the screen it opens |
| Browse | The fixtures are deliberately awkward and the screen takes them: `Views 1,000+` for a count the server capped, and under **Functions**, in place of a number, `permission denied for schema sales`. A MySQL connection lists no materialized views and no sequences, because the engine has none |
| The editor | `select * from invoices limit 5` answered **2 rows, 14 ms** beside a `limited` chip, and the rows render `NULL` in italic rather than as the word |
| Platform mode | "Switch to Platform" asks first, and says why: "The first time this account opens Platform, it takes one admin seat of the license." Confirming lands on Platform's Home — the organization card (`Example Org`, `example-org`, signed in as **Platform Admin**), a Connections card, and a bottom bar of Home, Connections and Audit |

### One thing measured and left unexplained

After the app was sent to the home screen and resumed with `am start`, every pixel of its window — the app bar
included — came back at `#ECECEC` instead of the page's `#FFFFFF`, while the system bars stayed black. That is the
app's own window dimmed by about 7.5%, not a display filter, and `#ECECEC` is in no palette this app ships: every
neutral of all six carries a blue cast and this one is exactly grey. A force-stop and a cold start came back at
`#FFFFFF`. The likely cause is a bottom sheet's barrier left behind when `KEYCODE_BACK` popped the app rather than
the sheet, which is not a sequence a person performs; it is written down because it was measured, and not filed,
because it was not reproduced.

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
| `https://localhost:9446` | `libredb-studio-platform`, a Studio 1.1.0 in governance mode whose governance source is this Platform's `bridge` schema, so the statements it runs are the events of Platform's audit log; its API is `https://localhost:9446/api` |
| `platform-studio-db` | PostgreSQL 17 holding that Studio's storage, database and schema `studio` as role `studio`, never Platform's database or the role `libredb_studio` |

Platform runs the 1.3.0 release image, `ghcr.io/libredb/libredb-platform:1.3.0`, pinned by its digest in the compose file; `PLATFORM_IMAGE` overrides it for both Platform services.
The image is published for `linux/amd64` only, so an arm64 host runs it under emulation.
`tool/studio-dev/platform/postgres/bootstrap.psql` and `init/01-bootstrap.sh` are byte-identical copies of `docker/postgres/` of libredb-platform `v1.3.0` (`0a84fa7`), unchanged since `v1.1.0`; copy them again from the tag of a new Platform release, never edit them.
`platform-db` has no named volume, so `down -v` starts it empty.
`libredb-studio-platform` signs in to `platform-db` as `libredb_studio`, the role `bootstrap.psql` creates for a Studio, with the instance id `libredb-studio-platform`, and opens the credentials Platform seals with the private key of `tool/studio-dev/governed/keyring.json`, whose public key is Platform's `BRIDGE_SEAL_PUBLIC_KEY`.
It is reached with bearer tokens only, so the realm's `libredb-studio` client has no callback for port 9446.

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
Without a license no account can take an admin seat, so an admin's first call of any `/api/v1` route answers 403 `LICENSE_INVALID`, and the web console refuses the sign-in too; only the refusals of [Platform answers](#platform-answers) can be recorded, and the localhost license below unlocks the [Success and write answers](#success-and-write-answers).

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

## Platform installer environment

The full-system check (#304 for Platform, #196 for Studio) runs against a disposable install made by Platform's own installer, not against tool/studio-dev or Railway platform-dev.
It runs installer 1.3.0 (Platform 1.3.0, Studio 1.1.0, Keycloak, PostgreSQL and the Caddy edge, with `mobile.enabled: true`) in the LXD VM `libredb-installer-lab` on the Linux host, so nothing of it touches the host's own Docker.
A release build on the test phone trusts only the system store, so the edge serves a publicly trusted certificate with `tls.mode: provided` on three host names in a zone the owner controls.
Platform's `docs/deploy/install-docker.md` and `installer/README.md` are the contract; this section is the command list for this host, and no shell script wraps it.

`<platform host>`, `<studio host>` and `<auth host>` stand for the owner's three host names, `<host LAN address>` for the address of the Linux host on the phone's network, and `<phone serial>` for the test phone's adb serial.
The committed configuration `tool/installer-lab/libredb.yaml.example` holds the placeholders `libredb.example.invalid`, `studio.example.invalid` and `sso.example.invalid` in their place, and `test/architecture/installer_lab_config_test.dart` keeps it free of real hosts, license tokens and keys.
No command below prints a license token, a password, a key or a file of `/opt/libredb/secrets/`, and none runs `docker compose config` inside the VM, because it prints the merged environment.

### What the owner provides

- Three host names, with DNS A records that point to `<host LAN address>`; reserve that address in the router's DHCP, because the records break when the lease changes.
- A publicly trusted certificate for the three names, for example from a DNS-01 challenge: per host a chain (leaf first, then the intermediates) and an unencrypted key, and the issuing CA bundle, as files outside every repository.
  `tls.mode: provided` never renews a certificate (`installer/README.md:150`), so the check must finish before it expires.
- Outbound HTTPS from the VM (below).

The license is a FREE license (1 admin seat, 3 user seats, 12 months) for `<platform host>`, signed by the maintainers' license tool under the ruling of `.team/decisions.md` "2026-10-26: M12-P and M13-P owner answers", and kept at `~/libredb-licenses/free-installer-lab.license` with mode 600.
A free license names exactly one host, so it is signed only once the Platform host name is known.
Its one admin seat means one admin account at a time can use Platform mode.

### Outbound HTTPS from the VM

Docker on the host sets the iptables `FORWARD` policy to `DROP`, so a VM on `lxdbr0` resolves names through LXD's DNS but opens no outbound connection, and the LAN cannot reach it through the proxy device either.
The first check after the VM starts shows it:

```shell
lxc exec libredb-installer-lab -- curl -fsSI https://ghcr.io
```

When that times out, the owner allows forwarding for `lxdbr0` in Docker's `DOCKER-USER` chain for the length of the check, and removes the rules with `iptables -D` and the same arguments at teardown:

```shell
sudo iptables -I DOCKER-USER -i lxdbr0 -j ACCEPT
sudo iptables -I DOCKER-USER -o lxdbr0 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
sudo iptables -I DOCKER-USER -o lxdbr0 -d 10.207.27.50 -p tcp --dport 443 -j ACCEPT
```

The first two let the VM out and its replies back; the third lets the LAN reach the VM's port 443 through the proxy device, which forwards and does not deliver locally.
They are host steps that only the owner runs, they and the LXD proxy device are the only host changes, and they do not survive a reboot, so the owner adds them again after one.
At teardown the owner removes them:

```shell
sudo iptables -D DOCKER-USER -o lxdbr0 -d 10.207.27.50 -p tcp --dport 443 -j ACCEPT
sudo iptables -D DOCKER-USER -o lxdbr0 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
sudo iptables -D DOCKER-USER -i lxdbr0 -j ACCEPT
```

### Phone reachability

The phone's network resolves every name, even `studio.invalid`, to its router (`docs/platform.md`), and a router with DNS rebinding protection drops public answers that point to a private address.
After the DNS records exist and before the install, check each host from the host and from the phone, the phone under `.team/phone.lock` and named with `-s`:

```shell
getent hosts <platform host> <studio host> <auth host>
flock .team/phone.lock sh -c 'for h in <platform host> <studio host> <auth host>; do adb -s <phone serial> shell ping -c 1 "$h"; done'
```

Each line must name `<host LAN address>`, not the router; when the phone gets the router or no answer, the owner chooses another route, such as a public address or a tunnel, before anything is installed.

### Set up

Create the VM (Ubuntu 24.04, 4 vCPU, 8 GiB, 40 GiB root disk) with a static address on `lxdbr0`, which the proxy device in NAT mode needs:

```shell
lxc init ubuntu:24.04 libredb-installer-lab --vm -c limits.cpu=4 -c limits.memory=8GiB -d root,size=40GiB
lxc config device override libredb-installer-lab eth0 ipv4.address=10.207.27.50
lxc start libredb-installer-lab
lxc exec libredb-installer-lab -- cloud-init status --wait
lxc exec libredb-installer-lab -- curl -fsSI https://ghcr.io
```

`10.207.27.50` lies in this host's `lxdbr0` range `10.207.27.0/24`; on another host pick a free address of `lxc network get lxdbr0 ipv4.address`.

Install Docker Engine and the Compose plugin from Docker's apt repository; `preflight` refuses an engine from 28.2.0 through 28.3.2, and the repository's current release is newer:

```shell
lxc exec libredb-installer-lab -- sh -euc '
apt-get update && apt-get install -y ca-certificates curl jq
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu noble stable" > /etc/apt/sources.list.d/docker.list
apt-get update && apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
docker version --format "{{.Server.Version}}"; docker compose version --short; command -v ss systemctl'
```

The VM has no stored Docker Hub credentials, so it pulls the images anonymously, unlike the host (see [Docker Hub on this machine](#docker-hub-on-this-machine)).

Download installer 1.3.0 and check it as `docs/deploy/install-docker.md` "Download and verify the installer" says:

```shell
lxc exec libredb-installer-lab -- sh -euc '
V=1.3.0; B=https://github.com/libredb/libredb-platform/releases/download/installer-v$V
mkdir -p /root/libredb-$V && cd /root/libredb-$V
curl -fL -O "$B/libredb-installer-linux-x64" -O "$B/SHA256SUMS"
sha256sum -c --ignore-missing SHA256SUMS
chmod 0755 libredb-installer-linux-x64 && ./libredb-installer-linux-x64 version'
```

`sha256sum` must print `libredb-installer-linux-x64: OK` and `version` `release 1.3.0`.
For the attestation, download the same file on the host, compare its `sha256sum` with the VM's, and run `gh attestation verify libredb-installer-linux-x64 --repo libredb/libredb-platform` there.

Copy the license, the chains, the keys and the CA bundle into the VM from their paths outside every repository, the license and the keys with mode 0600; `<certificate dir>` stands for the directory that holds the owner's files, named as `tool/installer-lab/libredb.yaml.example` names them:

```shell
lxc exec libredb-installer-lab -- install -d -m 0700 -o root -g root /etc/libredb /etc/libredb/tls
lxc file push --uid 0 --gid 0 --mode 0600 ~/libredb-licenses/free-installer-lab.license libredb-installer-lab/etc/libredb/platform.license
for e in platform studio auth; do
  lxc file push --uid 0 --gid 0 --mode 0644 "<certificate dir>/$e.chain.pem" "libredb-installer-lab/etc/libredb/tls/$e.chain.pem"
  lxc file push --uid 0 --gid 0 --mode 0600 "<certificate dir>/$e.key.pem" "libredb-installer-lab/etc/libredb/tls/$e.key.pem"
done
lxc file push --uid 0 --gid 0 --mode 0644 "<certificate dir>/ca-bundle.pem" libredb-installer-lab/etc/libredb/tls/ca-bundle.pem
```

One certificate whose SAN covers the three names serves all three endpoints: push its `fullchain.pem` as each `$e.chain.pem` and its `privkey.pem` as each `$e.key.pem`.
`tls.caBundleFile` must hold the self-signed root that the chain ends at, because the installer, like OpenSSL, does not take an intermediate as a trust anchor.
Certbot's `chain.pem` holds only intermediates, so it is not the bundle; for a Let's Encrypt chain that ends at the cross-signed ISRG Root X2, the bundle is ISRG Root X1 from the host's store, `/etc/ssl/certs/ISRG_Root_X1.pem`.

Fill in the configuration with the three host names and check it before `preflight`:

```shell
sed -e 's/libredb\.example\.invalid/<platform host>/' -e 's/studio\.example\.invalid/<studio host>/' \
  -e 's/sso\.example\.invalid/<auth host>/' tool/installer-lab/libredb.yaml.example > /tmp/libredb.yaml
lxc file push --uid 0 --gid 0 --mode 0600 /tmp/libredb.yaml libredb-installer-lab/etc/libredb/libredb.yaml && rm /tmp/libredb.yaml
lxc exec libredb-installer-lab -- sh -euc 'cd /root/libredb-1.3.0 && ./libredb-installer-linux-x64 validate -c /etc/libredb/libredb.yaml'
```

`validate` prints the normalized configuration, which holds the license's path and never its token.

Install, then check the result; `apply` copies the installer to `/opt/libredb/bin/libredb-installer`, which the later commands run:

```shell
lxc exec libredb-installer-lab -- sh -euc 'cd /root/libredb-1.3.0 && ./libredb-installer-linux-x64 preflight -c /etc/libredb/libredb.yaml'
lxc exec libredb-installer-lab -- sh -euc 'cd /root/libredb-1.3.0 && ./libredb-installer-linux-x64 apply -c /etc/libredb/libredb.yaml --yes'
lxc exec libredb-installer-lab -- sh -euc 's=0; /opt/libredb/bin/libredb-installer verify -c /etc/libredb/libredb.yaml --output json > /root/verify.json || s=$?; jq -r ".checks[] | \"\(.id) \(.result)\"" /root/verify.json; exit $s'
lxc exec libredb-installer-lab -- /opt/libredb/bin/libredb-installer status
lxc exec libredb-installer-lab -- /opt/libredb/bin/libredb-installer images list -c /etc/libredb/libredb.yaml
```

`verify` exits 4 when a check fails; the `|| s=$?` keeps `sh -e` from stopping there, so the `jq` summary still prints and the command still exits 4.
The `jq` filter prints only each check's id and result, since a `detail` names the license's host.
`status` must show every container healthy.

Expose the VM's port 443 on the host's LAN address with an LXD proxy device in NAT mode, which a VM needs, with the static NIC address and a concrete listen address:

```shell
lxc config device add libredb-installer-lab https proxy listen=tcp:<host LAN address>:443 connect=tcp:10.207.27.50:443 nat=true
```

The first admin `libredb-admin`, whose temporary password is in `/opt/libredb/secrets/first-admin.txt` inside the VM, and the user manager `libredb-user-manager` are the owner's: the owner signs in, sets a new password and TOTP, and creates the test user with the client role `libredb:user` in the realm console that `keycloak console` opens through an SSH tunnel to `127.0.0.1:18080` of the VM.
No agent reads that file.
The owner ruled this lab a demo environment (`.team/decisions.md` "2026-10-26: installer lab is a demo environment (user ruling)", with its 06:04Z amendment), so agents do these first-run steps there through the realm's admin API inside the VM, set no TOTP, and keep the new passwords in mode-600 files under `~/libredb-installer-lab/` on the host.

### Sample data

A PostgreSQL in the VM, outside the Compose project `libredb`, holds the seed of [Postgres seeds](#postgres-seeds), and joins the network `libredb_edge` so that Studio reaches it by name.
Its role passwords are random and stay in a 0600 file inside the VM:

```shell
lxc exec libredb-installer-lab -- install -d -m 0700 /root/lab-sample
lxc file push --mode 0644 tool/studio-dev/postgres/seed.sql libredb-installer-lab/root/lab-sample/10-seed.sql
lxc file push --mode 0755 tool/studio-dev/postgres/role-passwords.sh libredb-installer-lab/root/lab-sample/20-role-passwords.sh
lxc exec libredb-installer-lab -- sh -euc '
cd /root/lab-sample
umask 077
printf "POSTGRES_PASSWORD=%s\nAPP_OWNER_PASSWORD=%s\nSTUDIO_READER_PASSWORD=%s\n" \
  "$(openssl rand -hex 16)" "$(openssl rand -hex 16)" "$(openssl rand -hex 16)" > sample.env
docker run -d --name lab-sample-postgres --restart unless-stopped --network libredb_edge --env-file sample.env \
  -v /root/lab-sample/10-seed.sql:/docker-entrypoint-initdb.d/10-seed.sql:ro \
  -v /root/lab-sample/20-role-passwords.sh:/docker-entrypoint-initdb.d/20-role-passwords.sh:ro \
  postgres:17.6-alpine
until docker exec lab-sample-postgres pg_isready -h 127.0.0.1 -U postgres -d app; do sleep 2; done'
```

The connection is created in Platform's web console at `https://<platform host>`, never in the app: host `lab-sample-postgres`, port 5432, database `app`, user `app_owner`, and the `APP_OWNER_PASSWORD` of `/root/lab-sample/sample.env`.
Platform opens the connection with the read credential and asks to confirm that it can only read, so the read credential is the seed's read-only role `studio_reader`, and `app_owner` is the write credential.

### Acceptance checks

From the host, without `-k`, so the public chain validates against the system store:

```shell
curl -fsS https://<platform host>/api/health/live
curl -fsS https://<studio host>/api/ready
```

Both answer 200, the second with `"status":"ok"`.

The authorization endpoint serves the login page for the app's client with an S256 challenge, and refuses the same request without one; Keycloak sends that refusal to the redirect URI as a 302 whose `Location` carries `error=invalid_request`:

```shell
A='https://<auth host>/realms/libredb/protocol/openid-connect/auth?client_id=libredb-mobile&redirect_uri=org.libredb.mobile%3A%2Foauth2redirect&response_type=code&scope=openid'
C=$(head -c 32 /dev/urandom | basenc --base64url | tr -d '=')
curl -sS -o /dev/null -w '%{http_code}\n' "$A&code_challenge=$C&code_challenge_method=S256"
curl -sS -o /dev/null -w '%{http_code} %{redirect_url}\n' "$A"
```

The owner confirms in the realm console that `libredb-mobile` is a public client with the two audience mappers `libredb-studio-api` and `libredb-platform-api` (`installer/README.md:222`).

### Tear down

```shell
lxc delete --force libredb-installer-lab
lxc list
ss -Htln 'sport = :443'
```

Deleting the VM removes its proxy device too; `lxc list` must be empty and nothing may listen on port 443.
The owner then removes the `DOCKER-USER` rules of [Outbound HTTPS from the VM](#outbound-https-from-the-vm) with `iptables -D`.

### Recorded install

The install ran on 2026-10-26 with the commands above, on the owner's three host names and a Let's Encrypt certificate for them that expires on 2027-01-24.

| Item | Value |
| --- | --- |
| VM | `libredb-installer-lab`, Ubuntu 24.04 (image serial 20261017), 4 vCPU, 8 GiB, 40 GiB, `10.207.27.50` on `lxdbr0` |
| Docker in the VM | Engine 29.9.2, Compose 5.6.1, containerd.io 2.4.2 |
| Installer | 1.3.0, `release 1.3.0`, `libredb-installer-linux-x64` SHA-256 `b2dac4470173e87a4b38e75f996578e29599e3bb94b51c5fdcd70312664566b6`, `SHA256SUMS` OK, attestation verified on the host (signer `installer-release.yml` at `refs/tags/installer-v1.3.0`) |
| License | FREE, 1 admin seat, 3 user seats, `<platform host>`, until 2027-10-26; `apply` reports it active |
| `validate`, `preflight` | Pass, exit 0 |
| `apply --yes` | Exit 0, 84 changes |
| Platform | `ghcr.io/libredb/libredb-platform@sha256:e53ca9b82e337bb995a575ac4082de3da092d33c098a020a13292584fbc49ea9` |
| Studio | `ghcr.io/libredb/libredb-studio@sha256:e91183def05f4c13703c77363ec51ad68bfa45b1b1d3b92dc53c331b67e53d2c` |
| Keycloak | `quay.io/keycloak/keycloak@sha256:79c623a22abacf3fe6c00a5fb30f5b7843d717b234033b80995891c06116d244` |
| PostgreSQL | `docker.io/library/postgres@sha256:74935e72241653ca55e0414067e6d8763aceb8a810eb51b452253ec3dcfc4336` |
| Edge | `docker.io/library/caddy@sha256:685ae3d7c34d9b5f8caeddc5d14051db7bbd88ff1f5a2fa0c16bd8ca328fb7af` |
| Sample PostgreSQL | `postgres:17.6-alpine`, `postgres@sha256:ef257d85f76e48da1c64832459b59fcaba1a4dac97bf5d7450c77753542eee94`; `app` holds 7 tables and `archive` 1; Studio resolves `lab-sample-postgres` on `libredb_edge` |
| `status` | `edge`, `keycloak`, `platform`, `postgres` and `studio` running and healthy; the three provided certificates have 89 days left |
| Outbound HTTPS from the VM | Works with the owner's first two `DOCKER-USER` rules: `https://ghcr.io/v2/` answers 401, the anonymous answer |

The digests are what `images list` printed, and match `installer/release/release.config.json` of libredb-platform `16e6af1`.

`verify --output json` exited 0 with these results:

| Check | Result |
| --- | --- |
| `postgres-privileges` | passed |
| `components-healthy` | passed |
| `clock-skew` | passed |
| `no-proxy` | passed |
| `edge-tls` | passed |
| `platform-ready` | passed |
| `platform-signin-redirect` | passed |
| `platform-admin-api` | passed |
| `bridge-contract` | passed |
| `seal-canary-published` | passed |
| `bridge-privileges` | passed |
| `platform-license` | passed |
| `studio-ready` | passed |
| `studio-heartbeat` | passed |
| `studio-canary` | passed |
| `bridge-notify-roundtrip` | passed |
| `studio-oidc-chain` | passed |
| `oidc-discovery-in-network` | passed |
| `admin-mfa` | warning: `libredb-admin` and `libredb-user-manager` have no OTP credential; accepted, because a demo environment requires no TOTP (`.team/decisions.md` "2026-10-26: installer lab is a demo environment (user ruling)", 06:04Z amendment) |

From the host, without `-k`, on 2026-10-26:

- `https://<platform host>/api/health/live` answers 200 `{"status":"live"}`, and `https://<platform host>` answers 307 to `/login`.
- `https://<studio host>/api/ready` answers 200 with `"status":"ok"`, and `https://<studio host>` answers 307 to `/login`.
- The discovery document of `https://<auth host>/realms/libredb` names that issuer, and `openssl s_client` reports `Verify return code: 0 (ok)` for the Let's Encrypt chain.
- The authorization endpoint for `libredb-mobile` answers 200 with the login form for an S256 challenge, 302 with `error=invalid_request` (`Missing parameter: code_challenge_method`) without a challenge, and 302 with `error=invalid_request` for `code_challenge_method=plain`.

From the test phone, on its own network:

- `ping` of each of the three hosts resolves to `<host LAN address>` and answers, so the router does not block the private answers.
- Port 443 through the proxy device timed out until the owner added the third `DOCKER-USER` rule of [Outbound HTTPS from the VM](#outbound-https-from-the-vm); the first two rules let the VM out but drop the forwarded traffic from the LAN.
- With the third rule, the phone's `curl` gets 200 with `ssl_verify_result` 0 from `https://<platform host>/api/health/live`, `https://<studio host>/api/ready` and the issuer's discovery document, and Chrome on the phone opens the Platform sign-in page and the Keycloak login page with no certificate warning.

First-run steps, done by an agent under the demo environment ruling on 2026-10-26:

- `libredb-admin` (`libredb:admin`) and `libredb-user-manager` (the `realm-management` roles of the table in `installer/README.md`) have new passwords, set as not temporary, and no TOTP; their required actions `UPDATE_PASSWORD` and `CONFIGURE_TOTP` are removed, and their email and names are set, which Keycloak 26 asks for at the first login.
- `lab-user` exists with the client role `libredb:user` and no grant.
- `libredb-mobile` is public, has the standard flow only, PKCE S256, no direct access grants and no implicit flow, the redirect URI `org.libredb.mobile:/oauth2redirect`, and the two `oidc-audience-mapper` mappers `libredb-studio-api` and `libredb-platform-api` on the access token only.
- `libredb-admin` signs in to Platform with no TOTP prompt and created the connection "Lab sample PostgreSQL" in the web console: engine PostgreSQL, environment development, `lab-sample-postgres:5432/app`, SSL mode `disable`, read credential `studio_reader`, write credential `app_owner`; Platform lists it as Active with read and write credentials.
- `lab-user`'s Platform sign-in returns to `/login`, which is expected for an account without `libredb:admin`; it was not checked further.
- `verify` run again afterwards exits 0, with 18 checks passed and the accepted `admin-mfa` warning.

The teardown check of [Tear down](#tear-down) runs at the end of the last of #304 and #196, which use this lab, and is recorded there.

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

### Success and write answers

The success and write answers need the localhost license of [The license](#the-license) in `tool/studio-dev/platform-license.local`; Platform then logs "License active" when `serve` starts.
They were recorded on 2026-10-25 from Platform 1.3.0, the image the compose file pins, from a fresh volume, with a free localhost dev license of one admin seat and three user seats.
`me.json` comes first, so `admin` takes the only admin seat, and `admin2` is refused it afterwards.

The app never creates a connection, so the two connections the grant answers need were created by hand in Platform's web console:

1. Open `https://localhost:9445/login` in a browser, press its sign-in button and sign in to Keycloak as `admin` / `admin`.
2. Open `https://localhost:9445/connections/new`, the form that adds a connection, and fill it in: Name `Dev app (write)`, Environment `development`, Engine PostgreSQL, Host `postgres`, Port `5432`, Database `app`.
3. Under the read credential, enter User `studio_reader` with the password of `x-studio-reader-password` in the compose file, and tick the box that confirms the read credential can only read.
4. Set Write credential to "Add a write credential", enter User `app_owner` with the password of `x-app-owner-password` in the compose file, and create the connection.
5. Create a second connection the same way, named `Dev app (read-only)`, with Write credential left at "No write credential".

Platform reaches `postgres` through the stack's network, and the passwords are the dev ones the compose file holds; no other credential is used.
Platform lists the newest connection first, so `connections.json` lists `Dev app (read-only)` before `Dev app (write)`.

With `W` and `R` the ids of the write and the read-only connection from `connections.json`, `U` the id of `user` (`a0000000-0000-4000-8000-000000000002`) and `record_platform` of [Platform answers](#platform-answers), each line with a fresh `admin` token unless it names another user:

```shell
J=(-X PUT -H 'Content-Type: application/json')
token=$(tool/studio-dev/access-token.sh admin) && record_platform me /me  # 200
token=$(tool/studio-dev/access-token.sh admin2) && record_platform me_admin_seats /me  # 403 LICENSE_ADMIN_SEATS
token=$(tool/studio-dev/access-token.sh admin) && record_platform connections /connections  # 200, both
token=$(tool/studio-dev/access-token.sh admin) && record_platform directory /directory/users  # 200, disabled with enabled false
token=$(tool/studio-dev/access-token.sh admin) && record_platform directory_query '/directory/users?q=adm'  # 200, admin and admin2
token=$(tool/studio-dev/access-token.sh admin) && record_platform directory_bad_page '/directory/users?page=0'  # 400 VALIDATION_FAILED, page
token=$(tool/studio-dev/access-token.sh admin) && record_platform grant_put "/connections/$W/grants/$U" "${J[@]}" --data '{"level":"read","expiresAt":null}'  # 200 {id}
token=$(tool/studio-dev/access-token.sh admin) && record_platform grants "/connections/$W/grants"  # 200, that grant
token=$(tool/studio-dev/access-token.sh admin) && record_platform grants_unknown_connection /connections/unknown/grants  # 404 NOT_FOUND
token=$(tool/studio-dev/access-token.sh admin) && record_platform grant_put_level "/connections/$R/grants/$U" "${J[@]}" --data '{"level":"write","expiresAt":null}'  # 400, level
token=$(tool/studio-dev/access-token.sh admin) && record_platform grant_put_subject_unknown "/connections/$W/grants/a0000000-0000-4000-8000-000000000099" "${J[@]}" \
  --data '{"level":"read","expiresAt":null}'  # 400, subject
token=$(tool/studio-dev/access-token.sh admin) && record_platform grant_put_subject_disabled "/connections/$W/grants/a0000000-0000-4000-8000-000000000005" "${J[@]}" \
  --data '{"level":"read","expiresAt":null}'  # 400, subject
token=$(tool/studio-dev/access-token.sh admin) && record_platform grant_put_expiry "/connections/$W/grants/$U" "${J[@]}" \
  --data '{"level":"read","expiresAt":"2020-01-01T00:00:00.000Z"}'  # 400, expiresAt
token=$(tool/studio-dev/access-token.sh admin) && record_platform grant_put_body "/connections/$W/grants/$U" "${J[@]}" --data '{"level":"read","expiresAt":null,"note":"x"}'  # 400, ""
token=$(tool/studio-dev/access-token.sh admin) && record_platform grant_delete_unknown "/connections/$W/grants/unknown" -X DELETE  # 404 NOT_FOUND
```

`grant_put_body.json` carries the field key `""`, because the strict schema refuses an extra key at the root, and `grant_put_subject_disabled.json` names the username in its message, which the app never shows or logs.
For `grant_put_user_seats.json`, `admin` (`...0001`) and `admin2` (`...0004`) were each granted `read` on `W` with the same `PUT`, which with `user`'s grant takes all three user seats (an admin with a grant takes a user seat too); the `PUT` for `norole` (`...0003`) then answers 403 `LICENSE_USER_SEATS`:

```shell
token=$(tool/studio-dev/access-token.sh admin) && record_platform grant_put_user_seats "/connections/$W/grants/a0000000-0000-4000-8000-000000000003" "${J[@]}" \
  --data '{"level":"read","expiresAt":null}'  # 403 LICENSE_USER_SEATS
```

The answers of `PATCH /api/v1/connections/{id}` (libredb-platform#51), which the 1.3.0 image already serves, are recorded for M11-P on the read-only connection, so the no-op leaves it active:

```shell
P=(-X PATCH -H 'Content-Type: application/json')
token=$(tool/studio-dev/access-token.sh admin) && record_platform connection_patch "/connections/$R" "${P[@]}" --data '{"active":true}'  # 200, the connection
token=$(tool/studio-dev/access-token.sh admin) && record_platform connection_patch_body "/connections/$R" "${P[@]}" --data '{"active":true,"name":"x"}'  # 400, ""
token=$(tool/studio-dev/access-token.sh admin) && record_platform connection_patch_unknown /connections/unknown "${P[@]}" --data '{"active":true}'  # 404 NOT_FOUND
```

`directory_unavailable.json` is the 503 `DIRECTORY_UNAVAILABLE` of a directory search while Keycloak is stopped, with an `admin` token fetched, and its signing keys cached by Platform, before the stop:

```shell
token=$(tool/studio-dev/access-token.sh admin) && curl -sk -o /dev/null -H "Authorization: Bearer $token" https://localhost:9445/api/v1/directory/users
docker compose -f tool/studio-dev/docker-compose.yml --profile platform stop keycloak
record_platform directory_unavailable '/directory/users?q=zz'                                             # 503 DIRECTORY_UNAVAILABLE
docker compose -f tool/studio-dev/docker-compose.yml --profile platform up -d --wait
```

Every grant made for the recording was revoked by its id, and each `DELETE /api/v1/connections/{id}/grants/{grant id}` answered 204 with no body, so it has no fixture.
At the end `GET /api/v1/connections/{id}/grants` answered `{"grants":[]}` for both connections.

`recorded_platform_answers_test.dart` reads these through the production repositories and `platformError` or `platformGrantWriteError`; `me_admin_seats.json` makes `platformAccountRefusal` return `platformLicenseAdminSeats`.
`directory.json` and `directory_query.json` go through `PlatformDirectoryRepository.search`, and `grant_put.json` through `PlatformGrantRepository.put`, which must send the body it was recorded with.
No fixture carries the license.

### Audit, liveness and enable or disable answers

These were recorded on 2026-10-25 from Platform 1.3.0 and the Studio 1.1.0 of `libredb-studio-platform`, the images the compose file pins, from a fresh volume, with the localhost license of [The license](#the-license).
`GET /api/v1/me` as `admin` came first, so `admin` took the admin seat.
Then the three connections were created in Platform's web console as in [Success and write answers](#success-and-write-answers): `Dev app (write)` and `Dev app (read-only)` as there, and a third, `Dev app (toggle)`, made like the read-only one, with a read credential only, and used only for enable and disable.
The console was driven by a Playwright script with the same labels as Platform's own `e2e/self-hosted/connections.spec.ts`; a browser by hand does the same.
`W`, `R` and `T` are the ids of the write, the read-only and the toggle connection; the fixtures carry these new ids, and no earlier fixture was recorded again.

`user` (`a0000000-0000-4000-8000-000000000002`) was granted `write` on `W` and `read` on `R` with the grant `PUT` of [Success and write answers](#success-and-write-answers).
Then `user` ran test statements through `libredb-studio-platform` with a fresh token each, as `POST https://localhost:9446/api/db/query` with `{"connectionId":"seed:<id>","sql":...,"options":{"offset":0}}`.
Statement capture, the Studio setting `queryLog.statementCapture`, was changed on Platform's page `https://localhost:9445/studio-settings` before each group, and its change reaches Studio within a second through `bridge.settings_v1`:

| Capture | Connection | Statement | Studio's answer | Event |
| --- | --- | --- | --- | --- |
| `full` | `W` | `CREATE TABLE mobile_audit_fixture (id int)` | 200 | `success`, `DDL` |
| `full` | `W` | `INSERT INTO mobile_audit_fixture VALUES (1)` | 200 | `success`, `INSERT` |
| `full` | `W` | `SELECT 1 AS mobile_audit_fixture` | 200 | `success`, `SELECT` |
| `redacted` | `W` | `SELECT 1/0 AS mobile_audit_fixture_error` | 400 `QUERY_ERROR` | `error`, `22012` |
| `redacted` | `R` | `INSERT INTO mobile_audit_fixture VALUES (2)` | 403 `PERMISSION_DENIED` | `error`, `42501` |
| `redacted` | `T` | `SELECT 1 AS mobile_audit_fixture_refused` | 404 `CONNECTION_NOT_FOUND` | `refused`, no statement |
| `none` | `W` | `SELECT pg_sleep(30)` with a `queryId`, cancelled after 3 seconds with `POST /api/db/cancel` | 499 `QUERY_CANCELLED` | `cancelled`, `57014` |
| `none` | `W` | `SELECT 2 AS mobile_audit_fixture_none` | 200 | `success`, no statement |

Capture was set back to `redacted`, Platform's seeded default, right after.
Studio does not refuse the `INSERT` on `R` before it runs: it runs it with the read credential and PostgreSQL refuses it, so its event has status `error`.
A `refused` event comes from a request that Studio refuses before anything runs (Studio `docs/GOVERNANCE.md`, query events), here a statement on `T`, on which `user` holds no grant.
Under `redacted` capture Studio replaces literals with `?` and records no error text, and under `none` it records neither, so every `errorMessage` of these answers is null.

With `record_platform` of [Platform answers](#platform-answers), each line with a fresh `admin` token:

```shell
token=$(tool/studio-dev/access-token.sh admin) && record_platform audit /audit  # 200, the 8 events, newest first
token=$(tool/studio-dev/access-token.sh admin) && record_platform audit_page '/audit?limit=2&offset=2'  # 200, 2 events, total 8
token=$(tool/studio-dev/access-token.sh admin) && record_platform audit_filtered \
  "/audit?status=error&statementType=SELECT&connectionId=$W&from=2026-10-25T13:28:00.000Z&to=2026-10-25T13:30:00.000Z"  # 200, the 1/0 event
token=$(tool/studio-dev/access-token.sh admin) && record_platform audit_search '/audit?search=mobile_audit_fixture'  # 200, 5 events
token=$(tool/studio-dev/access-token.sh admin) && record_platform audit_bad_filters '/audit?limit=201&status=nope&from=yesterday'  # 400, from, limit, status
plan() { # plan <FREE|ENTERPRISE>: the plan of the install tenant
  docker compose -f tool/studio-dev/docker-compose.yml --profile platform exec platform-db psql -U postgres -d libredb -c \
    "UPDATE platform.tenants SET \"planConfigId\" = (SELECT id FROM platform.plan_configs WHERE code = '$1') WHERE slug = 'default'"
}
plan FREE
token=$(tool/studio-dev/access-token.sh admin) && record_platform audit_plan_feature_required /audit  # 403 PLAN_FEATURE_REQUIRED
plan ENTERPRISE
curl -sk -o test/fixtures/platform/health_live.json -w "health_live %{http_code}\n" https://localhost:9445/api/health/live  # 200, no token
P=(-X PATCH -H 'Content-Type: application/json')
token=$(tool/studio-dev/access-token.sh admin) && record_platform connection_patch_disable "/connections/$T" "${P[@]}" --data '{"active":false}'  # 200, inactive
token=$(tool/studio-dev/access-token.sh admin) && record_platform connection_patch_enable "/connections/$T" "${P[@]}" --data '{"active":true}'  # 200, active
```

Right after `plan ENTERPRISE`, `GET /api/v1/audit` answered 200 again.
`health_live.json` is fetched with curl directly, because `record_platform` prefixes `/api/v1` and the liveness probe needs no token.
For `connection_patch_user_seats.json`, `admin` (`...0001`) was granted `read` on `W`, which with `user`'s grants takes two user seats; `T` was disabled, and `admin2` (`...0004`) and `norole` (`...0003`) were granted `read` on it, which takes no seat while `T` is paused; enabling `T` would need four seats of the license's three:

```shell
token=$(tool/studio-dev/access-token.sh admin) && record_platform connection_patch_user_seats "/connections/$T" "${P[@]}" --data '{"active":true}'  # 403 LICENSE_USER_SEATS
```

`PERMISSION_DENIED` of `GET /api/v1/audit` has no fixture: a bearer caller is always a Platform admin, whom the audit read lets through (libredb-platform `docs/api/v1.md`, `src/features/audit/lib/audit-read.ts`), so it cannot be recorded through the bearer API, and the mock-based tests of the audit repository cover it.

At the end `admin2`'s and `norole`'s grants on `T` were revoked before `T` was enabled again, every other grant made here was revoked by its id (each `DELETE` answered 204), and `GET /api/v1/connections/{id}/grants` answered `{"grants":[]}` for all three connections.
`T` was left active, `mobile_audit_fixture` was dropped from the database `app`, the plan was `ENTERPRISE` and statement capture `redacted`.

`recorded_platform_answers_test.dart` reads the audit answers through `PlatformAuditRepository.list` and `platformError`, the enable and disable answers through `PlatformConnectionRepository.setActive`, which must send the body it was recorded with, and `health_live.json` through `PlatformStatusRepository.liveness`.
The audit events carry `user@example.com`, the realm's test address, as `username`, and only test statements.
