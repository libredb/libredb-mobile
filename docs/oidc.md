# Single Sign-On with OpenID Connect

The app signs users in one of two ways, chosen once at build time with `AUTH_PROVIDER`.
`jwt`, the default, is the password and OTP sign-in against a backend that issues its own JWT.
`oidc` signs the user in through any OpenID Connect provider, such as Keycloak, Zitadel, Auth0 or Microsoft Entra ID.
In `oidc` mode the app is a public client: it uses the Authorization Code flow with PKCE (S256), holds the provider's tokens itself, and sends the provider's access token to the backend as the bearer.
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
2. Make the provider put your role claim in both the ID token and the access token.
3. Build the app with the issuer and the client id:

```shell
fvm flutter run --target lib/main/main_prod.dart \
  --dart-define=AUTH_PROVIDER=oidc \
  --dart-define=OIDC_ISSUER=https://id.example.com/realms/acme \
  --dart-define=OIDC_CLIENT_ID=acme-app \
  --dart-define=OIDC_ROLE_CLAIM=realm_access.roles
```

A file of `KEY=value` lines works too, through `--dart-define-from-file=oidc.env`, as `tool/studio-dev/studio-dev.env` shows.
Every value is compiled in, so a change needs a new build.

The login page then shows a single "Sign in with SSO" button.
Registration, forgot password, OTP sign-in and change password belong to the provider, so their routes are not registered in `oidc` mode and their entry points are hidden.

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
4. Roles: the realm-role mapper writes `realm_access.roles` to the access token by default, but not to the ID token.
   Open **Client scopes**, then **roles**, then **Mappers**, then **realm roles**, switch **Add to ID token** on, and save.
   The role claim must be in both tokens: the app reads it from the ID token for its UI, and your backend from the access token.
5. Audience: Keycloak's access token carries `aud: account`, not your API.
   Add an **Audience** mapper to the client's dedicated scope (**Client scopes** tab of the client, then the `-dedicated` scope, then **Add mapper**, **By configuration**, **Audience**), with **Included Client Audience** set to your backend's client and **Add to access token** on.
   Your backend then checks that audience.

```env
AUTH_PROVIDER=oidc
OIDC_ISSUER=https://keycloak.example.com/realms/acme
OIDC_CLIENT_ID=acme-app
OIDC_ROLE_CLAIM=realm_access.roles
OIDC_ADMIN_ROLES=admin
OIDC_USER_ROLES=user
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
   In the application's token settings, switch on the option that adds the user roles to the ID token (**User roles inside ID Token**); the app sends no UserInfo request, so roles that are only in the UserInfo answer never reach it.
   The claim is an object whose keys are the role names (`{"admin": {"<org id>": "<org domain>"}}`), which the app's role mapping reads as the roles `admin` (see [Role mapping](#role-mapping)).
   The role claim must be in both tokens, so check that your backend sees it in the access token too.
5. Audience: set the application's **Auth Token Type** to **JWT**, because the default bearer token is opaque and a backend cannot verify it against the JWKS.
   Add the scope `urn:zitadel:iam:org:project:id:<project id>:aud`, so the project id is in the access token's `aud`.

```env
AUTH_PROVIDER=oidc
OIDC_ISSUER=https://acme.zitadel.cloud
OIDC_CLIENT_ID=<native client id>
OIDC_SCOPE=openid profile email offline_access urn:zitadel:iam:org:project:roles urn:zitadel:iam:org:project:id:<project id>:aud
OIDC_ROLE_CLAIM=urn:zitadel:iam:org:project:roles
OIDC_ADMIN_ROLES=admin
OIDC_USER_ROLES=user
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
   Add a post-login Action that writes them to both tokens under a namespaced claim:

```javascript
exports.onExecutePostLogin = async (event, api) => {
  const claim = 'https://example.com/roles';
  const roles = event.authorization?.roles ?? [];
  api.idToken.setCustomClaim(claim, roles);
  api.accessToken.setCustomClaim(claim, roles);
};
```

```env
AUTH_PROVIDER=oidc
OIDC_ISSUER=https://acme.eu.auth0.com/
OIDC_CLIENT_ID=<native client id>
OIDC_SCOPE=openid profile email offline_access
OIDC_AUDIENCE=https://api.example.com
OIDC_ROLE_CLAIM=https://example.com/roles
OIDC_ADMIN_ROLES=admin
OIDC_USER_ROLES=user
```

Use the issuer exactly as the `issuer` of your tenant's discovery document, which for Auth0 ends with a slash.
The claim name `https://example.com/roles` contains dots, and the app first looks it up as one literal top-level key, so it works as it is.
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
   Entra ID writes them to the `roles` claim of the ID token, and of the access token for an API exposed by the same registration, so both tokens carry them.

```env
AUTH_PROVIDER=oidc
OIDC_ISSUER=https://login.microsoftonline.com/<tenant id>/v2.0
OIDC_CLIENT_ID=<application id>
OIDC_SCOPE=openid profile email offline_access api://<application id>/access_as_user
OIDC_ROLE_CLAIM=roles
OIDC_ADMIN_ROLES=Admin
OIDC_USER_ROLES=User
```

Role names are compared case-insensitively.
Entra ID advertises its `end_session_endpoint` through discovery.

## Configuration reference

All values are compile-time defines, read once at bootstrap (`lib/infrastructure/config/auth_config.dart`).
Strings are trimmed; flags and `OIDC_PROMPT` are also lower-cased.

| Variable | Required | Default | Meaning |
| --- | --- | --- | --- |
| `AUTH_PROVIDER` | No | `jwt` | `jwt` or `oidc`, trimmed and lower-cased. Any other value stops the app at bootstrap with an error that names the variable |
| `OIDC_ISSUER` | Yes | none | Issuer URL, with discovery at `/.well-known/openid-configuration` under it. `https` in any case, or `http` on `localhost`, `127.0.0.1` or `[::1]`. No query and no fragment |
| `OIDC_CLIENT_ID` | Yes | none | The public client id |
| `OIDC_SCOPE` | No | `openid profile email` | Space-separated, and must contain `openid`. Zitadel, Auth0 and Entra ID need `offline_access` for a refresh token |
| `OIDC_AUDIENCE` | No | unset | Sent as `audience` on the authorization request (Auth0) |
| `OIDC_ROLE_CLAIM` | No | unset | Name or dot path of the role claim in the ID token, such as `realm_access.roles` |
| `OIDC_ADMIN_ROLES` | No | `admin` | Comma list, trimmed and compared case-insensitively |
| `OIDC_USER_ROLES` | No | unset | Comma list. When set, an account with neither an admin nor a user role is refused. Needs `OIDC_ROLE_CLAIM` |
| `OIDC_PROMPT` | No | `login` | `login`, `consent`, `select_account`, or `omit` to send none. Any other value, `none` included, is a configuration error |
| `OIDC_AUTO_REDIRECT` | No | off | `true`, `1`, `on` or `yes` turn it on; `false`, `0`, `off`, `no` or empty leave it off. Any other value is a configuration error |
| `OIDC_LOGOUT_HINT` | No | on | The same spellings. Off sends no `id_token_hint` at logout |
| `OIDC_REDIRECT_SCHEME` | No | `org.libredb.mobile` | Custom URI scheme of the redirect URI `<scheme>:/oauth2redirect`: a lower-case letter, then lower-case letters, digits, `+`, `-` or `.`. It must equal the Android manifest placeholder |

An empty role list, or one made only of commas, counts as unset.
There is no `OIDC_CLIENT_SECRET`: the app is a public client, and a guard test fails when anything in `lib/` names a client secret or builds a client authentication other than `OidcClientAuthentication.none`.

An invalid `oidc` configuration does not stop the app.
It starts, the login page shows "Single sign-on is not configured correctly in this app. Contact your administrator." in place of the button, and the log names the variable and the rule it breaks.
Such a build fails closed on a session that an earlier, correctly configured build stored: it never restores it, so the user starts signed out with that sentence, and it never refreshes through the backend's `jwt` refresh endpoint, so the provider's refresh token never reaches the backend.
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

## Role mapping

The app maps the ID token's claims to one app role with a port of LibreDB Studio's `mapOIDCRole` (`lib/core/security/oidc_role_mapping.dart`):

1. Without `OIDC_ROLE_CLAIM`, every account is a `user`, unless `OIDC_USER_ROLES` is set, which refuses it.
2. When the claim name exists as a top-level key of the claims, that key's value is used as it is, dots and all, so Auth0's `https://example.com/roles` works.
3. Otherwise the name is walked as a dot path, such as `realm_access.roles`.
   A missing value, or a step through a value that is not an object, means no match.
4. The value becomes a list of role names:
   - an object contributes its keys, which is Zitadel's shape (`{"admin": {"<org id>": "<org domain>"}}`);
   - an array contributes its elements, where an object element contributes its keys (`[{"user": {...}}]`) and any other element becomes a string;
   - any other value becomes one name.
5. Any case-insensitive match with `OIDC_ADMIN_ROLES` gives `admin`, so admin wins when the claim holds both.
6. Otherwise a match with `OIDC_USER_ROLES` gives `user`.
7. Anything else is a `user` while `OIDC_USER_ROLES` is unset, and is refused once it is set.

`admin` grants `ROLE_ADMIN` and `ROLE_USER`, and `user` grants `ROLE_USER`, the roles `GET /account` returns for those users in `jwt` mode.
A refused account sees "Your account has no role that allows access to this app. Ask your administrator.", and nothing is stored.

| Claims | `OIDC_ROLE_CLAIM` | Admin / user roles | Result |
| --- | --- | --- | --- |
| `{"realm_access": {"roles": ["admin", "offline_access"]}}` | `realm_access.roles` | `admin` / `user` | `admin` |
| `{"https://example.com/roles": ["User"]}` | `https://example.com/roles` | `admin` / `user` | `user` |
| `{"urn:zitadel:iam:org:project:roles": {"admin": {"1": "acme"}}}` | `urn:zitadel:iam:org:project:roles` | `admin` / unset | `admin` |
| `{"roles": ["guest"]}` | `roles` | `admin` / unset | `user` |
| `{"roles": ["guest"]}` | `roles` | `admin` / `user` | refused |

Roles are fixed at sign-in.
A role changed at the provider shows in the app at the next sign-in, and the backend, which checks the roles of every access token, stays the authorization boundary.
The app's roles only shape the UI: menus, routes and admin pages.

## Backend contract

In `oidc` mode every API request carries `Authorization: Bearer <access token>` from the provider.
The backend must:
- verify the access token's signature against the issuer's JWKS, and check `iss`, `aud` (its own audience) and `exp`;
- map roles from the access token for its own authorization decisions, which is why each provider section puts the role claim in both tokens;
- answer 401 to a missing, invalid or expired token, after which the app refreshes once at the provider and retries, and a second 401 ends the session;
- answer 403 to a valid token without permission, which the app already handles.

The app calls the same endpoints as in `jwt` mode, minus `/authenticate*`, `/register`, `/account/reset-password/*`, `/account/change-password` and `/token/refresh`.
The account repository calls `GET /account` after sign-in for the profile.
LibreDB Studio has no such endpoint and answers who the user is at `GET /api/auth/me`, which `StudioIdentityRepository` reads; showing that answer in the profile sheet is milestone M2 ([#17](https://github.com/libredb/libredb-mobile/issues/17), [roadmap.md](roadmap.md)).
The account fetch runs after sign-in, and its failure does not end the session.
User management pages keep calling the backend as they do today; managing users in `oidc` mode is out of scope, and users and roles live at the provider.

How to get an access token with the right audience:

| Provider | How |
| --- | --- |
| Keycloak | An audience mapper or a client scope |
| Auth0 | `OIDC_AUDIENCE` |
| Entra ID | A scope of the exposed API (`api://<application id>/<scope>`) in `OIDC_SCOPE` |
| Zitadel | The JWT access token type and the project audience scope |

### Next.js with `jose`

```ts
// lib/bearer.ts
import { createRemoteJWKSet, jwtVerify, type JWTPayload } from 'jose';

const issuer = process.env.OIDC_ISSUER!; // https://localhost:8443/realms/libredb
const audience = process.env.OIDC_API_AUDIENCE!; // the audience your provider puts in the access token
const jwks = createRemoteJWKSet(new URL(process.env.OIDC_JWKS_URI!)); // jwks_uri of the discovery document

export type Caller = { subject: string; roles: Set<string> };

// Returns the caller of a valid bearer, or null, which the route answers with 401.
export async function verifyBearer(request: Request): Promise<Caller | null> {
  const [scheme, token] = (request.headers.get('authorization') ?? '').split(' ');
  if (scheme?.toLowerCase() !== 'bearer' || !token) return null;
  try {
    // jwtVerify checks the signature, iss, aud and exp.
    const { payload } = await jwtVerify(token, jwks, { issuer, audience });
    return { subject: payload.sub!, roles: appRoles(payload) };
  } catch {
    return null;
  }
}

// The same mapping as the app: admin grants ROLE_ADMIN and ROLE_USER, user grants ROLE_USER.
function appRoles(payload: JWTPayload): Set<string> {
  const realmAccess = payload.realm_access as { roles?: string[] } | undefined;
  const names = (realmAccess?.roles ?? []).map((role) => role.toLowerCase());
  if (names.includes('admin')) return new Set(['ROLE_ADMIN', 'ROLE_USER']);
  if (names.includes('user')) return new Set(['ROLE_USER']);
  return new Set();
}
```

```ts
// app/api/users/route.ts
import { NextResponse } from 'next/server';
import { verifyBearer } from '@/lib/bearer';

export async function GET(request: Request) {
  const caller = await verifyBearer(request);
  if (!caller) return NextResponse.json({ code: 'AUTH_REQUIRED' }, { status: 401 });
  if (!caller.roles.has('ROLE_ADMIN')) return NextResponse.json({ code: 'FORBIDDEN' }, { status: 403 });
  return NextResponse.json([]);
}
```

### Spring Boot resource server

With `spring-boot-starter-oauth2-resource-server`, Spring fetches discovery and the JWKS from the issuer, and checks the signature, `iss` and `exp`:

```yaml
spring:
  security:
    oauth2:
      resourceserver:
        jwt:
          issuer-uri: https://localhost:8443/realms/libredb
          audiences: libredb-studio-api
```

A `JwtAuthenticationConverter` turns the role claim into the authorities the backend already uses:

```java
@Configuration
@EnableWebSecurity
class SecurityConfiguration {

  @Bean
  SecurityFilterChain api(HttpSecurity http) throws Exception {
    http.authorizeHttpRequests(auth -> auth
            .requestMatchers("/api/admin/**").hasAuthority("ROLE_ADMIN")
            .anyRequest().authenticated())
        .oauth2ResourceServer(oauth -> oauth.jwt(jwt -> jwt.jwtAuthenticationConverter(roleConverter())));
    return http.build();
  }

  // Maps Keycloak's realm_access.roles: admin grants ROLE_ADMIN and ROLE_USER, user grants ROLE_USER.
  private JwtAuthenticationConverter roleConverter() {
    JwtAuthenticationConverter converter = new JwtAuthenticationConverter();
    converter.setJwtGrantedAuthoritiesConverter(jwt -> {
      Map<String, Object> realmAccess = jwt.getClaimAsMap("realm_access");
      Collection<?> roles = realmAccess == null ? List.of() : (Collection<?>) realmAccess.getOrDefault("roles", List.of());
      if (roles.contains("admin")) {
        return List.of(new SimpleGrantedAuthority("ROLE_ADMIN"), new SimpleGrantedAuthority("ROLE_USER"));
      }
      if (roles.contains("user")) return List.of(new SimpleGrantedAuthority("ROLE_USER"));
      return List.of();
    });
    return converter;
  }
}
```

The resource server answers 401 to a missing or invalid bearer and 403 to a missing authority, which is what the app expects.

### Which 401 ends the session

By default every 401 means the bearer is no longer valid: the app refreshes the session, and ends it when the refresh cannot fix the 401.
A backend that also answers 401 for other reasons needs that rule narrowed, or a refused database password would sign the user out.
LibreDB Studio is such a backend: it answers 401 with `AUTH_ERROR` when a database refuses its credentials and with `LLM_AUTH` when a model key is rejected, and only its `code: "AUTH_REQUIRED"` means the session ended.
The rule is one getter, `AppDependencies.sessionExpiredPredicate` in `lib/app/di/app_dependencies.dart`, which in this app is `isStudioSessionExpired` (`lib/infrastructure/studio/studio_session_policy.dart`): only a 401 with `AUTH_REQUIRED`, or a 401 without a code, ends the session.
The predicate applies in both modes, and a 401 it does not match reaches the caller as an ordinary error.

## Troubleshooting

The log lines below come from `AppLogger`.
A `main_local.dart` build uses its development filter, which prints nothing once asserts are off, so its sign-in and refresh lines are seen only in a debug build; a `main_prod.dart` build prints info and above.

**The app stops at startup with "AUTH_PROVIDER is ..., but it must be jwt or oidc".**
`AUTH_PROVIDER` has a value other than `jwt` or `oidc`; an unknown value is never read as `jwt`.

**The login page says "Single sign-on is not configured correctly in this app."**
The `oidc` settings break a rule.
The log line `OIDC configuration is invalid: <reason>` names the variable, such as an `http` issuer that is not on a loopback host, `OIDC_PROMPT=none`, an unknown flag spelling, or `OIDC_USER_ROLES` without `OIDC_ROLE_CLAIM`.
Fix the defines and build again; trying again cannot help.

**"The identity provider could not be reached."**
Discovery, the JWKS or the token endpoint could not be fetched, or did not validate.
Check that the issuer answers at `<issuer>/.well-known/openid-configuration`, and that its `issuer` value equals `OIDC_ISSUER` (Auth0's ends with a slash).
With the local stack on the Android emulator, run `tool/studio-dev/trust-android-emulator.sh` again after every emulator boot: it forwards the ports and installs the stack's CA.

**The provider shows "Invalid parameter: redirect_uri".**
The redirect URI the app sent is not registered.
Check that the scheme equals `OIDC_REDIRECT_SCHEME` and the Android manifest placeholder, and that `<scheme>:/oauth2redirect` is registered.

**"Your account has no role that allows access to this app."**
`OIDC_USER_ROLES` is set, and the ID token holds neither an admin nor a user role under `OIDC_ROLE_CLAIM`.
Most often the role claim is only in the access token: in Keycloak switch **Add to ID token** on, and in Zitadel **User roles inside ID Token**.
The app sends no UserInfo request, so roles must be in the ID token itself.

**Everyone is a `user`, even admins.**
`OIDC_ROLE_CLAIM` is unset or names a claim the ID token does not carry, or `OIDC_ADMIN_ROLES` does not match the role names; decode an ID token and compare.

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
The `oidc_android` plugin needs the `oidcRedirectScheme` placeholder in `android/app/build.gradle.kts`, in every build, `jwt` included.

## Switching modes

`AUTH_PROVIDER` decides only how the user signs in.
The entry point still decides between the mock API and the real one, so both entry points accept both modes:

| | `AUTH_PROVIDER=jwt` | `AUTH_PROVIDER=oidc` |
| --- | --- | --- |
| `main_local.dart` (mock API) | Today's demo | Sign-in at a real provider, API calls answered by the mock |
| `main_prod.dart` (real API) | Password sign-in and the backend's JWT | A real provider and a real backend |

There is no mock identity provider: the Keycloak of `tool/studio-dev` plays that part.
In `jwt` mode the app constructs and calls nothing from the OIDC path: no discovery request, no OIDC client and no OIDC storage key.
The `oidc` package stays in `pubspec.yaml` in both modes, so every Android build merges its redirect activity.

Sign out before a device switches from one build mode to the other.
The two modes share the bearer slot of secure storage, so an `oidc` build reads a `jwt` session it finds as signed in, without an expiry, until its first 401 ends it.

## Known limitations

- **Keycloak's ID token is short-lived:** Keycloak gives the ID token the access token's lifespan, 60 seconds in the local stack, so the stored ID token is usually expired.
  A refresh and a logout still work with it: the refresh does not check its expiry, and Keycloak 26.8.1 accepts an expired `id_token_hint` and ends the session.
- **One client operation at a time:** sign-in, refresh and provider logout run one after another, so a pending interactive sign-in or provider logout holds back the others until it ends.
- **Keycloak's cookies on iOS:** Keycloak 26.8.1 chooses its cookie attributes by user agent, and `ASWebAuthenticationSession` on iOS is unverified with them.
  If a sign-in fails there with "Restart login cookie not found", check the cookie attributes Keycloak sends to Safari.
- **iOS shows its system alert:** iOS uses the shared browser session, so it asks "... Wants to Use ... to Sign In" on every sign-in and every logout.
- **Roles are fixed at sign-in:** a role changed at the provider shows at the next sign-in.
- **No user management:** the user list, the user editor and account editing still call the backend; with single sign-on, manage users at the provider.

# Part 2: Internals

## Flows

### Bootstrap

`AppBootstrap.run` reads `AuthMode.fromDefines(const AuthDefines())` once.
An unknown `AUTH_PROVIDER` throws `AuthProviderConfigError`, which is logged and stops the app before any screen.
`oidc` becomes `OidcAuthMode(settings)`, or `OidcMisconfiguredAuthMode(reason)` when the settings break a rule; the reason is logged at error.
The mode is injected through `AppDependencies.authMode`, and `AppScope` provides it as `AuthMode`.
Only `OidcAuthMode` builds the OIDC pieces: `IOidcClient`, `ISsoAuthRepository`, one `TokenRotation` shared by the startup step and the `ApiClient`, `SsoSignOutAuthRepository` and `SsoAutoRedirectGate`.
`OidcMisconfiguredAuthMode` builds no OIDC client and fails closed: `SessionCubit` gets `MisconfiguredSsoSessionStartup`, which answers `oidc_config` without reading the stored session, and the `ApiClient` gets `RefusingTokenRotation`, which refuses every refresh without a request, so a stored provider refresh token never reaches `BackendTokenRotation`.

### Sign-in

1. The SSO button, or the automatic redirect, adds `SsoSignInRequested` to `LoginBloc`, whose handler drops a second request while one runs.
2. `SignInWithSsoUseCase` calls `SsoAuthRepository.signIn`, which calls `OidcClient.signIn`.
3. `OidcClient` fetches discovery (cached for 5 minutes, failures never cached), and the package builds the request with a PKCE S256 challenge, `state`, `nonce`, the redirect URI `<scheme>:/oauth2redirect`, the scope, `prompt` unless it is `omit`, and `audience` when it is set.
4. The platform opens the provider's page: a Custom Tab on Android, `ASWebAuthenticationSession` on iOS.
5. On return the package checks `state`, exchanges the code with the verifier, and validates the ID token: its signature against the JWKS, `iss`, `aud`, `exp` and `nonce`.
6. `OidcClient` requires an access token, an ID token and `expires_in`, and strips `nonce`, `at_hash` and `c_hash` from the claims it hands on.
7. `SsoAuthRepository` requires a string `sub` and `iss` (`oidc_no_claims` otherwise), maps the role (`oidc_no_role` otherwise, with nothing written), and takes the username from `email`, else `preferred_username`, else `sub`.
8. The session is persisted through `AuthSessionRepository` with its rollback: the access token in the bearer slot (`SecureStorageKeys.jwtToken`), the refresh token when one was issued, the ID token under `oidcIdToken`, and the access token expiry under `accessTokenExpiresAt`; the username and roles go to local storage.
9. `LoginBloc` emits the same `LoginLoadedState(roles)` as a password sign-in, without the `GET /account` call; `AppSessionListeners`, `SessionCubit.markAuthenticated`, the account fetch and the idle observer run unchanged, and the page navigates to the safe return path.

A closed provider page is a cancel: no message, logged at info, and the automatic redirect gate closes.
On Android a closed Custom Tab tells the app nothing, so `OidcClient` cancels the pending flow whenever the app resumes; after a real redirect that cancel does nothing.
Every outcome ends with the transaction store cleared and the package's user manager forgetting its user, so the app's secure storage is the only place tokens live.

### Startup in `oidc` mode

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
In `oidc` mode the refresh goes through `OidcTokenRotation`:
1. Rotations run one at a time, and a refresh token that the provider has replaced or refused is never sent in a second grant, so a provider with refresh token reuse detection never sees a used token twice.
   A provider that does not rotate refresh tokens answers with no new one, or the same one, so that token stays the stored one and is sent again when the new access token expires.
2. A refresh token that the store no longer holds gets `RotationUnavailable` without a request, and the interceptor retries with the stored tokens.
3. `OidcClient.refresh` hands the stored access token, ID token and refresh token to the package for one `refresh_token` grant at the provider's token endpoint; the stored ID token may have expired.
4. A new ID token's signature is then verified against the provider's keys.
   When the token endpoint has answered but the JWKS cannot be fetched for that check, the grant is not thrown away: the answer keeps the new access and refresh tokens, drops the unchecked ID token so the stored one stays, and a warning is logged.
5. The interceptor stores the new access token and its expiry, the new refresh token when the provider rotates it, and the new ID token when one is returned and checked; roles are not re-mapped.

| Answer | Result | Effect |
| --- | --- | --- |
| New tokens | `TokensRotated` | Stored, and the request is retried |
| New tokens, but the JWKS for the new ID token could not be fetched | `TokensRotated` without an ID token | The new access and refresh tokens are stored, the stored ID token stays, and the request is retried |
| `invalid_grant`, `invalid_client` or another client or authentication error, or a new ID token whose signature or claims fail a check | `RotationRefused` | The session ends with reason expired, and the login page shows the button with no error |
| A token endpoint status of 429 or 5xx whatever its error code, `server_error`, `temporarily_unavailable`, discovery that cannot be fetched, or a transport failure | `RotationUnavailable` | The session is kept, the request fails as a network error, and the next 401 tries again |

`jwt` mode keeps `BackendTokenRotation`, today's `POST /token/refresh`, where any failure ends the session.

### Logout

A logout the user starts goes through `SsoSignOutUseCase` and `SsoSignOutAuthRepository.signOut`:
1. It reads the stored ID token.
2. It clears the local session exactly as in `jwt` mode, including the OIDC keys, and answers at once with that result and the provider logout started (`SsoSignOut`).
3. `SignOutBloc` signs the app out on that answer, so the login page shows while the provider logout goes on.
4. `OidcClient.endProviderSession` uses the discovered `end_session_endpoint`, else Auth0's `/v2/logout` for an issuer on `auth0.com`, else no provider logout.
5. It opens that endpoint with `client_id`, the `post_logout_redirect_uri` `<scheme>:/oauth2redirect`, and the ID token as `id_token_hint` while `OIDC_LOGOUT_HINT` is on.
6. A failed, cancelled or unopenable provider logout leaves the user signed out; `SignOutBloc` then emits `SignedOutWithProviderSessionLeft`, and `AppSessionListeners` shows the `oidc_logout_incomplete` sentence as a notice over the login page; when the local clear failed, only the notice about stored data left behind shows.

No automatic redirect fires in the same run after a user logout.
An idle timeout or an unrefreshable 401 clears the local session only, through `SessionCubit`, because a provider logout needs a browser and the user is not there.

## Module map

| Path | Role |
| --- | --- |
| `lib/infrastructure/config/auth_config.dart` | `AuthDefines`, the sealed `AuthMode` (`JwtAuthMode`, `OidcAuthMode`, `OidcMisconfiguredAuthMode`), `OidcSettings.parse` and its rules, and the redirect URI |
| `lib/core/security/oidc_role_mapping.dart` | `mapOidcRole` and `appRolesFor`, pure functions |
| `lib/core/security/safe_redirect.dart` | `safeReturnPath`: the return path rules on top of `safeRedirectTarget` |
| `lib/core/security/sensitive_data_scrubber.dart` | `sensitiveExactKeys`: `code`, `code_verifier`, `state`, `nonce`, `session_state`, `id_token_hint` |
| `lib/infrastructure/analytics/sentry_scrub.dart` | Masks those keys in breadcrumbs, keeping the navigation breadcrumb's `state` |
| `lib/core/errors/app_error_code.dart`, `lib/shared/l10n/app_error_code_l10n.dart` | The six `auth.oidc_*` codes and their sentences |
| `lib/l10n/intl_en.arb`, `lib/l10n/intl_tr.arb` (and `lib/generated/`) | The sentences, the SSO button and its subtitle |
| `lib/infrastructure/storage/secure_storage.dart` | The `oidcIdToken` and `accessTokenExpiresAt` keys and the expiry encoding |
| `lib/features/auth/domain/entities/auth_session.dart` | `AuthSession.oidcIdToken` and `accessTokenExpiresAt` |
| `lib/features/auth/data/repositories/auth_session_repository_impl.dart` | Persist, rollback and clear of the OIDC keys, only with `oidcKeys: true` |
| `lib/infrastructure/http/token_rotation.dart` | `TokenRotation`, `TokenRotationResult`, `BackendTokenRotation`, `RefusingTokenRotation` for a misconfigured build, and the `SessionExpiredPredicate` seam |
| `lib/infrastructure/http/interceptors/token_refresh_interceptor.dart` | Refreshes through a `TokenRotation`, honors `RotationUnavailable`, stores the OIDC fields |
| `lib/infrastructure/http/api_client.dart` | Passes the rotation and the 401 predicate to the interceptor |
| `lib/infrastructure/http/interceptors/mock_interceptor.dart` | Answers 401 to an expired JWT bearer in dev mode |
| `lib/infrastructure/auth/oidc/oidc_client.dart` | `IOidcClient` and `OidcClient`: sign-in, refresh, provider logout, error classification, and `OidcPlatformKind` (Android or iOS) |
| `lib/infrastructure/auth/oidc/app_oidc_user_manager.dart` | The package's `OidcUserManager` with timers off, a 5 minute transaction life, session adoption and the refreshed ID token check |
| `lib/infrastructure/auth/oidc/oidc_transaction_store.dart` | The app-owned `OidcStore`, in memory for the run, cleared after every operation |
| `lib/infrastructure/auth/oidc/oidc_token_rotation.dart` | `OidcTokenRotation` |
| `lib/features/auth/domain/repositories/sso_auth_repository.dart`, `lib/features/auth/data/repositories/sso_auth_repository_impl.dart` | `ISsoAuthRepository` and `SsoAuthRepository`: claims, roles and persist |
| `lib/features/auth/domain/entities/sso_sign_in_result.dart` | The sealed `SsoSignInResult` |
| `lib/features/auth/application/usecases/sign_in_with_sso_usecase.dart` | `SignInWithSsoUseCase` |
| `lib/features/auth/application/login_bloc.dart`, `login_event.dart` | `SsoSignInRequested` and its handler |
| `lib/features/auth/domain/services/sso_session_startup.dart`, `lib/features/auth/data/services/sso_session_startup_impl.dart` | The startup step and its sealed result |
| `lib/features/auth/domain/services/sso_auto_redirect_gate.dart` | `SsoAutoRedirectGate` |
| `lib/features/auth/domain/repositories/sso_sign_out_repository.dart`, `lib/features/auth/application/usecases/sso_sign_out_usecase.dart` | `ISsoSignOutRepository`, `SsoSignOut` (the local clear and the pending provider logout) and `SsoSignOutUseCase` |
| `lib/features/auth/data/repositories/sso_sign_out_auth_repository.dart` | `SsoSignOutAuthRepository`: the local clear, then the provider logout |
| `lib/features/auth/data/services/misconfigured_sso_session_startup.dart` | `MisconfiguredSsoSessionStartup`, which answers `oidc_config` without reading the stored session |
| `lib/app/session/session_cubit.dart` | Runs the startup step under its own limit, `SessionUnauthenticated.signInError` |
| `lib/app/bootstrap/app_bootstrap.dart` | Reads the mode, stops on an unknown `AUTH_PROVIDER` |
| `lib/app/bootstrap/app_session_listeners.dart` | Closes the gate on sign-in, logout and a restore past the storage limit, and shows the logout notice, also when it follows the sign-out |
| `lib/app/di/app_dependencies.dart`, `lib/app/di/app_scope.dart` | Builds and provides the OIDC pieces in `OidcAuthMode` only, the fail-closed startup and rotation of `OidcMisconfiguredAuthMode`, and `sessionExpiredPredicate` |
| `lib/app/shell/menu_bloc/menu_bloc.dart`, `menu_state.dart` | Signs out on the local clear, then `MenuStateStatus.providerSessionLeft` when the provider logout fails |
| `lib/features/auth/presentation/pages/login_page.dart` | The SSO variant of the login page, its error line and the automatic redirect |
| `lib/features/auth/navigation/auth_routes.dart` | Only the `login` route in the `oidc` modes |
| `lib/app/router/app_router.dart`, `lib/app/app.dart` | Routes by mode, and `/oauth2redirect` to `/login` with no `returnUrl` |
| `lib/features/settings/presentation/pages/settings_screen.dart`, `lib/app/shell/command_palette/command_palette_widget.dart` | Change password hidden outside `jwt` mode |
| `android/app/build.gradle.kts` | The `oidcRedirectScheme` manifest placeholder |
| `tool/studio-dev/docker-compose.yml`, `tool/studio-dev/studio-dev.env` | The local Keycloak and Studio, see [studio.md](studio.md) |
| `pubspec.yaml`, `pubspec.lock` | `oidc` 5.0.2, `http` 1.6.0, and `logging` 1.3.0 for tests |

## Security model

- **Public client:** PKCE S256 on every sign-in, and no client secret in the binary; a guard test fails on any `client_secret`, `OIDC_CLIENT_SECRET` or `clientSecret` spelling in `lib/`, and on any client authentication other than `.none`.
- **State and nonce:** always sent and checked by the package.
- **ID token validation:** the package verifies the signature against the JWKS, never hand-written code.
  A refreshed ID token is verified against the provider's keys too, because the package re-verifies it only with the keys of the user it replaces.
- **Issuer:** `https`, except on a loopback host.
- **`prompt=none`** is refused at bootstrap.
- **Tokens:** only in the app's secure storage.
  The package's store keeps no token: `state`, the PKCE verifier, the nonce, the manager's copy of the tokens and the request live in memory for one operation, and a transaction expires after 5 minutes.
- **Provider text:** never on screen.
  The error code picks a fixed sentence, classification goes by error type, and the log gets only the type, the provider's error code and the HTTP status.
- **Logs:** no token, authorization code, verifier, `state`, `nonce`, `session_state` or `id_token_hint` reaches a log line, the dev console or Sentry.
  The scrubber masks the exact keys `code`, `code_verifier`, `state`, `nonce`, `session_state` and `id_token_hint` in bodies and query strings, while names such as `statusCode` keep their values.
  The package's own `package:logging` records do not reach the app's dev console, but go_router's root logging subscription (`debugLogDiagnostics` is on) sends them, unscrubbed, to `dart:developer`, which is the IDE and DevTools log, and a SEVERE one to `FlutterError.dumpErrorToConsole`.
  So the client avoids every record that carries a secret: UserInfo is off.
  `AuthInterceptor`'s request log keeps its existing masked preview of the bearer, the first and last four characters through `maskToken`, which predates this feature and applies in both modes.
- **Router:** `/oauth2redirect` always goes to `/login` with no `returnUrl`, so a callback URL never becomes a router location or a return path.
- **Misconfigured build:** fails closed on a stored session: it never restores it and never refreshes, so a provider refresh token never reaches the backend's `jwt` refresh endpoint.
- **Return path:** checked on the way in and on the way out with `safeReturnPath`: a local path only, at most 1024 UTF-8 bytes, no control characters, and not the login route; an unsafe value becomes `/`.
- **`id_token_hint`:** always the current session's ID token, because it is written, rolled back and wiped together with the session it belongs to.
- **Credentials in `toString`:** `OidcTokens`, `TokensRotated` and `OidcTokenRotation` print tokens only through `maskToken` or `secretMask`.

### Where the build differs from the design

- The startup step has its own 15 second limit, before the 10 second storage limit, and a timeout keeps the stored session and disables the automatic redirect.
- The `id_token_hint` is the current session's stored ID token by construction; there is no comparison of its `sub` with a stored subject.
- A logout the user starts signs the app out before the provider logout runs, instead of after it, so the login page shows at once and the `oidc_logout_incomplete` sentence can follow it.
- A refresh whose new ID token cannot be checked because the JWKS cannot be fetched keeps the new access and refresh tokens and the stored ID token, since the provider has already traded the refresh token.
- A sign-in whose token response has no `expires_in` fails with `oidc_failed`, because the session could never be refreshed in time.
- The scrubber's exact OIDC keys apply in `jwt` mode too: a `state=` or `code=` value in a logged URL and a `{"code": ...}` member in a logged body now print `[REDACTED]`.
  Sentry navigation breadcrumbs keep their `didPush`, `didPop` or `didReplace` state.

## Error codes

Each code is an `AppErrorCode` in the `auth.` namespace, with one sentence in each ARB file.

| Code | When | Sentence (English) |
| --- | --- | --- |
| `auth.oidc_config` | Invalid configuration, checked at bootstrap; such a build starts signed out, whatever session is stored | Single sign-on is not configured correctly in this app. Contact your administrator. |
| `auth.oidc_discovery` | Discovery, the JWKS or the token endpoint unreachable, a TLS failure, a response that is not JSON, or a discovery document naming another issuer | The identity provider could not be reached. Try again later, or contact your administrator if this continues. |
| `auth.oidc_no_role` | Role mapping refused the account | Your account has no role that allows access to this app. Ask your administrator. |
| `auth.oidc_no_claims` | The ID token has no string `sub` or `iss` | Sign-in failed. Please try again. |
| `auth.oidc_failed` | Any other failure after the provider answered: a `state` mismatch, a failed code exchange, an invalid ID token, an answer without `expires_in`, or an error from the provider | Sign-in failed. Please try again. |
| `auth.oidc_logout_incomplete` | The provider logout failed, was cancelled or could not be opened; shown after the app has signed out, so it can follow the login page | You are signed out of this app, but your session at the identity provider may still be active. |
| (none) | The user closed or left the provider page: a closed Custom Tab or system sheet | No message |

A sign-in whose session cannot be stored shows the existing `auth.session_persist_failed` sentence.

## Tests

Each test file below names the behavior it pins.
`test/infrastructure/auth/oidc/support/fake_provider.dart` is an OpenID provider behind `MockClient`, with discovery, JWKS and a token endpoint that sign RS256 ID tokens, so the client tests run the real package end to end without a network.

| Test | What it pins |
| --- | --- |
| `test/infrastructure/config/auth_config_test.dart` | Every variable, default and spelling, every refusal, and the redirect URI |
| `test/app/di/app_dependencies_test.dart`, `test/app/di/app_scope_test.dart`, `test/app/di/app_scope_oidc_test.dart` | The mode's injection; a `jwt` build creates no OIDC client and touches no OIDC key; a misconfigured build restores signed out with `oidc_config`, leaves the stored session alone and refreshes through a rotation that refuses |
| `test/core/security/oidc_role_mapping_test.dart` | LibreDB Studio's `mapOIDCRole` cases, the literal key, the object and array-wrapped shapes |
| `test/core/security/safe_redirect_test.dart` | Each return path rule |
| `test/core/security/sensitive_data_scrubber_test.dart`, `test/infrastructure/analytics/sentry_scrub_test.dart` | The exact OIDC keys, and the navigation breadcrumb's `state` |
| `test/shared/l10n/app_error_code_l10n_test.dart` | Each code's sentence in English and Turkish |
| `test/features/auth/data/repositories/auth_session_repository_impl_test.dart`, `test/infrastructure/storage/secure_storage_test.dart`, `test/features/auth/domain/entities/auth_session_test.dart` | The OIDC keys are written, rolled back and cleared with the session, and never touched in `jwt` mode |
| `test/infrastructure/http/interceptors/mock_interceptor_test.dart` | An expired JWT bearer gets a 401, and `MOCK_TOKEN` still passes |
| `test/infrastructure/http/token_rotation_test.dart`, `test/infrastructure/http/interceptors/token_refresh_interceptor_test.dart` | The rotation seam, `RotationUnavailable`, `RefusingTokenRotation`, the narrowed 401 predicate, and `jwt` refresh unchanged |
| `test/infrastructure/auth/oidc/oidc_transaction_store_test.dart` | The store's namespaces, what `clearTransactions` removes, and the refused `session` namespace |
| `test/infrastructure/auth/oidc/oidc_client_test.dart`, `oidc_token_rotation_test.dart` | Sign-in, the custom-scheme redirect URI, Android cancel on resume, refresh classification (a 429 or 5xx token answer keeps the session, an unreachable JWKS after the grant keeps the new tokens and the stored ID token), a provider that does not rotate refresh tokens, one operation at a time, provider logout and the Auth0 fallback |
| `test/features/auth/data/repositories/sso_auth_repository_impl_test.dart`, `test/features/auth/application/login_bloc_test.dart`, `test/features/auth/application/usecases/sign_in_with_sso_usecase_test.dart` | Claims, roles and persist; the production log names the role but not the username; each outcome in `LoginBloc`; dropped concurrent taps |
| `test/features/auth/data/services/sso_session_startup_impl_test.dart`, `test/features/auth/domain/services/sso_auto_redirect_gate_test.dart`, `test/app/session/session_cubit_test.dart` | The startup step, its time limit and late answers, and the gate |
| `test/features/auth/data/repositories/sso_sign_out_auth_repository_test.dart`, `test/app/shell/menu_bloc/menu_bloc_test.dart`, `test/app/bootstrap/app_session_listeners_test.dart`, `test/app/bootstrap/app_session_listeners_sso_test.dart` | Provider logout; the sign-out answers before the provider logout ends, so the login page opens while it is pending; the incomplete-logout notice, also when it comes later; the gate after logout and after a restore past the storage limit |
| `test/features/auth/presentation/pages/login_screen_test.dart`, `login_screen_golden_test.dart` | The SSO page, each error sentence, the Turkish text, the automatic redirect and the `login_screen_sso_light` golden |
| `test/app/router/app_router_test.dart` | The password routes are absent in `oidc` mode, and a callback URL, with or without a trailing slash, lands on `/login` with no `returnUrl` |
| `test/features/settings/presentation/pages/settings_screen_test.dart`, `test/app/shell/command_palette/command_palette_widget_test.dart` | Change password offered only in `jwt` mode |
| `test/features/auth/sso_log_hygiene_test.dart` | A full sign-in, refresh, logout and pushed callback route print no token, code, verifier, `state` or `nonce` |
| `test/architecture/oidc_platform_setup_test.dart` | The Android placeholder equals the default scheme, no client secret in `lib/` and only `.none` client authentication, and no intent filter for the scheme or its placeholder in any app manifest |

The sign-in was also walked through by hand on the Android emulator (an API 30 Google APIs image) against `tool/studio-dev`, as [studio.md](studio.md) describes: sign-in, the connection list over the bearer, the refresh after the 60 second token life, and a logout that ends the Keycloak session.
iOS was not run.
