# LibreDB Platform

Platform mode is the sign-in entry for Platform admins: sign-in stays Keycloak, and every call in Platform mode goes to LibreDB Platform's bearer API under `/api/v1`.
The app still holds no database credential, and it never creates, edits or deletes a connection.
This page is the contract the app relies on; paths in libredb-platform are given at its `origin/main` `d6ad8f5`, whose `docs/api/v1.md` is the source of truth.

## The defines

| Define | Meaning |
| --- | --- |
| `PLATFORM_API_URL` | Platform's origin plus `/api`, for example `https://platform.example.org/api`; empty for a build without Platform mode |
| `PLATFORM_CERT_PINS` | The pins of the host of `PLATFORM_API_URL` ([security.md](security.md#certificate-pinning)); empty leaves it on the system trust store |

`AppConfig.platform` (`lib/infrastructure/config/environment.dart`) is `PlatformConfigured` with that base URL and its pins, or `PlatformNotConfigured` when `PLATFORM_API_URL` is empty.
A prod build refuses a `PLATFORM_API_URL` that is not an https URL, or has surrounding whitespace, with `ProdHttpsConfigError`, and a `PLATFORM_CERT_PINS` without `PLATFORM_API_URL` with `CertificatePinsConfigError`.
Dev and test builds carry `PlatformConfigured` without a base URL, which `MockInterceptor` answers from `assets/mock/`.
The release workflow does not pass either define until M13-P, so the store build stays Studio-only ([release.md](release.md)).

`OIDC_SCOPE`, `OIDC_AUDIENCE` and `PROD_API_URL` do not change: one Keycloak access token of the client `libredb-mobile` carries both audiences, Studio's and Platform's (libredb-platform `docs/api/v1.md`, "One token serves Studio and Platform").

## The client

`PlatformApiClient` (`lib/infrastructure/platform/platform_api_client.dart`) is its own DI type next to the Studio `ApiClient`, and shares its token rotation; [http-client.md](http-client.md#libredb-platform) describes the chain.
In a build without a Platform target every call fails with `PlatformNotConfiguredException` and no request is sent.

## Endpoints

| Method and path | Answer | Read by |
| --- | --- | --- |
| `GET /api/v1/me` | `{id, email, name, roles, permissions, tenant: {id, name, slug}}` | `PlatformIdentityRepository`, `PlatformIdentityModel` |
| `GET /api/v1/connections` | `{connections: [{id, name, engine, status, hasWriteCredential}]}` | `IPlatformConnectionRepository.list`, `PlatformConnectionsModel` |
| `GET /api/v1/connections/{id}/grants` | `{grants: [{id, subject, subjectUsername, subjectEmail, level, expiresAt, grantedBy: {id, name, email}, grantedAt}]}` | `PlatformGrantRepository.list`, `PlatformGrantJson` |
| `DELETE /api/v1/connections/{id}/grants/{grantId}` | 204, no body | `PlatformGrantRepository.revoke` |

- `GET /api/v1/me` answers the caller's Platform user (libredb-platform `src/app/api/v1/me/route.ts`).
  `roles` is always `["PLATFORM_ADMIN"]` and `permissions` every permission (`src/shared/lib/bearer/with-bearer.ts`); `name` is nullable, `email` and the tenant's fields are not (`prisma/schema.prisma`).
  The app keeps roles and permissions as opaque strings, holds the identity in memory only (`PlatformIdentityCubit`) and never stores it.
  `id` is Platform's user id, not the identity provider's `sub`, so it never keys a store.
- The first call of an account provisions its Platform user and takes an admin seat, so the license can refuse it (`docs/api/v1.md`).
- `GET /api/v1/connections` answers every connection of the install tenant, active and inactive, newest first, with no host, credential or sealed value (libredb-platform `src/features/connections/lib/grant-service.ts`).
  All five fields are always present; `status` is `active` or `inactive` today, and the app keeps `engine` and `status` as opaque strings, an unknown value included, and keeps Platform's order.
  The connections tab (`lib/features/platform_connections/`) shows the list read only: no connection is created, edited or deleted on the phone, and enabling or disabling one comes in M11-P with `PATCH /api/v1/connections/{id}`.
  It loads when the tab opens, on a pull to refresh and on a retry, never on a timer; a tap opens the connection's grants at `/platform/connections/:id`.
- `GET /api/v1/connections/{id}/grants` lists a connection's grants by username, then id, expired grants included (libredb-platform `src/features/connections/lib/grant-service.ts`, `grant.repository.ts`).
  The app keeps that order and never sorts.
  `subjectEmail`, `expiresAt` and `grantedBy.name` are nullable, and a null `expiresAt` is a grant without expiry; `level` is kept as an opaque string, so an unknown level is shown as Platform sent it.
  A connection that is not in the install tenant, or is deleted, answers 404 `NOT_FOUND`; an inactive connection lists its grants.
  The usernames and e-mail addresses are held in memory by the page's bloc only, never stored, never logged, and `PlatformGrant.toString` prints none of them.
- `DELETE /api/v1/connections/{id}/grants/{grantId}` revokes one grant and answers 204 with no body, which the app does not read.
  The last segment is the grant id from the list, never the subject that a `PUT` takes.
  It answers 404 `NOT_FOUND` for a grant another admin already revoked, a grant of another connection, and an unknown or deleted connection alike; the app reads only the code, so it says "Already removed" and lets the refresh that follows tell a revoked grant from a connection that is gone.
  It reads nothing from Keycloak, so it never answers `DIRECTORY_UNAVAILABLE`, and like every non-GET it is never sent twice.
- Each id is sent as one path segment encoded with `Uri.encodeComponent`.
  `MockInterceptor` answers every GET under `/v1/connections/<something>` from `assets/mock/GET_v1_connections_pathParams.json`, so a later GET on another path under that base needs its own mock naming.
- `/api/v1` is a public path of Platform's proxy, so it never answers with a redirect to `/login` (`src/shared/lib/public-paths.ts`); the client follows no redirect.

## Errors

Every error body is `{"error":{"code","message","fieldErrors"?}}` (`src/shared/lib/bearer/api-v1-response.ts`); a 5xx keeps its code with a generic message, and a 500 is always `INTERNAL_ERROR`.
A 400 `VALIDATION_FAILED` carries `fieldErrors`, keyed by zod paths joined with `.`, `""` for the root and `body` for a body that is not a JSON object (`src/shared/lib/bearer/api-v1-input.ts`).

Platform's `message`, and the messages of `fieldErrors`, are never logged, put into an exception text or shown: a message can name a user, such as a Keycloak user that is disabled.
`PlatformErrorEnvelope` keeps only the status, the code and the field keys, and a repository logs only the mapped code.

`platformError` (`lib/infrastructure/platform/platform_errors.dart`) checks the code first and the status second:

| Platform answer | `AppErrorCode` | `AppError` |
| --- | --- | --- |
| 401 `BEARER_INVALID` | `authInvalidAccessToken` | `AuthError` |
| 403 `ADMIN_ROLE_REQUIRED` | `platformAdminRoleRequired` | `AuthError` |
| 403 `LICENSE_ADMIN_SEATS` | `platformLicenseAdminSeats` | `AuthError` |
| 403 `LICENSE_USER_SEATS` | `platformLicenseUserSeats` | `AuthError` |
| 403 `LICENSE_EXPIRED` | `platformLicenseExpired` | `AuthError` |
| 403 `LICENSE_INVALID` | `platformLicenseInvalid` | `AuthError` |
| 404 `API_DISABLED` | `platformApiDisabled` | `NotFoundError` |
| 404 `NOT_FOUND` | `platformNotFound` | `NotFoundError` |
| 400 `VALIDATION_FAILED` | `platformValidationFailed` | `ValidationError` |
| 503 `IDENTITY_PROVIDER_UNAVAILABLE` | `platformIdentityProviderUnavailable` | `ServerError` |
| 503 `DIRECTORY_UNAVAILABLE` | `platformDirectoryUnavailable` | `ServerError` |
| 503 `KEYCLOAK_UNAVAILABLE`, 502 `KEYCLOAK_AUTH_ERROR`, 502 `KEYCLOAK_PERMISSION_ERROR`, 404 `KEYCLOAK_NOT_FOUND` | `platformKeycloakUnavailable` | `ServerError` |
| 403 `PLAN_FEATURE_REQUIRED` | `platformPlanFeatureRequired` | `AuthError` |
| 403 `PERMISSION_DENIED` | `platformPermissionDenied` | `AuthError` |
| 500 `INTERNAL_ERROR`, or any 5xx with another code or no envelope | `platformInternalError` | `ServerError` |
| Any other status with another code or no envelope | none | 400 `ValidationError`, 401 or 403 `AuthError`, 404 `NotFoundError`, else `UnknownError` |
| No status (transport failure) | as every other server (`transport_error_mapping.dart`) | as every other server |
| `FormatException` from a model | `platformUnreadableAnswer` | `ServerError` |
| `PlatformNotConfiguredException` | `platformNotConfigured` | `NotFoundError` |

`platformGrantWriteError`, for a grant `PUT` only, maps a 400 `VALIDATION_FAILED` refused on exactly one of `level`, `subject` or `expiresAt` to `platformGrantLevelRefused`, `platformGrantSubjectRefused` or `platformGrantExpiryRefused`, and everything else through `platformError`.
The grant rows stay out of `platformError`, because `GET /api/v1/audit` also has a `subject` filter whose refusal must not say that Keycloak does not know the user.

`KEYCLOAK_NOT_FOUND` comes from the directory reading a user's roles (`src/shared/lib/keycloak/directory.ts`), so it is an outage of the directory, not a missing item.
`PLAN_FEATURE_REQUIRED` is reachable on `GET /api/v1/audit`, since the plan is checked before any permission (`src/features/audit/lib/audit-read.ts`).
`PERMISSION_DENIED` cannot reach a bearer caller today, because every bearer caller holds `PLATFORM_ADMIN`; it is mapped so that a later Platform change does not show up unlabelled.

## Sign-in

A build with a Platform target shows two entries on the login page, "Sign in to Studio" and "Sign in to Platform"; a build without one shows the single "Sign in with SSO" button.
The Platform button's helper text says that the entry is for Platform admins and that the first Platform sign-in takes one admin seat of the license, because the first successful call of an account provisions its Platform user and takes the seat (libredb-platform `docs/api/v1.md`, `src/shared/lib/bearer/with-bearer.ts`).
There is no confirmation dialog, and the page remembers no last entry.

The Platform entry stores the Keycloak tokens with the session target `platform`, then calls `GET /api/v1/me` (`SignInUseCase`); only its 200 with an answer `PlatformIdentityModel` can read is a sign-in, and Studio's `GET /api/auth/me` is never called.
Platform checks a sign-in in this order (`with-bearer.ts`), and the login page shows the first refusal it meets:

1. 404 `API_DISABLED`, when the bearer API is off.
2. 401 `BEARER_INVALID` for a missing or malformed header, then 503 `IDENTITY_PROVIDER_UNAVAILABLE` when the issuer's keys cannot be read, then 401 `BEARER_INVALID` for a token that fails a check, such as one without Platform's audience.
3. 403 `ADMIN_ROLE_REQUIRED` for a valid token without the admin role, before any seat is taken.
4. Only on an account's first call: 403 `LICENSE_INVALID` or `LICENSE_EXPIRED`, then a Keycloak failure (503 `KEYCLOAK_UNAVAILABLE`, 502 `KEYCLOAK_AUTH_ERROR` or `KEYCLOAK_PERMISSION_ERROR`, 404 `KEYCLOAK_NOT_FOUND`), then 403 `LICENSE_ADMIN_SEATS` when every admin seat is in use.
5. 500 `INTERNAL_ERROR` for anything else.

A refusal clears the stored tokens and the session target and leaves the user on the login page with the sentence of its code ([oidc.md](oidc.md#roles) lists them); a 401 that reaches the gate shows `platform.account_refused`.
The gate starts no provider logout, so the Keycloak browser session stays and a sign-in through the Studio entry right after usually needs no password.
A refusal at the gate never opens the account refusal page, which covers only a signed-in Platform session.
The login page shows no `returnUrl` of a Studio route after a Platform sign-in, and no `/platform` one after a Studio sign-in; it opens the home of the signed-in target instead.
The Platform shell loads `PlatformIdentityCubit` itself when it opens, so a sign-in costs one more `GET /api/v1/me`, which takes no new seat because the account then already has its Platform user.
While Studio is unreachable, its status page still covers the login page, so the Platform entry is unreachable too.

## Session and refusals

- A 401 `BEARER_INVALID` starts one token refresh; a second 401 `BEARER_INVALID` for the request sent again after it ends the session as expired (`lib/infrastructure/platform/platform_session_policy.dart`).
- A 401 without Platform's envelope reaches the caller as an error and never ends the session.
- A 502 or 503 never ends the session, whatever its code.
- A 403 `ADMIN_ROLE_REQUIRED` or `LICENSE_ADMIN_SEATS` refuses the signed-in admin (`PlatformAccountRefusalCubit`); it is reported only under a signed-in Platform session, so a refusal during the sign-in stays on the login page.
- `LICENSE_EXPIRED`, `LICENSE_INVALID` and `LICENSE_USER_SEATS` are shown by the caller and never refuse the account, because a grant `PUT` can answer them and refusing the whole account over one grant would lock the admin out.

A deployment whose `libredb-mobile` access token lacks Platform's audience answers `BEARER_INVALID` to every call, so a Platform session there ends after its one refresh.

## The Platform shell

A Platform session lives in its own shell under `/platform` (`PlatformShell`), with the tabs Home and Connections and the settings opened from the profile sheet.
The router sends a Platform session away from every Studio route, and a Studio session away from every `/platform` route, to the home of its own target (`ApplicationRoutesConstants.belongsTo` and `homeFor`).
The Platform shell reads nothing of Studio and provides none of the Studio scopes, and it keeps no data of an account on the device, so Settings shows no "Remove my data".
While Platform refuses the admin, a refusal page covers the screens; Retry asks `GET /api/v1/me` again and uncovers them on a 200, and Logout signs out.
The Studio unreachable page does not cover a signed-in Platform session; it still covers the restore and the login page.
Switching mode is a sign-out followed by a sign-in through the other entry.

A tap on a connection opens its grants (`/platform/connections/<id>`), with the tapped connection handed over as go_router `extra`, since go_router logs every location and Platform has no route that reads one connection.
The location carries only the connection id; a location reached without that `extra`, such as a `returnUrl` after sign-in or a typed location, opens the connections list instead.
While a revoke runs every row's actions menu is disabled, because a second revoke would be dropped.

A Platform sign-out sends no request to Studio and writes no warn line about a missing Studio record, since Platform v1 has no logout route and there is no Studio session to record; it still wipes the session and starts the Keycloak end-session with the ID token hint.

## Where Platform mode works

Only Docker or VM installer installs with `mobile.enabled`, and Railway platform-dev, serve Platform mode today.
The Helm chart does not create the mobile client yet (libredb-platform `charts/libredb-platform/Chart.yaml`, the `mobile.enabled` change note).
