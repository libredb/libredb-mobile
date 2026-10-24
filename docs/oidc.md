# Single Sign-On with OpenID Connect

The app signs users in only through an OpenID Connect provider: Keycloak for LibreDB Studio, and in principle Zitadel, Auth0 or Microsoft Entra ID.
It has no password, OTP or registration screen of its own, and calls no sign-in or token endpoint of its backend.
The app is a public client: it uses the Authorization Code flow with PKCE (S256), holds the provider's tokens itself, and sends the provider's access token to LibreDB Studio as the bearer.
There is no client secret anywhere in the app.
The app runs on Android and iOS, and signs in through the system browser of each: a Custom Tab on Android and `ASWebAuthenticationSession` on iOS.

Part 1 is the setup guide.
Part 2 describes how it works inside.

How far each provider was verified:

| Provider | Status |
| --- | --- |
| Keycloak | Walked through by hand on the Android emulator against the stack in `tool/studio-dev` (Keycloak 26.8.1, see [studio.md](studio.md)); not run on iOS (see [Tests](#tests)) |
| Zitadel | Written from Zitadel's documentation; not yet run against a live tenant |
| Auth0 | Written from Auth0's documentation; not yet run against a live tenant |
| Microsoft Entra ID | Written from Microsoft's documentation; not yet run against a live tenant |

The provider sections below are a starting point for those three, and a report from a real tenant is welcome.

# Part 1: Setup

## Quick start

1. Register a public client (no client secret) at your provider, with PKCE S256 and the redirect URI of the app (see [Redirect URI](#redirect-uri)).
2. Make the provider put the role claim into the access token, where LibreDB Studio maps it (see [Roles](#roles)).
3. Build the app with the issuer and the client id:

```shell
fvm flutter run --target lib/main/main_prod.dart \
  --dart-define=OIDC_ISSUER=https://id.example.com/realms/acme \
  --dart-define=OIDC_CLIENT_ID=acme-app
```

A file of `KEY=value` lines works too, through `--dart-define-from-file=oidc.env`, as `tool/studio-dev/studio-dev.env` shows.
Every value is compiled in, so a change needs a new build.

The login page then shows a single "Sign in with SSO" button.
Registration, forgot password and change password belong to the provider, so the app has no page for them.

### Redirect URI

With the default scheme `org.libredb.mobile` (`OIDC_REDIRECT_SCHEME`), the app uses one URI, `org.libredb.mobile:/oauth2redirect` (`OidcSettings.redirectUri`), as the redirect URI of a sign-in and as the post-logout redirect URI on both platforms:

| Platform | Sign-in surface |
| --- | --- |
| Android | Custom Tab |
| iOS | `ASWebAuthenticationSession`, shared browser session |

Register it at your provider as a redirect URI and as a post-logout redirect URI.

## Try it locally with Keycloak

`tool/studio-dev/docker-compose.yml` starts Keycloak 26.8.1 and LibreDB Studio behind a local TLS proxy, with the public client `libredb-mobile` already registered for `org.libredb.mobile:/oauth2redirect`, and `tool/studio-dev/studio-dev.env` points a `main_prod.dart` build at it.
[studio.md](studio.md) has the commands, the users (`admin` / `admin` and `user` / `user`), and the steps that make the Android emulator and the iOS simulator trust the stack's CA.

What the walkthrough shows:
- With the default `OIDC_PROMPT=login`, every sign-in asks for the password, even while the Keycloak session lives.
- Add `--dart-define=OIDC_PROMPT=omit` and the next sign-in completes without a form while the Keycloak session lives.
- The realm gives access tokens a 60 second life, so an API call a minute after sign-in gets a 401 from Studio, and the app refreshes at Keycloak and retries without signing out.
- Logout ends the Keycloak session as well: the next sign-in asks for the password again.
- Logout first tells Studio at `POST /api/auth/logout`, so Studio's audit trail shows the sign-out as it shows a web sign-out.
  An access token that has expired is refreshed first, since Studio records nothing for an expired token and still answers success.
  The app waits for the refresh and that answer for at most three seconds, never sends the record twice, and signs out whatever they answer.

A protocol mapper writes the realm roles to `realm_access.roles`, and an audience mapper puts Studio's API audience into the access token; [studio.md](studio.md) describes the client.

## Keycloak

1. In the admin console, open your realm and create a client under **Clients**, then **Create client**:
   - Client type: OpenID Connect.
   - Client authentication: Off, which makes it a public client.
   - Authentication flow: Standard flow only; switch Direct access grants off.
2. In the client's settings:
   - **Valid redirect URIs:** `org.libredb.mobile:/oauth2redirect`.
   - **Valid post logout redirect URIs:** `org.libredb.mobile:/oauth2redirect`.
3. Under **Advanced**, set **Proof Key for Code Exchange Code Challenge Method** to `S256`.
4. Roles: the realm-role mapper writes `realm_access.roles` to the access token by default, which is where Studio reads it.
   The ID token needs no role: the app takes the role from Studio's `GET /api/auth/me`.
5. Audience: Keycloak's access token carries `aud: account`, not your API.
   Add an **Audience** mapper to the client's dedicated scope (**Client scopes** tab of the client, then the `-dedicated` scope, then **Add mapper**, **By configuration**, **Audience**), with **Included Client Audience** set to your backend's client and **Add to access token** on.
   Your backend then checks that audience.

```env
OIDC_ISSUER=https://keycloak.example.com/realms/acme
OIDC_CLIENT_ID=acme-app
```

Keycloak issues a refresh token without `offline_access`, so the default scope is enough.
The logout sends the ID token as `id_token_hint`, so Keycloak ends the session without asking the user to confirm it.
Keycloak gives the ID token the access token's lifespan, and accepts an expired `id_token_hint` at its logout endpoint (checked against 26.8.1).

## Zitadel

Not yet run against a live tenant; this section follows Zitadel's documentation.

1. In the console, create a project, then add an application of type **Native** with the **PKCE** authentication method.
2. Redirect URIs: `org.libredb.mobile:/oauth2redirect`, and the same URI as the post logout URI.
3. Grant types: switch **Refresh Token** on, and add `offline_access` to `OIDC_SCOPE`, or Zitadel issues no refresh token.
4. Roles: create the project roles, grant them to users, and request them with the scope `urn:zitadel:iam:org:project:roles`.
   The claim is an object whose keys are the role names (`{"admin": {"<org id>": "<org domain>"}}`).
   Set Studio's `OIDC_ROLE_CLAIM` to `urn:zitadel:iam:org:project:roles`: Studio 1.1.0 and later take the keys of that object as the role names; before 1.1.0 no role was read from it, so no account matched `OIDC_ADMIN_ROLES` (see [Roles](#roles)).
5. Audience: set the application's **Auth Token Type** to **JWT**, because the default bearer token is opaque and a backend cannot verify it against the JWKS.
   Add the scope `urn:zitadel:iam:org:project:id:<project id>:aud`, so the project id is in the access token's `aud`.

```env
OIDC_ISSUER=https://acme.zitadel.cloud
OIDC_CLIENT_ID=<native client id>
OIDC_SCOPE=openid profile email offline_access urn:zitadel:iam:org:project:roles urn:zitadel:iam:org:project:id:<project id>:aud
```

Zitadel advertises its `end_session_endpoint` through discovery, so the provider logout needs no special case.

## Auth0

Not yet run against a live tenant; this section follows Auth0's documentation.

1. Create an application of type **Native** under **Applications**.
   It is a public client: its token endpoint authentication method is **None**.
2. Settings of the application:
   - **Allowed Callback URLs:** `org.libredb.mobile:/oauth2redirect`.
   - **Allowed Logout URLs:** `org.libredb.mobile:/oauth2redirect`.
   - Under **Advanced Settings**, **OAuth**, keep the JSON Web Token signature algorithm at **RS256**: an HS256 ID token needs the client secret to verify, and the app fails closed on it.
3. Audience: create an API under **Applications**, **APIs**, and set `OIDC_AUDIENCE` to its identifier.
   Without an audience, Auth0 issues an opaque access token that your backend cannot verify against the JWKS.
4. Refresh: switch **Allow Offline Access** on for that API and add `offline_access` to `OIDC_SCOPE`; refresh token rotation is recommended.
5. Roles: Auth0 puts no roles in the tokens by default.
   Add a post-login Action that writes them to the access token under a namespaced claim, and set Studio's `OIDC_ROLE_CLAIM` to that claim's name, here `https://example.com/roles`.
   Studio 1.1.0 and later read a claim whose name holds dots whole; before 1.1.0 no role was read from it, so no account matched `OIDC_ADMIN_ROLES`. The access token, not only the ID token, must carry it, because Studio's bearer channel maps the role from the access token:

```javascript
exports.onExecutePostLogin = async (event, api) => {
  const roles = event.authorization?.roles ?? [];
  api.accessToken.setCustomClaim('https://example.com/roles', roles);
};
```

```env
OIDC_ISSUER=https://acme.eu.auth0.com/
OIDC_CLIENT_ID=<native client id>
OIDC_SCOPE=openid profile email offline_access
OIDC_AUDIENCE=https://api.example.com
```

Use the issuer exactly as the `issuer` of your tenant's discovery document, which for Auth0 ends with a slash.
Auth0 advertises an `end_session_endpoint` only when **RP-Initiated Logout End Session Endpoint Discovery** is on in the tenant's advanced settings.
Without it, for an issuer on `auth0.com` or a subdomain of it, the app falls back to Auth0's `/v2/logout` with `client_id` and `returnTo`.
That fallback is the only provider-specific code path; a custom domain needs the discovery setting on.

## Microsoft Entra ID

Not yet run against a live tenant; this section follows Microsoft's documentation.

1. Register an application under **App registrations**, **New registration**.
2. Under **Authentication**, add the platform **Mobile and desktop applications** with the redirect URI `org.libredb.mobile:/oauth2redirect`.
   The same URI is the `post_logout_redirect_uri`, so it is already registered for the logout.
3. Audience: under **Expose an API**, set the application ID URI (`api://<application id>`) and add a scope, for example `access_as_user`.
   Put `api://<application id>/access_as_user` in `OIDC_SCOPE`.
   Without a scope of your own API, the access token is for Microsoft Graph, and your backend cannot verify it.
   Set `requestedAccessTokenVersion` (`accessTokenAcceptedVersion` in the older manifest) to `2`, so the access token's `iss` is the v2.0 issuer that your backend expects.
4. Refresh: add `offline_access` to `OIDC_SCOPE`, or Entra ID issues no refresh token and the session ends when the access token expires.
5. Roles: define **App roles** on the registration and assign them to users or groups under **Enterprise applications**.
   Entra ID writes them to the `roles` claim of the access token for an API exposed by the same registration, where Studio maps them.

```env
OIDC_ISSUER=https://login.microsoftonline.com/<tenant id>/v2.0
OIDC_CLIENT_ID=<application id>
OIDC_SCOPE=openid profile email offline_access api://<application id>/access_as_user
```

Entra ID advertises its `end_session_endpoint` through discovery.

## Configuration reference

All values are compile-time defines, read once at bootstrap (`lib/infrastructure/config/auth_config.dart`).
Strings are trimmed; flags and `OIDC_PROMPT` are also lower-cased.

| Variable | Required | Default | Meaning |
| --- | --- | --- | --- |
| `OIDC_ISSUER` | Yes | none | Issuer URL, with discovery at `/.well-known/openid-configuration` under it. `https` in any case, or `http` on `localhost`, `127.0.0.1` or `[::1]` outside a prod build, which stops at start on any `http` issuer ([security.md](security.md), "Encryption in transit"). No query and no fragment |
| `OIDC_CLIENT_ID` | Yes | none | The public client id |
| `OIDC_SCOPE` | No | `openid profile email` | Space-separated, and must contain `openid`. Zitadel, Auth0 and Entra ID need `offline_access` for a refresh token |
| `OIDC_AUDIENCE` | No | unset | Sent as `audience` on the authorization request (Auth0) |
| `OIDC_PROMPT` | No | `login` | `login`, `consent`, `select_account`, or `omit` to send none. Any other value, `none` included, is a configuration error |
| `OIDC_AUTO_REDIRECT` | No | off | `true`, `1`, `on` or `yes` turn it on; `false`, `0`, `off`, `no` or empty leave it off. Any other value is a configuration error |
| `OIDC_LOGOUT_HINT` | No | on | The same spellings. Off sends no `id_token_hint` at logout |
| `OIDC_REDIRECT_SCHEME` | No | `org.libredb.mobile` | Custom URI scheme of the redirect URI `<scheme>:/oauth2redirect`: a lower-case letter, then lower-case letters, digits, `+`, `-` or `.`. It must equal the Android manifest placeholder |

There is no `OIDC_CLIENT_SECRET`: the app is a public client, and a guard test fails when anything in `lib/` names a client secret or builds a client authentication other than `OidcClientAuthentication.none`.

An invalid configuration does not stop the app, and a build without `OIDC_ISSUER` or `OIDC_CLIENT_ID` is one: there is no other way to sign in.
It starts, the login page shows "Single sign-on is not configured correctly in this app. Contact your administrator." in place of the button, and the log names the variable and the rule it breaks.
Such a build fails closed on a session that an earlier, correctly configured build stored: it never restores it, so the user starts signed out with that sentence, and it never refreshes it.
The stored session stays on the device unread, and is wiped if this build ends a session.

To change the redirect scheme, change it in three places together:
- `OidcSettings.defaultRedirectScheme` in `lib/infrastructure/config/auth_config.dart`;
- `manifestPlaceholders["oidcRedirectScheme"]` in `android/app/build.gradle.kts`, which `test/architecture/oidc_platform_setup_test.dart` ties to the default;
- the redirect URIs registered at your provider, and `redirectUris` and `post.logout.redirect.uris` of the `libredb-mobile` client in `tool/studio-dev/docker-compose.yml` for the local stack.

On Android the scheme the app sends must equal the manifest placeholder, so an Android build changes it only through the default and the placeholder together.
`OIDC_REDIRECT_SCHEME` at build time overrides the scheme the app sends, which is enough on iOS, where `ASWebAuthenticationSession` takes the scheme from the redirect URI; an Android build given a value other than the placeholder never receives its redirect.

### Automatic redirect

With `OIDC_AUTO_REDIRECT` on, a signed-out cold start that lands on the login page starts the sign-in without a tap.
It fires at most once per app run, and never after a sign-in error, the configuration error, a cancel at the provider, or a logout the user started in the same run.
The SSO button stays available in every case.

## Roles

The app reads no role from a token, maps none and stores none.
LibreDB Studio maps the role from the access token under its own `OIDC_ROLE_CLAIM`, `OIDC_ADMIN_ROLES` and `OIDC_USER_ROLES`, and enforces it on every request; the app takes the role only from Studio's answer to `GET /api/auth/me` (`StudioIdentity.role`), as Studio's web client does.
So the provider must put the role claim into the access token, and an app build has no role setting.

A sign-in stores the provider's tokens, then calls `GET /api/auth/me`, and succeeds only on its 200.
Any other answer clears the stored tokens and leaves the user on the login page with the reason:

| Studio answers | The login page says |
| --- | --- |
| 401, without a code or with `AUTH_REQUIRED` after one refresh | Studio did not accept this sign-in. Try again, or ask an administrator for access. |
| 403 `BEARER_NO_ROLE` (from libredb-studio#1922 on) | This account has no role in Studio. Ask an administrator to give it one. |
| 403 `BEARER_NO_IDENTITY` (from libredb-studio#1922 on) | Studio cannot tell who this account is. Ask an administrator to check the account's email and username. |
| 503 `IDENTITY_PROVIDER_UNAVAILABLE`, no network, or another error | The sentence of that error |

Studio records a refused account in its audit as `permission_denied` with the reason `bearer_no_role`, `bearer_no_identity` or `bearer_token_invalid` (Studio's `docs/OIDC.md`).
The role can lag the provider by one access token lifetime, because Studio maps it from the token; Studio answers 403 meanwhile.

## Backend contract

The app's backend is LibreDB Studio ([studio.md](studio.md)), and every API request carries `Authorization: Bearer <access token>` from the provider.
Studio verifies the access token's signature against the issuer's JWKS and checks `iss`, `aud` and `exp`, so the provider must put Studio's audience into the access token:

| Provider | How |
| --- | --- |
| Keycloak | An audience mapper or a client scope |
| Auth0 | `OIDC_AUDIENCE` |
| Entra ID | A scope of the exposed API (`api://<application id>/<scope>`) in `OIDC_SCOPE` |
| Zitadel | The JWT access token type and the project audience scope |

Studio answers 401 to a missing, invalid or expired token, after which the app refreshes once at the provider and retries, and 403 to a valid token without permission.
The app calls Studio's API only; the sign-in, the token refresh and the provider logout go to the provider.
Studio answers who the user is at `GET /api/auth/me`, which `StudioIdentityRepository` reads and the profile sheet of the shell shows, with the username and Studio's role.
Users and roles live at the provider, so the app has no user management.

### Which 401 ends the session

By default every 401 means the bearer is no longer valid: the app refreshes the session, and ends it when the refresh cannot fix the 401.
A backend that also answers 401 for other reasons needs that rule narrowed, or a refused database password would sign the user out.
LibreDB Studio is such a backend: it answers 401 with `AUTH_ERROR` when a database refuses its credentials and with `LLM_AUTH` when a model key is rejected, and only its `code: "AUTH_REQUIRED"` means the session ended.
The rule is one getter, `AppDependencies.sessionExpiredPredicate` in `lib/app/di/app_dependencies.dart`, which in this app is `isStudioSessionExpired` (`lib/infrastructure/studio/studio_session_policy.dart`): only a 401 with `AUTH_REQUIRED`, or a 401 without a code, ends the session.
A 401 the predicate does not match reaches the caller as an ordinary error.

## Troubleshooting

The log lines below come from `AppLogger`.
A `main_local.dart` build uses its development filter, which prints nothing once asserts are off, so its sign-in and refresh lines are seen only in a debug build; a `main_prod.dart` build prints info and above.

**The login page says "Single sign-on is not configured correctly in this app."**
The `OIDC_*` settings break a rule, or the build has none.
The log line `OIDC configuration is invalid: <reason>` names the variable, such as a missing `OIDC_ISSUER`, an `http` issuer that is not on a loopback host, `OIDC_PROMPT=none` or an unknown flag spelling.
Fix the defines and build again; trying again cannot help.

**"The identity provider could not be reached."**
Discovery, the JWKS or the token endpoint could not be fetched, or did not validate.
Check that the issuer answers at `<issuer>/.well-known/openid-configuration`, and that its `issuer` value equals `OIDC_ISSUER` (Auth0's ends with a slash).
With the local stack on the Android emulator, run `tool/studio-dev/trust-android-emulator.sh` again after every emulator boot: it forwards the ports and installs the stack's CA.

**The provider shows "Invalid parameter: redirect_uri".**
The redirect URI the app sent is not registered.
Check that the scheme equals `OIDC_REDIRECT_SCHEME` and the Android manifest placeholder, and that `<scheme>:/oauth2redirect` is registered.

**"Studio did not accept this sign-in." or "This account has no role in Studio."**
The provider signed the user in, but Studio refused the access token's account at `GET /api/auth/me`.
Most often the account holds none of Studio's `OIDC_ADMIN_ROLES` or `OIDC_USER_ROLES` under its `OIDC_ROLE_CLAIM`, or the role claim is not in the access token; Studio's audit names the reason.
Studio before libredb-studio#1922 answers every refusal, and an unreachable provider, with the same 401, so the first sentence covers them all there.

**"Sign-in failed. Please try again."**
The provider answered with an error, or its answer failed a check: a `state` mismatch, a refused code exchange, an ID token whose signature, `iss`, `aud`, `exp` or `nonce` does not verify, or a token answer without `expires_in`.
The log names the error type and the provider's error code, never its text.
An Auth0 application that signs with HS256 fails here; switch it to RS256.

**Every sign-in asks for the password.**
That is `OIDC_PROMPT=login`, the default; set `OIDC_PROMPT=omit` to reuse the provider session.

**The session ends after a few minutes or right at expiry.**
The provider issued no refresh token, or refused the refresh.
Entra ID, Auth0 and Zitadel need `offline_access` in `OIDC_SCOPE`; Keycloak refuses a refresh after the realm's SSO Session Idle (30 minutes by default).
Every refresh request sends the configured scope, as the `oidc` package does; a provider that refuses that on a refresh ends the session.

**Logout leaves the provider session active.**
The provider advertises no `end_session_endpoint`, such as Google, so only the app session ends; that is expected.
When a provider logout fails or the user closes its page, the app still signs out and says "You are signed out of this app, but your session at the identity provider may still be active."
The app signs out on this device first and runs the provider logout after that, so the sentence can appear after the login page shows.
With `OIDC_LOGOUT_HINT=false` Keycloak asks the user to confirm each logout.

**Keycloak says "Restart login cookie not found" on iOS.**
See [Known limitations](#known-limitations): `ASWebAuthenticationSession` is unverified with Keycloak's login cookies.

**The Android build fails in the manifest merger.**
The `oidc_android` plugin needs the `oidcRedirectScheme` placeholder in `android/app/build.gradle.kts`, in every build.

## Mock mode without Keycloak

`main_prod.dart` signs in through the provider its `OIDC_*` defines name, and `main_local.dart` signs in without one.
`main_local.dart` passes `LocalSignInDependencies` (`lib/app/di/local_sign_in_dependencies.dart`) to `AppBootstrap.run`, which replaces only the provider: its `IOidcClient` is `LocalOidcClient` (`lib/infrastructure/auth/oidc/local_oidc_client.dart`).
A tap on "Sign in with SSO" signs in at once with tokens the mock API accepts (`MOCK_TOKEN`, valid for an hour), every refresh gives new ones, and there is no provider logout.
Everything above the client runs as in production: `SsoAuthRepository` stores the session, the API calls go to the mocked Studio of `assets/mock/`, and a 401 refreshes through `OidcTokenRotation`.

The double is debug only and never part of a production build:
- both constructors throw a `StateError` in a profile or release build;
- only `main_local.dart` and the tests import it, so the compiler leaves it out of `main_prod.dart`, and `test/architecture/local_sign_in_test.dart` fails when anything that `main_prod.dart` imports, directly or not, imports it.

The widget tests build the app with `LocalSignInDependencies` as well, so they need neither a network nor a provider.

## Known limitations

- **Keycloak's ID token is short-lived:** Keycloak gives the ID token the access token's lifespan, 60 seconds in the local stack, so the stored ID token is usually expired.
  A refresh and a logout still work with it: the refresh does not check its expiry, and Keycloak 26.8.1 accepts an expired `id_token_hint` and ends the session.
- **One client operation at a time:** sign-in, refresh and provider logout run one after another, so a pending interactive sign-in or provider logout holds back the others until it ends.
- **Keycloak's cookies on iOS:** Keycloak 26.8.1 chooses its cookie attributes by user agent, and `ASWebAuthenticationSession` on iOS is unverified with them.
  If a sign-in fails there with "Restart login cookie not found", check the cookie attributes Keycloak sends to Safari.
- **iOS shows its system alert:** iOS uses the shared browser session, so it asks "... Wants to Use ... to Sign In" on every sign-in and every logout.
- **The role lags the provider:** Studio maps it from the access token, so a role changed at the provider shows after the next token refresh.
- **No user management:** manage users and their roles at the provider.

# Part 2: Internals

## Flows

### Bootstrap

`AppBootstrap.run` builds the `AppDependencies` through `AppBootstrap.definedDependencies`, unless `main_local.dart` passes its local sign-in, which reads `AuthMode.fromDefines(const AuthDefines())` once.
The defines become `OidcAuthMode(settings)`, or `OidcMisconfiguredAuthMode(reason)` when the settings break a rule or are missing; the reason is logged at error.
The mode is injected through `AppDependencies.authMode`, and `AppScope` provides it as `AuthMode`.
Only `OidcAuthMode` builds the OIDC pieces: `IOidcClient`, `ISsoAuthRepository`, one `TokenRotation` shared by the startup step and the `ApiClient`, `SsoSignOutAuthRepository` and `SsoAutoRedirectGate`.
`OidcMisconfiguredAuthMode` builds no OIDC client and fails closed: `SessionCubit` gets `MisconfiguredSsoSessionStartup`, which answers `oidc_config` without reading the stored session, and the `ApiClient` gets `RefusingTokenRotation`, which refuses every refresh without a request.

### Sign-in

1. The SSO button, or the automatic redirect, adds `SsoSignInRequested` to `LoginBloc`, whose handler drops a second request while one runs.
2. `SignInWithSsoUseCase` calls `SsoAuthRepository.signIn`, which calls `OidcClient.signIn`.
3. `OidcClient` fetches discovery (cached for 5 minutes, failures never cached), and the package builds the request with a PKCE S256 challenge, `state`, `nonce`, the redirect URI `<scheme>:/oauth2redirect`, the scope, `prompt` unless it is `omit`, and `audience` when it is set.
4. The platform opens the provider's page: a Custom Tab on Android, `ASWebAuthenticationSession` on iOS.
5. On return the package checks `state`, exchanges the code with the verifier, and validates the ID token: its signature against the JWKS, `iss`, `aud`, `exp` and `nonce`.
6. `OidcClient` requires an access token, an ID token and `expires_in`, and strips `nonce`, `at_hash` and `c_hash` from the claims it hands on.
7. `SsoAuthRepository` requires a string `sub` and `iss` (`oidc_no_claims` otherwise), and reads no role and no username from the claims.
8. The session is persisted through `AuthSessionRepository` with its rollback: the access token in the bearer slot (`SecureStorageKeys.jwtToken`), the refresh token when one was issued, the ID token under `oidcIdToken`, and the access token expiry under `accessTokenExpiresAt`.
9. `SignInWithSsoUseCase` calls Studio's `GET /api/auth/me` with the new bearer; any failure clears the stored session and rejects with the code of [Roles](#roles).
10. On Studio's 200 `LoginBloc` emits `LoginLoadedState`; `AppSessionListeners`, `SessionCubit.markAuthenticated` and the idle observer run, and the page navigates to the safe return path.

A closed provider page is a cancel: no message, logged at info, and the automatic redirect gate closes.
On Android a closed Custom Tab tells the app nothing, so `OidcClient` cancels the pending flow whenever the app resumes; after a real redirect that cancel does nothing.
Every outcome ends with the transaction store cleared and the package's user manager forgetting its user, so the app's secure storage is the only place tokens live.

### Startup

`SessionCubit.restore` runs the startup step first, under its own 15 second limit, and only then reads the stored session under the existing 10 second storage limit.
The step checks the stored access token expiry, never a JWT `exp`, so an opaque access token works too.
An expired access token with a stored refresh token is refreshed through the shared `TokenRotation`.
The refresh follows the session-generation rules of `TokenRefreshInterceptor`: a wipe during the reads ends the step without a grant, an answer that comes after the session ended is dropped, and what it stored while the session ended is taken back.
A refused refresh, an expired access token without a refresh token, or a failed write of the refreshed tokens clears the session, and the user starts signed out.
An unreachable provider keeps the stored session.
A step that does not answer within 15 seconds is treated as an unreachable provider: the stored session is read as it is, and the automatic redirect gate closes.
What the step answers after its limit is acted on only while nothing has been emitted since the read after the limit: a late session end ends the session, and any other late answer is only logged.

### Refresh

`TokenRefreshInterceptor` stays the only owner of refresh, with its single flight, its session-generation checks, its rollback, and its check of the stored refresh token after the grant, since the startup step can rotate the session while a request refreshes it.
The package's own refresh timers are off (`AppOidcUserManager`).
The refresh goes through `OidcTokenRotation`:
1. Rotations run one at a time, and a refresh token that the provider has replaced or refused is never sent in a second grant, so a provider with refresh token reuse detection never sees a used token twice.
   A provider that does not rotate refresh tokens answers with no new one, or the same one, so that token stays the stored one and is sent again when the new access token expires.
2. A refresh token that the store no longer holds gets `RotationUnavailable` without a request, and the interceptor retries with the stored tokens.
3. `OidcClient.refresh` hands the stored access token, ID token and refresh token to the package for one `refresh_token` grant at the provider's token endpoint; the stored ID token may have expired.
4. A new ID token's signature is then verified against the provider's keys.
   When the token endpoint has answered but the JWKS cannot be fetched for that check, the grant is not thrown away: the answer keeps the new access and refresh tokens, drops the unchecked ID token so the stored one stays, and a warning is logged.
5. The interceptor stores the new access token and its expiry, the new refresh token when the provider rotates it, and the new ID token when one is returned and checked.

| Answer | Result | Effect |
| --- | --- | --- |
| New tokens | `TokensRotated` | Stored, and the request is retried |
| New tokens, but the JWKS for the new ID token could not be fetched | `TokensRotated` without an ID token | The new access and refresh tokens are stored, the stored ID token stays, and the request is retried |
| `invalid_grant`, `invalid_client` or another client or authentication error, or a new ID token whose signature or claims fail a check | `RotationRefused` | The session ends with reason expired, and the login page shows the button with no error |
| A token endpoint status of 429 or 5xx whatever its error code, a redirect from the token endpoint, `server_error`, `temporarily_unavailable`, discovery that cannot be fetched, or a transport failure | `RotationUnavailable` | The session is kept, the request fails as a network error, and the next 401 tries again |

### Logout

A logout the user starts goes through `SsoSignOutUseCase` and `SsoSignOutAuthRepository.signOut`:
1. It reads the stored ID token, before anything that could delete it: a refresh that ends the session clears the OIDC keys as well.
2. It refreshes an expired access token and records the sign-out at Studio, for at most three seconds, whatever they answer.
   It never sends an access token it knows has expired, such as when the provider could not be reached, and a refresh that answers after the three seconds sends nothing.
   A sign-out that leaves Studio without a record writes one `warn` line naming the reason: budget passed, refresh refused, no refresh token, provider unreachable, store unreadable, or Studio's error code; the user sees nothing for it.
3. It clears the local session, including the OIDC keys, and answers at once with that result and the provider logout started (`SsoSignOut`).
4. `SignOutBloc` signs the app out on that answer, so the login page shows while the provider logout goes on.
5. `OidcClient.endProviderSession` uses the discovered `end_session_endpoint`, else Auth0's `/v2/logout` for an issuer on `auth0.com`, else no provider logout.
6. It opens that endpoint with `client_id`, the `post_logout_redirect_uri` `<scheme>:/oauth2redirect`, and the ID token as `id_token_hint` while `OIDC_LOGOUT_HINT` is on.
7. A failed, cancelled or unopenable provider logout leaves the user signed out; `SignOutBloc` then emits `SignedOutWithProviderSessionLeft`, and `AppSessionListeners` shows the `oidc_logout_incomplete` sentence as a notice over the login page; when the local clear failed, only the notice about stored data left behind shows.

The shell shows a blocking progress indicator until the sign-out is done (`SignOutProgressBarrier`), and `SignOutBloc` drops a second request meanwhile.
No automatic redirect fires in the same run after a user logout.
An idle timeout or an unrefreshable 401 clears the local session only, through `SessionCubit`, because a provider logout needs a browser and the user is not there.

## Module map

| Path | Role |
| --- | --- |
| `lib/infrastructure/config/auth_config.dart` | `AuthDefines`, the sealed `AuthMode` (`OidcAuthMode`, `OidcMisconfiguredAuthMode`), `OidcSettings.parse` and its rules, and the redirect URI |
| `lib/core/security/safe_redirect.dart` | `safeReturnPath`: the return path rules on top of `safeRedirectTarget` |
| `lib/core/security/sensitive_data_scrubber.dart` | `sensitiveExactKeys`: `code`, `code_verifier`, `state`, `nonce`, `session_state`, `id_token_hint` |
| `lib/infrastructure/analytics/sentry_scrub.dart` | Masks those keys in breadcrumbs, keeping the navigation breadcrumb's `state` |
| `lib/core/errors/app_error_code.dart`, `lib/shared/l10n/app_error_code_l10n.dart` | The five `auth.oidc_*` codes, the three `studio.account_*` codes of a refused sign-in, and their sentences |
| `lib/l10n/intl_en.arb`, `lib/l10n/intl_tr.arb` (and `lib/generated/`) | The sentences, the SSO button and its subtitle |
| `lib/infrastructure/storage/secure_storage.dart` | The `oidcIdToken` and `accessTokenExpiresAt` keys and the expiry encoding |
| `lib/features/auth/domain/entities/auth_session.dart` | `AuthSession.oidcIdToken` and `accessTokenExpiresAt` |
| `lib/features/auth/data/repositories/auth_session_repository_impl.dart` | Persist, rollback and clear of the OIDC keys |
| `lib/infrastructure/http/token_rotation.dart` | `TokenRotation`, `TokenRotationResult`, `RefusingTokenRotation` for a misconfigured build, and the `SessionExpiredPredicate` seam |
| `lib/infrastructure/http/interceptors/token_refresh_interceptor.dart` | Refreshes through a `TokenRotation`, honors `RotationUnavailable`, stores the OIDC fields |
| `lib/infrastructure/http/api_client.dart` | Passes the rotation and the 401 predicate to the interceptor |
| `lib/infrastructure/http/interceptors/mock_interceptor.dart` | Answers 401 to an expired JWT bearer in dev mode |
| `lib/infrastructure/auth/oidc/oidc_client.dart` | `IOidcClient` and `OidcClient`: sign-in, refresh, provider logout, error classification, and `OidcPlatformKind` (Android or iOS) |
| `lib/infrastructure/auth/oidc/app_oidc_user_manager.dart` | The package's `OidcUserManager` with timers off, a 5 minute transaction life, session adoption and the refreshed ID token check |
| `lib/infrastructure/auth/oidc/oidc_transaction_store.dart` | The app-owned `OidcStore`, in memory for the run, cleared after every operation |
| `lib/infrastructure/auth/oidc/oidc_token_rotation.dart` | `OidcTokenRotation` |
| `lib/features/auth/domain/repositories/sso_auth_repository.dart`, `lib/features/auth/data/repositories/sso_auth_repository_impl.dart` | `ISsoAuthRepository` and `SsoAuthRepository`: claims and persist |
| `lib/features/auth/domain/entities/sso_sign_in_result.dart` | The sealed `SsoProviderSignIn` of the provider and `SsoSignInResult` of the whole sign-in |
| `lib/features/auth/application/usecases/sign_in_with_sso_usecase.dart` | `SignInWithSsoUseCase`: the provider sign-in, then Studio's `GET /api/auth/me`, clearing the session on a refusal |
| `lib/features/auth/application/login_bloc.dart`, `login_event.dart` | `SsoSignInRequested` and its handler |
| `lib/features/auth/domain/services/sso_session_startup.dart`, `lib/features/auth/data/services/sso_session_startup_impl.dart` | The startup step and its sealed result |
| `lib/features/auth/domain/services/sso_auto_redirect_gate.dart` | `SsoAutoRedirectGate` |
| `lib/features/auth/domain/repositories/sso_sign_out_repository.dart`, `lib/features/auth/application/usecases/sso_sign_out_usecase.dart` | `ISsoSignOutRepository`, `SsoSignOut` (the local clear and the pending provider logout) and `SsoSignOutUseCase` |
| `lib/features/auth/data/repositories/sso_sign_out_auth_repository.dart` | `SsoSignOutAuthRepository`: the local clear, then the provider logout |
| `lib/features/auth/data/services/misconfigured_sso_session_startup.dart` | `MisconfiguredSsoSessionStartup`, which answers `oidc_config` without reading the stored session |
| `lib/app/session/session_cubit.dart` | Runs the startup step under its own limit, `SessionUnauthenticated.signInError` |
| `lib/app/bootstrap/app_bootstrap.dart` | Reads the mode from the defines, or takes the local sign-in of `main_local.dart` |
| `lib/app/di/local_sign_in_dependencies.dart`, `lib/infrastructure/auth/oidc/local_oidc_client.dart` | The debug-only provider double of `main_local.dart`, see [Mock mode without Keycloak](#mock-mode-without-keycloak) |
| `lib/app/bootstrap/app_session_listeners.dart` | Closes the gate on sign-in, logout and a restore past the storage limit, and shows the logout notice, also when it follows the sign-out |
| `lib/app/di/app_dependencies.dart`, `lib/app/di/app_scope.dart` | Builds and provides the OIDC pieces in `OidcAuthMode` only, the fail-closed startup and rotation of `OidcMisconfiguredAuthMode`, and `sessionExpiredPredicate` |
| `lib/features/auth/application/sign_out_bloc.dart` | Signs out on the local clear, then `SignedOutWithProviderSessionLeft` when the provider logout fails |
| `lib/features/auth/presentation/pages/login_page.dart` | The SSO variant of the login page, its error line and the automatic redirect |
| `lib/features/auth/navigation/auth_routes.dart` | The `login` route, the only public one |
| `lib/app/router/app_router.dart`, `lib/app/app.dart` | `/oauth2redirect` to `/login` with no `returnUrl` |
| `android/app/build.gradle.kts` | The `oidcRedirectScheme` manifest placeholder |
| `tool/studio-dev/docker-compose.yml`, `tool/studio-dev/studio-dev.env` | The local Keycloak and Studio, see [studio.md](studio.md) |
| `pubspec.yaml`, `pubspec.lock` | `oidc` 5.0.2, `http` 1.6.0, and `logging` 1.3.0 for tests |

## Security model

- **Public client:** PKCE S256 on every sign-in, and no client secret in the binary; a guard test fails on any `client_secret`, `OIDC_CLIENT_SECRET` or `clientSecret` spelling in `lib/`, and on any client authentication other than `.none`.
- **State and nonce:** always sent and checked by the package.
- **ID token validation:** the package verifies the signature against the JWKS, never hand-written code.
  A refreshed ID token is verified against the provider's keys too, because the package re-verifies it only with the keys of the user it replaces.
- **Issuer:** `https`, except on a loopback host outside a prod build.
- **`prompt=none`** is refused at bootstrap.
- **Tokens:** only in the app's secure storage.
  The package's store keeps no token: `state`, the PKCE verifier, the nonce, the manager's copy of the tokens and the request live in memory for one operation, and a transaction expires after 5 minutes.
- **Provider text:** never on screen.
  The error code picks a fixed sentence, classification goes by error type, and the log gets only the type, the provider's error code and the HTTP status.
- **Logs:** no token, authorization code, verifier, `state`, `nonce`, `session_state` or `id_token_hint` reaches a log line, the dev console or Sentry.
  The scrubber masks the exact keys `code`, `code_verifier`, `state`, `nonce`, `session_state` and `id_token_hint` in bodies and query strings, while names such as `statusCode` keep their values.
  The package's own `package:logging` records do not reach the app's dev console, but go_router's root logging subscription (`debugLogDiagnostics` is on) sends them, unscrubbed, to `dart:developer`, which is the IDE and DevTools log, and a SEVERE one to `FlutterError.dumpErrorToConsole`.
  So the client avoids every record that carries a secret: UserInfo is off.
  `AuthInterceptor`'s request log keeps its existing masked preview of the bearer, the first and last four characters through `maskToken`, which predates this feature.
- **Router:** `/oauth2redirect` always goes to `/login` with no `returnUrl`, so a callback URL never becomes a router location or a return path.
- **Misconfigured build:** fails closed on a stored session: it never restores it and never refreshes it.
- **Return path:** checked on the way in and on the way out with `safeReturnPath`: a local path only, at most 1024 UTF-8 bytes, no control characters, and not the login route; an unsafe value becomes `/`.
- **`id_token_hint`:** always the current session's ID token, because it is written, rolled back and wiped together with the session it belongs to.
- **Credentials in `toString`:** `OidcTokens`, `TokensRotated` and `OidcTokenRotation` print tokens only through `maskToken` or `secretMask`.

### Where the build differs from the design

- The startup step has its own 15 second limit, before the 10 second storage limit, and a timeout keeps the stored session and disables the automatic redirect.
- The `id_token_hint` is the current session's stored ID token by construction; there is no comparison of its `sub` with a stored subject.
- A logout the user starts signs the app out before the provider logout runs, instead of after it, so the login page shows at once and the `oidc_logout_incomplete` sentence can follow it.
- A refresh whose new ID token cannot be checked because the JWKS cannot be fetched keeps the new access and refresh tokens and the stored ID token, since the provider has already traded the refresh token.
- A sign-in whose token response has no `expires_in` fails with `oidc_failed`, because the session could never be refreshed in time.
- The scrubber's exact OIDC keys apply to every logged request: a `state=` or `code=` value in a logged URL and a `{"code": ...}` member in a logged body print `[REDACTED]`.
  Sentry navigation breadcrumbs keep their `didPush`, `didPop` or `didReplace` state.

## Error codes

Each code is an `AppErrorCode` in the `auth.` namespace, with one sentence in each ARB file.

| Code | When | Sentence (English) |
| --- | --- | --- |
| `auth.oidc_config` | Invalid configuration, checked at bootstrap; such a build starts signed out, whatever session is stored. Also a discovery document that names an endpoint the app uses that is not https ([security.md](security.md), "Encryption in transit") | Single sign-on is not configured correctly in this app. Contact your administrator. |
| `auth.oidc_discovery` | Discovery, the JWKS or the token endpoint unreachable, a TLS failure, a response that is not JSON, or a discovery document naming another issuer | The identity provider could not be reached. Try again later, or contact your administrator if this continues. |
| `auth.oidc_no_claims` | The ID token has no string `sub` or `iss` | Sign-in failed. Please try again. |
| `auth.oidc_failed` | Any other failure after the provider answered: a `state` mismatch, a failed code exchange, an invalid ID token, an answer without `expires_in`, or an error from the provider | Sign-in failed. Please try again. |
| `auth.oidc_logout_incomplete` | The provider logout failed, was cancelled or could not be opened; shown after the app has signed out, so it can follow the login page | You are signed out of this app, but your session at the identity provider may still be active. |
| (none) | The user closed or left the provider page: a closed Custom Tab or system sheet | No message |

A sign-in whose session cannot be stored shows the existing `auth.session_persist_failed` sentence, and one that Studio refuses shows a `studio.account_*` sentence, see [Roles](#roles).

## Tests

Each test file below names the behavior it pins.
`test/infrastructure/auth/oidc/support/fake_provider.dart` is an OpenID provider behind `MockClient`, with discovery, JWKS and a token endpoint that sign RS256 ID tokens, so the client tests run the real package end to end without a network.

| Test | What it pins |
| --- | --- |
| `test/infrastructure/config/auth_config_test.dart` | Every variable, default and spelling, every refusal, and the redirect URI |
| `test/app/di/app_dependencies_test.dart`, `test/app/di/app_scope_test.dart`, `test/app/di/app_scope_oidc_test.dart` | The mode's injection; a misconfigured build creates no OIDC client, restores signed out with `oidc_config`, leaves the stored session alone and refreshes through a rotation that refuses |
| `test/core/security/safe_redirect_test.dart` | Each return path rule |
| `test/core/security/sensitive_data_scrubber_test.dart`, `test/infrastructure/analytics/sentry_scrub_test.dart` | The exact OIDC keys, and the navigation breadcrumb's `state` |
| `test/shared/l10n/app_error_code_l10n_test.dart` | Each code's sentence in English and Turkish |
| `test/features/auth/data/repositories/auth_session_repository_impl_test.dart`, `test/infrastructure/storage/secure_storage_test.dart`, `test/features/auth/domain/entities/auth_session_test.dart` | The OIDC keys are written, rolled back and cleared with the session |
| `test/infrastructure/http/interceptors/mock_interceptor_test.dart` | An expired JWT bearer gets a 401, and `MOCK_TOKEN` still passes |
| `test/infrastructure/http/token_rotation_test.dart`, `test/infrastructure/http/interceptors/token_refresh_interceptor_test.dart` | The rotation seam, `RotationUnavailable`, `RefusingTokenRotation` and the narrowed 401 predicate |
| `test/infrastructure/auth/oidc/oidc_transaction_store_test.dart` | The store's namespaces, what `clearTransactions` removes, and the refused `session` namespace |
| `test/infrastructure/auth/oidc/oidc_client_test.dart`, `oidc_token_rotation_test.dart` | Sign-in, the custom-scheme redirect URI, Android cancel on resume, refresh classification (a 429 or 5xx token answer keeps the session, an unreachable JWKS after the grant keeps the new tokens and the stored ID token), a provider that does not rotate refresh tokens, one operation at a time, provider logout and the Auth0 fallback |
| `test/features/auth/data/repositories/sso_auth_repository_impl_test.dart`, `test/features/auth/application/login_bloc_test.dart`, `test/features/auth/application/usecases/sign_in_with_sso_usecase_test.dart`, `test/app/di/app_scope_test.dart` | Claims and persist, whatever the role claim holds; the production log names no user; Studio's 200 as the only success, each refusal clearing once with its code, also for Studio main's 401 and #1922's 403; each outcome in `LoginBloc`; dropped concurrent taps |
| `test/features/auth/data/services/sso_session_startup_impl_test.dart`, `test/features/auth/domain/services/sso_auto_redirect_gate_test.dart`, `test/app/session/session_cubit_test.dart` | The startup step, its time limit and late answers, and the gate |
| `test/features/auth/data/repositories/sso_sign_out_auth_repository_test.dart`, `test/features/auth/application/sign_out_bloc_test.dart`, `test/app/bootstrap/app_session_listeners_test.dart`, `test/app/bootstrap/app_session_listeners_sso_test.dart` | Provider logout; the sign-out answers before the provider logout ends, so the login page opens while it is pending; the incomplete-logout notice, also when it comes later; the gate after logout and after a restore past the storage limit |
| `test/features/auth/presentation/pages/login_screen_test.dart`, `login_screen_golden_test.dart` | The SSO page, each error sentence, the Turkish text, the automatic redirect and the `login_screen_sso_light` golden |
| `test/app/router/app_router_test.dart` | The password routes resolve to nothing, and a callback URL, with or without a trailing slash, lands on `/login` with no `returnUrl` |
| `test/infrastructure/config/auth_config_test.dart`, `test/integration/app_smoke_test.dart`, `test/architecture/local_sign_in_test.dart` | A build without OIDC settings has no password sign-in to fall back to; `main_local.dart`'s local sign-in opens the connection list; `main_prod.dart` never imports the double |
| `test/features/auth/sso_log_hygiene_test.dart` | A full sign-in, refresh, logout and pushed callback route print no token, code, verifier, `state` or `nonce` |
| `test/architecture/oidc_platform_setup_test.dart` | The Android placeholder equals the default scheme, no client secret in `lib/` and only `.none` client authentication, and no intent filter for the scheme or its placeholder in any app manifest |

The sign-in was also walked through by hand on the Android emulator (an API 30 Google APIs image) against `tool/studio-dev`, as [studio.md](studio.md) describes: sign-in, the connection list over the bearer, the refresh after the 60 second token life, and a logout that ends the Keycloak session.
iOS was not run.
