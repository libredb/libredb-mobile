# Running the app against LibreDB Studio

The app talks to [LibreDB Studio](https://github.com/libredb/libredb-studio) as its backend.
It signs in to Keycloak itself, as the public client `libredb-mobile` with the authorization code flow and PKCE, and sends Keycloak's access token to Studio as `Authorization: Bearer`.
Studio accepts that token through its bearer channel for native clients, which `OIDC_BEARER_AUDIENCE` turns on (Studio's `docs/OIDC.md`, "Bearer access tokens for native clients").
The sign-in itself is the app's `oidc` mode, described in [oidc.md](oidc.md).

The bearer channel came with libredb/libredb-studio#1914, which is on Studio's main branch; Studio 1.0.0 does not have it.
Until a Studio release contains it, build the Studio image from main, as shown below.

## What Studio and Keycloak need

In Keycloak, next to Studio's own confidential client:

- A public client `libredb-mobile`: client authentication off, standard flow only, direct access grants off, PKCE method `S256`.
- Redirect URI and post-logout redirect URI `org.libredb.mobile:/oauth2redirect`.
- An Audience mapper on that client that puts Studio's API audience, for example `libredb-studio-api`, into the access token only.
  It must differ from Studio's own client id.
- The role claim in both tokens: the app reads it from the ID token and Studio from the access token.

In Studio:

```env
OIDC_BEARER_AUDIENCE=libredb-studio-api
OIDC_BEARER_CLIENT_IDS=libredb-mobile
```

Under LibreDB Platform the installer creates all of this when `mobile.enabled` is set in `libredb.yaml`.

The app is built with:

```env
AUTH_PROVIDER=oidc
OIDC_ISSUER=https://keycloak.example.com/realms/libredb
OIDC_CLIENT_ID=libredb-mobile
OIDC_ROLE_CLAIM=realm_access.roles
OIDC_ADMIN_ROLES=admin
OIDC_USER_ROLES=user
PROD_API_URL=https://studio.example.com/api
```

Studio's API lives under `/api`, so `PROD_API_URL` ends with it and the repositories use paths such as `/connections/managed`.
A prod build without `PROD_API_URL` stops at start with `ProdApiUrlConfigError`.
In a Platform install the role claim is `libredb_roles` instead of `realm_access.roles`.

## Try it locally

`tool/studio-dev/docker-compose.yml` starts Keycloak 26.8.1 and Studio behind Caddy, which serves both over TLS with its own local CA, because Studio refuses an issuer that is not https:

| Address | Service |
| --- | --- |
| `https://localhost:8443` | Keycloak, realm `libredb`; admin console at `/admin/` with `kcadmin` / `kcadmin` |
| `https://localhost:9443` | Studio; the app's API is `https://localhost:9443/api` |

The realm has the users `admin` / `admin` (realm role `admin`) and `user` / `user` (realm role `user`), and gives access tokens a 60 second life, so a walkthrough also exercises the refresh.
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
2. After the sign-in the app opens the dashboard; the sign-in sends nothing to Studio.
3. Connections in the menu lists what Studio offers the user: without a seed file, Studio's two sample connections.
   That request carries the access token, so the list proves the bearer channel.
4. A minute later the access token has expired: Studio answers the next request with 401, and the app refreshes at Keycloak and repeats it.
5. Logout ends the Keycloak session as well, and the app is back on the login page.

How far this was verified:

| Platform | Status |
| --- | --- |
| Android emulator, API 30 Google APIs image | Walked through as above with Studio built from libredb/libredb-studio#1914 at `d8d1b4970`: sign-in, the connection list, the refresh after expiry and the logout all worked |
| iOS simulator | Not run |

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

### Regenerating the seed

`tool/studio-dev/governed/generate.ts` writes `governance-source.sql`, `governed-db.sql` and `keyring.json` from a checkout of Studio, with Studio's own fixture builder and test sealer; never edit those files by hand:

```shell
bun tool/studio-dev/governed/generate.ts ../libredb-studio
```

Every key and password in them is derived from a fixed label and protects nothing, so a second run writes the same bytes.
Run it again when Studio publishes a new governance contract.

### Docker Hub on this machine

Where the stored Docker Hub credentials are rejected, pulls of `postgres` and `caddy` fail even though the images are public.
Point `DOCKER_CONFIG` at an empty directory for the command, so Docker pulls anonymously:

```shell
mkdir -p /tmp/empty-docker-config
DOCKER_CONFIG=/tmp/empty-docker-config docker compose -f tool/studio-dev/docker-compose.yml --profile governed up -d --wait
```

### Recorded answers

`test/fixtures/studio/managed_governed.json`, `policy_governed.json` and `governance_unavailable.json` were recorded as `user` with a `libredb-mobile` access token, and `admin_governance.json` as `admin`, from Studio main at `dbfea263`.
The seed in `tool/studio-dev/governed/` was generated from Studio `02dc26057`, which has the same governance contract as `dbfea263`.
`test/infrastructure/studio/recorded_studio_answers_test.dart` reads them.
The app was also walked through on the Android emulator (API 30 Google APIs image) against the governed Studio: the SSO sign-in as `user` and the connection list with both granted connections.
