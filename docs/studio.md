# Running the app against LibreDB Studio

The app talks to [LibreDB Studio](https://github.com/libredb/libredb-studio) as its backend.
It signs in to Keycloak itself, as the public client `libredb-mobile` with the authorization code flow and PKCE, and sends Keycloak's access token to Studio as `Authorization: Bearer`.
Studio accepts that token through its bearer channel for native clients, which `OIDC_BEARER_AUDIENCE` turns on (Studio's `docs/OIDC.md`, "Bearer access tokens for native clients").
The sign-in itself is the template's `oidc` mode, described in [oidc.md](oidc.md).

The bearer channel comes with libredb/libredb-studio#1914.
Until a Studio release contains it, build the Studio image from that branch, as shown below.

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
In a Platform install the role claim is `libredb_roles` instead of `realm_access.roles`.

## Try it locally

`tool/studio-dev/docker-compose.yml` starts Keycloak 26.8.1 and Studio behind Caddy, which serves both over TLS with its own local CA, because Studio refuses an issuer that is not https:

| Address | Service |
| --- | --- |
| `https://localhost:8443` | Keycloak, realm `libredb`; admin console at `/admin/` with `kcadmin` / `kcadmin` |
| `https://localhost:9443` | Studio; the app's API is `https://localhost:9443/api` |

The realm has the users `admin` / `admin` (realm role `admin`) and `user` / `user` (realm role `user`), and gives access tokens a 60 second life, so a walkthrough also exercises the refresh.
The stack is unfit for production on purpose: `start-dev` with the embedded H2 store, a self-signed CA, and committed passwords and client secret.

Build the Studio image from the bearer branch, until a release contains it:

```shell
git clone --branch feat/oidc-bearer-access-token https://github.com/libredb/libredb-studio.git
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
