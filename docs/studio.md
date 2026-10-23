# Running the app against LibreDB Studio

The app talks to [LibreDB Studio](https://github.com/libredb/libredb-studio) as its backend.
It signs in to Keycloak itself, as the public client `libredb-mobile` with the authorization code flow and PKCE, and sends Keycloak's access token to Studio as `Authorization: Bearer`.
Studio accepts that token through its bearer channel for native clients, which `OIDC_BEARER_AUDIENCE` turns on (Studio's `docs/OIDC.md`, "Bearer access tokens for native clients").
The sign-in itself, the app's only one, is described in [oidc.md](oidc.md).

The bearer channel came with libredb/libredb-studio#1914, which is on Studio's main branch; Studio 1.0.0 does not have it.
Until a Studio release contains it, build the Studio image from main, as shown below.

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
In a Platform install Studio's role claim is `libredb_roles` instead of `realm_access.roles`; the app's build does not change.

## Try it locally

`tool/studio-dev/docker-compose.yml` starts Keycloak 26.8.1 and Studio behind Caddy, which serves both over TLS with its own local CA, because Studio refuses an issuer that is not https:

| Address | Service |
| --- | --- |
| `https://localhost:8443` | Keycloak, realm `libredb`; admin console at `/admin/` with `kcadmin` / `kcadmin` |
| `https://localhost:9443` | Studio; the app's API is `https://localhost:9443/api` |

The realm has the users `admin` / `admin` (realm role `admin`) and `user` / `user` (realm role `user`), and gives access tokens a 60 second life, so a walkthrough also exercises the refresh.
`norole` / `norole` holds no realm role, so Studio refuses it: the sign-in stays on the login page with the refusal, and nothing is stored.
The stack is unfit for production on purpose: `start-dev` with the embedded H2 store, a self-signed CA, and committed passwords and client secret.

Build the Studio image from main, until a release contains the bearer channel:

```shell
git clone https://github.com/libredb/libredb-studio.git
docker build -t libredb-studio:bearer libredb-studio
```

Start the stack and build the app against it:

```shell
STUDIO_IMAGE=libredb-studio:bearer docker compose -f tool/studio-dev/docker-compose.yml up -d --wait
fvm flutter run --target lib/main/main_prod.dart --dart-define-from-file=tool/studio-dev/studio-dev.env
docker compose -f tool/studio-dev/docker-compose.yml down -v
```

The last command removes the stack with all its state, its CA included.

### Android emulator

The app's own requests trust only the system CA store, so the stack's CA has to go there.
`tool/studio-dev/trust-android-emulator.sh` does that and forwards ports 8443 and 9443 with `adb reverse`, so the emulator's `localhost` reaches the stack and the issuer stays `https://localhost:8443/...`:

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

- The read-only seed: Dev Postgres (read-only role) shows `public.orders` with its columns and indexes, no key mark on `id`, and "Studio lists no foreign keys." on the Foreign keys tab, because Studio hides the keys from a role that does not own the table (see [Postgres seeds](#postgres-seeds)).
  The read grant of Sales (production) shows `public.orders` without a key mark on `id` for the same reason.
- Exclusion constraints: the seed holds none, so the table `sales.room_bookings`, with `EXCLUDE USING gist (during WITH &&)`, was created in `app` as `app_owner` during the walkthrough; its Indexes tab lists `room_bookings_during_excl` and, under "Exclusion constraints", its definition.

The local Studio answers a key-scan page in a few milliseconds, so Load all ended before Stop could be tapped; for the Stop check the `redis` container was given a 1.5 second network delay (`tc qdisc add dev eth0 root netem delay 1500ms`, from a container sharing its network namespace with `NET_ADMIN`), removed again afterwards.
The view's row in the search reads "View · 0 B", the size Studio sends for a view.

Found during the walkthrough and logged for the backlog, none of which fails a step:

- At start the app asks `GET /api/app/config`, a route Studio does not have, without a token, and Studio answers 401.
- Under a pattern, the key browser's "Scanned n of the t keys this database holds" counts the matching keys, so a finished walk of `user:*` reads "Scanned 1203 of the 1207 keys this database holds".
- A Browse level that failed offline loads again only on Retry after airplane mode ends, while the connection list recovers by itself.
- The Postgres seed has no exclusion constraint, which is why the table above was added by hand.

The iOS simulator was not run, since this Linux host has none and CI builds Android only, so no step is verified on iOS, #57's share sheet included; #91 tracks the iOS walkthrough.

## Postgres seeds

The default stack also runs `postgres`, Postgres 17 loaded by `tool/studio-dev/postgres/seed.sql`, and Studio reads `tool/studio-dev/seed-connections.yaml` through `SEED_CONFIG_PATH` beside its built-in samples:

| Connection | Environment, group | What it opens |
| --- | --- | --- |
| `seed:dev-postgres`, "Dev Postgres" | `development`, `Dev databases` | The database `app`, so the tree starts at its schemas |
| `seed:dev-postgres-server`, "Dev Postgres server" | `staging`, `Dev databases` | The whole server, so the tree starts at its databases (`app`, `archive`, `postgres`) and a request names the database in `catalog` |
| `seed:dev-postgres-readonly`, "Dev Postgres (read-only role)" | `development`, `Dev databases` | The database `app` through a role that may only read |

`app` holds the schemas `public` and `sales`:

- `public.customers`, `public.orders` and `public.order_items`, with primary keys, the foreign keys `orders.customer_id` and `order_items.order_id`, and the index `orders_customer_id_idx`.
- Columns of `bytea`, `numeric`, `bigint` and `jsonb`, rows with many NULLs, and the `email` and `card_number` columns the masking work of M4 masks.
- `public.column_types`, one row of every column type a query result renders.
- The view `sales.order_totals`, the function `sales.order_total(bigint)`, the procedure `sales.mark_shipped(bigint)` and the trigger `orders_touch_updated_at` on `public.orders`.
- `sales.ledger`, exactly 100 rows, so pages of 50 rows end with a full page that has no more and an empty page past it.

`archive` holds one table, so the server-level seed lists more than one database.
The first two seeds sign in as `app_owner`, which owns every object, and the third as `studio_reader`, which may only read and owns nothing.
Studio reads a table's keys from `information_schema` views, which show foreign keys only to the owner, and primary keys only to the owner or a role with a non-SELECT privilege on the table, so its describe of `public.orders` names them through the first seed and not through the third.
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
STUDIO_IMAGE=libredb-studio:bearer docker compose -f tool/studio-dev/docker-compose.yml --profile governed up -d --wait
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

`test/fixtures/studio/managed_governed.json`, `policy_governed.json` and `governance_unavailable.json` were recorded as `user` with a `libredb-mobile` access token, and `admin_governance.json` as `admin`, from Studio main at `dbfea263`.
The seed in `tool/studio-dev/governed/` was generated from Studio `02dc26057`, which has the same governance contract as `dbfea263`.
`managed_governed.json` was recorded again as `user` from Studio main at `c9989a6b5` (`libredb-studio:main-c9989a6`, with the same seed), which adds each connection's grant level as `access` (libredb-studio#1922): `write` on `sales-dev` and `read` on `sales-prod`.
`ready_governed.json` is the governed Studio's `GET /api/ready`, and `ready_degraded.json` the same about 15 seconds after `governance-source` was stopped; both were recorded without a token, as were `health.json` and `ready.json` from the first Studio.
`test/infrastructure/studio/recorded_studio_answers_test.dart` reads them.
The app was also walked through on the Android emulator (API 30 Google APIs image) against the governed Studio: the SSO sign-in as `user` and the connection list with both granted connections.

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

The Postgres answers were recorded as `admin` from Studio main at `c9989a6b5` (`libredb-studio:main-c9989a6`):

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
```

The row previews and counts of #98 were recorded the same way, from a fresh volume, with the statements the app's generator writes:

```shell
record query_preview_postgres_customers /db/query '{"connectionId":"seed:dev-postgres","sql":"SELECT * FROM public.customers;","options":{"limit":50,"offset":0}}'
record query_count_postgres_customers /db/query '{"connectionId":"seed:dev-postgres","sql":"SELECT COUNT(*) AS row_count\nFROM public.customers;","options":{"offset":0}}'
record query_preview_postgres_server_orders /db/query '{"connectionId":"seed:dev-postgres-server","sql":"SELECT * FROM app.public.orders;","options":{"limit":50,"offset":0},"catalog":"app"}'
record query_preview_postgres_readonly_customers /db/query '{"connectionId":"seed:dev-postgres-readonly","sql":"SELECT * FROM public.customers;","options":{"limit":50,"offset":0}}'
record query_count_postgres_readonly_customers /db/query '{"connectionId":"seed:dev-postgres-readonly","sql":"SELECT COUNT(*) AS row_count\nFROM public.customers;","options":{"offset":0}}'
```

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

The transaction answers come from one database of the server-level seed, recorded last because the `UPDATE` changes a row:

```shell
record txbegin /db/transaction '{"connectionId":"seed:dev-postgres-server","action":"begin","catalog":"app"}'
record txquery /db/transaction '{"connectionId":"seed:dev-postgres-server","action":"query","sql":"UPDATE public.orders SET status = '"'"'paid'"'"' WHERE id = 2","options":{"limit":50,"offset":0},"catalog":"app"}'
record txcommit /db/transaction '{"connectionId":"seed:dev-postgres-server","action":"commit","catalog":"app"}'
```

The refusals of `GET /api/auth/me` come from the same Studio, which has libredb/libredb-studio#1922:

```shell
token=$(tool/studio-dev/access-token.sh norole) && record me_norole /auth/me     # 403 BEARER_NO_ROLE
token=$(tool/studio-dev/access-token.sh user) && sleep 100 && record me_expired /auth/me
docker compose -f tool/studio-dev/docker-compose.yml stop keycloak
docker compose -f tool/studio-dev/docker-compose.yml restart libredb-studio
record me_idp_unavailable /auth/me                                                # with a token fetched before the stop
```

`me_expired.json` is the 401 `AUTH_REQUIRED` of a token past its 60 seconds and Studio's 30 second clock tolerance, sent with `WWW-Authenticate: Bearer error="invalid_token"`.
`me_idp_unavailable.json` is the 503 `IDENTITY_PROVIDER_UNAVAILABLE` of a Studio restarted while Keycloak is stopped, so it has no signing keys cached to check the token with.

`test/infrastructure/studio/recorded_studio_answers_test.dart` reads every one of them.
