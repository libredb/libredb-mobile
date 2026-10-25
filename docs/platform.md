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
The release workflow does not pass either define until M12-P, so the store build stays Studio-only ([release.md](release.md)).

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
| `GET /api/v1/directory/users?q=&page=` | `{users: [{id, username, email, firstName, lastName, enabled, studioRole, needsSeat}], page, total}` | `IPlatformDirectoryRepository.search`, `DirectoryPageJson` |
| `PUT /api/v1/connections/{id}/grants/{subject}` | `{id}` | `PlatformGrantRepository.put`, `GrantPutBody`, `GrantPutAnswerJson` |
| `PATCH /api/v1/connections/{id}`, body `{active}` | one connection: `{id, name, engine, status, hasWriteCredential}` | `IPlatformConnectionRepository.setActive`, `PlatformConnectionsModel.readOne` |
| `GET /api/v1/audit?subject=&connectionId=&source=&statementType=&status=&from=&to=&search=&limit=&offset=` | `{events: [{eventId, startedAt, finishedAt, subject, username, sessionRole, connectionId, connectionKnown, connectionName, engine, accessLevel, source, statementType, explain, statementCapture, statement, statementTruncated, rowCount, durationMs, status, errorCode, errorMessage, transactionOutcome}], total}` | `IPlatformAuditRepository.list`, `AuditPageJson` |
| `GET /api/health/live` | `{status: "live"}` | `IPlatformStatusRepository.liveness`, `PlatformStatusJson` |

- `GET /api/v1/me` answers the caller's Platform user (libredb-platform `src/app/api/v1/me/route.ts`).
  `roles` is always `["PLATFORM_ADMIN"]` and `permissions` every permission (`src/shared/lib/bearer/with-bearer.ts`); `name` is nullable, `email` and the tenant's fields are not (`prisma/schema.prisma`).
  The app keeps roles and permissions as opaque strings, holds the identity in memory only (`PlatformIdentityCubit`) and never stores it.
  `id` is Platform's user id, not the identity provider's `sub`, so it never keys a store.
- The first call of an account provisions its Platform user and takes an admin seat, so the license can refuse it (`docs/api/v1.md`).
- `GET /api/v1/connections` answers every connection of the install tenant, active and inactive, newest first, with no host, credential or sealed value (libredb-platform `src/features/connections/lib/grant-service.ts`).
  All five fields are always present; `status` is `active` or `inactive` today, and the app keeps `engine` and `status` as opaque strings, an unknown value included, and keeps Platform's order.
  The connections tab (`lib/features/platform_connections/`) shows the list; no connection is created, edited or deleted on the phone.
- `PATCH /api/v1/connections/{id}` disables an active connection or enables an inactive one from the row's menu on the connections tab (libredb-platform `docs/api/v1.md`, `src/features/connections/lib/connection-service.ts`, Platform 1.3.0).
  The body is exactly `{"active": true}` or `{"active": false}`; the app never sends a name, a definition or a credential.
  Each action first shows a confirmation: a disable closes the connection for every Studio user within about 30 seconds (Studio's governance reload), does not stop a query already running and keeps its grants; an enable opens it again for every grant holder, and those grants can take user seats of the license.
  Platform answers 200 with the connection as it now holds it, also when it already had the asked value (a no-op that records no admin action), and the row shows that answered status in place, without a list reload, keeping the search.
  A 404 `NOT_FOUND` says the connection no longer exists and refreshes the list; a 403 `LICENSE_USER_SEATS` (on enable only) opens a dialog worded for the connection's grants and never the account refusal page; a 400, `LICENSE_EXPIRED`, `LICENSE_INVALID`, a 5xx and a transport failure each show their message, and the row keeps its status.
  The request is never retried, and a second confirm while one is out is dropped; every row's menu is disabled until the answer arrives.
  The log carries the id and the answered status, never the connection name.
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

## Directory search and grant editor

The grant editor (`lib/features/platform_grants/presentation/pages/platform_grant_editor_page.dart`, route `/platform/connections/:id/grant`) picks a user from Platform's directory, then sets the level and the expiry; opened on a grant from the grants list, it shows the form at once.
The route needs `GrantEditorArgs` as `extra`, built by the grants page from the connection and its loaded grants; a location without it opens the grants page of that connection.

- `GET /api/v1/directory/users` searches Keycloak's users anywhere in the username, first name, last name or e-mail address, 20 per page, `page` from 1 to 100000 (libredb-platform `src/features/connections/lib/grant.schema.ts`).
  `q` is trimmed and at most 255 UTF-16 code units; the app never sends a longer one and shows a hint instead, and sends no `q` for an empty search.
  `studioRole` is kept as an opaque nullable string, null meaning the user cannot sign in to Studio; `needsSeat` says a grant on an active connection would take a user seat.
  `total` comes from a separate Keycloak count, so paging stops when `page * 20` reaches it, when a page holds fewer than 20 users, or at page 100000, and a page adds only users not already listed.
- Each search costs Platform up to 22 Keycloak Admin calls, which cancelling on the phone does not stop, so `DirectoryPickerBloc` sends few: one request when the picker opens, then a trimmed query once typing pauses for 400 ms, never a query already in flight or on screen, and the same query again only on Retry.
  A newer query drops the answer to an older one, or to a page of it.
- The directory refuses with 400 `VALIDATION_FAILED` on `q` or `page`, 503 `DIRECTORY_UNAVAILABLE`, 502 `KEYCLOAK_AUTH_ERROR` or `KEYCLOAK_PERMISSION_ERROR`, 404 `KEYCLOAK_NOT_FOUND` for a user deleted during the search, and 500 `INTERNAL_ERROR`.
- `PUT /api/v1/connections/{id}/grants/{subject}` creates the subject's grant or replaces it, and answers `{id}`; sending it twice leaves the same grant.
  The subject is the directory `id`, one path segment encoded with `Uri.encodeComponent`, such as `f%3Aldap-1%3Abob` for an LDAP user without import.
  The body is exactly `{level, expiresAt}`: `read` or `write`, and a UTC ISO 8601 time or JSON `null` for no expiry.
- Platform refuses the `PUT` in this order: 400 on the body or a field, 404 `NOT_FOUND` for the connection, 400 on `level` (write without a write credential), 503 or 502 from the user read, 400 on `subject` (unknown or disabled user), 400 on `expiresAt` (not in the future by Platform's clock), and 403 `LICENSE_INVALID`, `LICENSE_EXPIRED` or `LICENSE_USER_SEATS` only on an active connection for a user without a seat.
  `platformGrantWriteError` gives each field refusal its own code, and the form shows it under that field or the user line; a license refusal shows a banner and keeps the form, and never opens the account refusal page.
- `GrantEditorBloc` checks the level and that the expiry is after now before sending, drops a save while one runs, and never sends the `PUT` again on its own: after a 503 or 502 only Retry sends the `PUT` again, checked and built from the values the form shows then.
  A timeout, a lost connection, a 500 or an unreadable 200 may have saved the grant, so the grants list is read again.
- The search text, the users found, the subject and the grant's values are held in memory only, never stored, and never logged; the logs carry page numbers, counts and codes.
  `MockInterceptor` answers the directory from `assets/mock/GET_v1_directory_users_queryParams.json` for every query and page, and the `PUT` from `assets/mock/PUT_v1_connections_pathParams.json`.

## Audit log

`IPlatformAuditRepository.list` (`lib/features/platform_audit/`) reads the governed query events of the install, the statements that a Studio governed by Platform ran, refused or cancelled, through `GET /api/v1/audit` (libredb-platform `src/features/audit/lib/audit-read.ts`, `src/shared/lib/bridge/query-events.ts`).

- `AuditFilter` holds the optional filters under Platform's names: `subject` (the Keycloak `sub`, at most 512 characters) and `connectionId` (at most 64), matched exactly; `source` (`^[a-z][a-z-]{0,31}$`, an open vocabulary); `statementType` (`SELECT`, `INSERT`, `UPDATE`, `DELETE`, `DDL`, `OTHER`); `status` (`success`, `error`, `cancelled`, `refused`); `from` and `to`, inclusive bounds on `startedAt`; and `search`, matched literally in the statement ignoring case.
  Every value is trimmed and an empty one is unset, since Platform ignores an empty filter; `search` is cut to its first 200 UTF-16 code units without splitting a surrogate pair.
  `from` and `to` are sent in UTC with `Z`, and `limit` (1 to 200, 50 by default) and `offset` are always sent.
- The answer is `{events, total}`, newest first by `startedAt`, then `eventId`; `total` counts every event the filters select, and `AuditPage.hasMore` is true while `offset` plus the events on the page is below it.
  Offset paging over a newest-first list repeats an event when a new one arrives between two pages, so a screen that appends a page drops an event whose `eventId` it already shows.
- `AuditPageJson` throws a `FormatException` naming the field for a missing `events` list or integer `total`, and for an event without its string `eventId`, `subject`, `connectionId`, `connectionName`, `source`, `statementType`, `status` and `statementCapture`, an ISO time `startedAt`, a bool `statementTruncated` or an integer `durationMs`.
  Every other field reads as null when it is missing or of another type, and the vocabularies are kept as opaque strings, an unknown value verbatim.
  An event whose connection Platform no longer knows has `connectionKnown: false` and the `connectionName` `unknown connection`.
- Platform checks the plan first, 403 `PLAN_FEATURE_REQUIRED` (`platform.plan_feature_required`), then the permission, 403 `PERMISSION_DENIED` (`platform.permission_denied`), then the filters, 400 `VALIDATION_FAILED` (`platform.validation_failed`) whose field keys name the refused filters.
  Neither 403 is reachable through the bearer API of Platform 1.3.0: the install tenant is on the `ENTERPRISE` plan and every bearer caller is a Platform admin with every permission; the app still maps both.
- The events are held in memory only, never stored, and never cached, since every `/v1/` path is networkOnly.
  No filter value, statement, error text, subject, username or connection name is logged: the repository logs counts, the offset and the names of the set filters, `AuditEvent` and `AuditFilter` print no such value, and the request line masks every query value of a `/v1/` request.
  `MockInterceptor` answers every filter and offset from `assets/mock/GET_v1_audit_queryParams.json`.

The Audit tab (`/platform/audit`, `AuditLogPage`) shows the events newest first: the time, relative within a day, the username or the start of the Keycloak id, the connection name or a localized marker for an unknown connection, the statement type, the status (an unknown one verbatim), the duration, the row count, and the first line of a captured statement or "Statement not captured".

- `AuditLogBloc` reads the first page on a filter change, a pull or a retry, replacing a read still running; the statement search is sent once the typing pauses for 400 ms, trimmed, and never when it equals the current search.
- Load more reads from the end of the rows Platform answered so far and shows while Platform's paging rule says another page exists; it is dropped while one runs, its answer is dropped after a refresh or a filter change, and an event already listed is not listed again.
- A failed refresh or Load more shows a banner above the list it kept, an empty list included; `PLAN_FEATURE_REQUIRED` and `PERMISSION_DENIED` replace any list with their own page, without a filter or a retry.
- The filter sheet sets status, statement type and source as single choices with Any, from and to as local days sent in UTC (from at the start of its day, to at its last millisecond, since `to` is inclusive), and the statement text, refused past 200 UTF-16 code units as Platform counts them; every set filter shows as a removable chip.
- The event page (`/platform/audit/event`, `AuditEventPage`) lists every field of the event the list holds, a null one as not recorded, with the statement in a selectable monospace block; "Only this user" and "Only this connection" set `subject` or `connectionId` on the list and return to it.
- The event reaches the page as go_router `extra`, `AuditEventArgs`, whose text names only the event id and status; the location carries no value, and a location without that `extra` opens the list.
- The list rows, while the list is not empty, and the event's statement and error message are kept out of screenshots while on screen; leaving the tab disposes the bloc and its filters.

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
Each entry says when its own server does not answer ([Liveness and the two gates](#liveness-and-the-two-gates)), so a Studio outage never blocks the Platform sign-in.

## Session and refusals

- A 401 `BEARER_INVALID` starts one token refresh; a second 401 `BEARER_INVALID` for the request sent again after it ends the session as expired (`lib/infrastructure/platform/platform_session_policy.dart`).
- A 401 without Platform's envelope reaches the caller as an error and never ends the session.
- A 502 or 503 never ends the session, whatever its code.
- A 403 `ADMIN_ROLE_REQUIRED` or `LICENSE_ADMIN_SEATS` refuses the signed-in admin (`PlatformAccountRefusalCubit`); it is reported only under a signed-in Platform session, so a refusal during the sign-in stays on the login page.
- `LICENSE_EXPIRED`, `LICENSE_INVALID` and `LICENSE_USER_SEATS` are shown by the caller and never refuse the account, because a grant `PUT` can answer them and refusing the whole account over one grant would lock the admin out.
- The refusal of a refreshed token is scoped to the session's target, so a mode switch cannot sign the user out: Platform's second 401 `BEARER_INVALID` ends only a Platform session, and Studio's second 401 `AUTH_REQUIRED` ends only a Studio session (`onSessionRefused` in `lib/app/di/app_scope.dart`).
- A token refresh the identity provider refuses ends the session whatever its target, because that refresh token is dead for both servers (`onSessionExpired`).
- Studio's account refusals (`BEARER_NO_ROLE`, `BEARER_NO_IDENTITY`) are reported only under a signed-in Studio session, as Platform's are only under a Platform session.

A deployment whose `libredb-mobile` access token lacks Platform's audience answers `BEARER_INVALID` to every call, so a Platform session there ends after its one refresh.

## The Platform shell

A Platform session lives in its own shell under `/platform` (`PlatformShell`), with the tabs Home, Connections and Audit and the settings opened from the profile sheet.
The router sends a Platform session away from every Studio route, and a Studio session away from every `/platform` route, to the home of its own target (`ApplicationRoutesConstants.belongsTo` and `homeFor`).
The Platform shell reads nothing of Studio and provides none of the Studio scopes, and it keeps no data of an account on the device, so Settings shows no "Remove my data".
While Platform refuses the admin, a refusal page covers the screens; Retry asks `GET /api/v1/me` again and uncovers them on a 200, and Logout signs out.
The Studio unreachable page does not cover a signed-in Platform session, and the Platform unreachable page covers it while Platform does not answer.
In a build with a Platform target, the profile sheet switches the live session to the other mode in place: "Switch to Platform" in a Studio session, "Switch to Studio" in a Platform session.
The switch asks only the other target's gate with the live access token, Platform's `GET /api/v1/me` or Studio's `GET /api/auth/me`, because one access token carries both audiences, so it needs no provider sign-in.
A switch to Platform first asks for confirmation, because Platform's first answer to an account takes an admin seat of the license; a switch to Studio asks nothing.
Either switch first asks once about the unsaved changes of any open form (`UnsavedChangesRegistry.confirmLeavingAll`).
Only a 200 switches: the stored session target is rewritten alone (`IAuthSessionRepository.persistTarget`), the new mode's identity is filled from the gate's answer, the in-memory state of the mode left is cleared, and the router opens the new mode's home (`SessionTargetSwitchBloc`, `AppSessionListeners`).
A refusal keeps the session, its target, its pages and its cubits, and a snackbar says why, such as an account that is not a Platform admin or a license without a free admin seat.
A switch is no sign-out: it sends no Studio logout record, writes no warn line, starts no provider end-session, sends the app lock no event and removes no stored data.
A sign-out or an idle timeout while a switch runs ends the session and leaves no target stored.

A tap on a connection opens its grants (`/platform/connections/<id>`), with the tapped connection handed over as go_router `extra`, since go_router logs every location and Platform has no route that reads one connection.
The location carries only the connection id; a location reached without that `extra`, such as a `returnUrl` after sign-in or a typed location, opens the connections list instead.
While a revoke runs every row's actions menu is disabled, because a second revoke would be dropped.

A Platform sign-out sends no request to Studio and writes no warn line about a missing Studio record, since Platform v1 has no logout route and there is no Studio session to record; it still wipes the session and starts the Keycloak end-session with the ID token hint.

## Liveness and the two gates

`GET /api/health/live` answers 200 `{"status":"live"}` without any I/O (libredb-platform `src/app/api/health/live/route.ts`).
It needs no session or bearer, since every `/api/health` path is public in both deployment modes (`src/shared/lib/public-paths.ts`) and is served before the session is read (`src/proxy.ts`).
It is outside `/api/v1`, so it never answers `API_DISABLED`, and it is not in `docs/api/v1.md`.

`PlatformStatusRepository` (`lib/features/platform_status/`) sends it as `GET /health/live` relative to `PLATFORM_API_URL`, without a bearer (`publicEndpoints`), never from the cache (`CacheInterceptor` makes it networkOnly), with a 10 second timeout and past the client's retries and circuit breaker, so one check sends one request.
Only `{"status":"live"}` is an answer; anything else fails with `platform.unreadable_answer`.

`PlatformStatusBloc` asks nothing on its own at first.
In a build with a Platform target, the app layer (`AppStatusGate`) sends its first check once, when the login page or a Platform session first needs Platform; it checks again on a Retry, when the device comes back online while Platform is unreachable, and when the app comes back after more than 5 minutes in the background.
A build without a Platform target never sends `GET /api/health/live`.

The gates, in a build with a Platform target:

| Session state | Studio unreachable page | Platform unreachable page |
| --- | --- | --- |
| Restore (`SessionUnknown`) | No | No |
| Login page (`SessionUnauthenticated`) | No | No |
| Studio session | Yes, while Studio does not answer | No |
| Platform session | No | Yes, while Platform does not answer |

The restore calls neither server, so neither gate covers it.
On the login page, an entry whose server does not answer stays visible and disabled, with "Studio does not answer" or "Platform does not answer" under its helper text and a Retry that asks only that server again; the other entry is unaffected.
Studio's governance outage does not disable the Studio entry.
Both gates stay in the tree in every state and only their pass-through flags change, so the open pages keep their state across an outage, a recovery and a session change.

A build without a Platform target keeps the Studio gate over the restore, the login page and a Studio session, and its single entry shows no notice.

## Where Platform mode works

Only Docker or VM installer installs with `mobile.enabled`, and Railway platform-dev, serve Platform mode today.
The Helm chart does not create the mobile client yet (libredb-platform `charts/libredb-platform/Chart.yaml`, the `mobile.enabled` change note).
The audit log is empty unless a Studio governed by that Platform has run statements: Platform lists the query events such a Studio writes into its `bridge` schema, and nothing else.

## M10-P walkthrough

The end-to-end walkthrough of milestone M10-P (#251) was run on 2026-10-25 on Railway platform-dev, which ran Platform 1.3.0 and Studio 1.1.0 that day (the image digests the Railway CLI lists, matched to their GHCR tags).
Build P was built from `main` at `3777948`, and build A from `053ef66`, both with Flutter 3.47.7 as release APKs of `main_prod.dart` signed with the debug key and without `SENTRY_DSN`.
Builds N and U came from the commit of P, with the defines the issue names; every build had `OIDC_PROMPT=omit` and `SCREEN_CAPTURE_PROTECTION=false`.
The device was the test phone, a Samsung Galaxy M51 (SM-M515F) on Android 12, reached over wireless debugging.
The owner typed every Keycloak sign-in on the phone, as a dedicated test user with the client role `user` and no grant, or as the realm's admin account.
The web console readings of steps 1, 4, 6, 7, 8 and 11 were replaced by the app's own Platform answers, and the owner confirmed the test user's grants once at teardown (orchestrator ruling on #251).

| Step | Result |
| --- | --- |
| 1. Upgrade in place | Passed: the test user signed in on A, and after `install -r` of P the stored session restored into the Studio shell with no login page; sign-out returned to the login page |
| 2. Login page | Passed: a cold start shows "Sign in to Studio" and "Sign in to Platform" with equal weight, the Platform helper text says it is for Platform admins and that the first sign-in takes an admin seat, no dialog opens, and the browser does not open on its own |
| 3. Non-admin refusal | Passed: Platform answered `GET /api/v1/me` with 403 `ADMIN_ROLE_REQUIRED`, so the mobile access token carries Platform's audience; the login page showed the `platform.admin_role_required` message, a relaunch showed the login page, and "Sign in to Studio" then landed in the Studio shell without a Keycloak form |
| 4. Admin sign-in | Passed: the Platform home shows the tenant name and slug and the admin's name, the navigation shows only Home and Connections, and the profile sheet labels the mode "Platform admin"; see step 16 for the admin seats |
| 5. Connections | Passed: nine active Postgres sample connections, none with the "Read grants only" chip, so each has a write credential; the filter narrows by name and pull to refresh reloads |
| 6. Grants | Passed: Sample: Netflix, on which the test user held no grant, lists its one grant with username, level, expiry and granted by |
| 7. Add a grant | Passed: the directory search for part of the username shows one row with "Takes a user seat"; a past expiry is refused with "Choose a time in the future, or no expiry" before anything is sent; read with an expiry the next day saves and the grant list shows it, granted by the admin |
| 8. Change, lock | Partly run: the change to write saved and the list shows write; platform-dev has no connection without a write credential, so the disabled write option stays covered by #250's widget test; the app lock part was skipped by the orchestrator, since the phone has no screen lock and Settings keeps the app lock off with "Set a screen lock on this device to turn this on" |
| 9. Studio cross-check | Passed: the test user's Studio list shows Sample: Netflix after a pull, without the read-only chip, while the grant was write |
| 10. Unreachable, not configured | Passed: with the Platform session stored, U restored into the Platform shell and loaded the connections and the grant list; P over U restored the shell again; N showed only the Studio entry with the `platform.not_configured` message, and a relaunch showed the login page without it; P over N signed in through Platform again |
| 11. Revoke | Passed: the dialog names the test user, write access and Sample: Netflix, the row is gone after Remove, and the test user's Studio list no longer shows the connection after a pull |
| 12. Platform sign-out | Passed: the sign-out returned to the login page and the app's log has no `logout: Studio has no record of this sign-out` line and no warn line for it; the next sign-in, the admin's through Studio, showed the Keycloak form and landed in the Studio shell |
| 13. Idle timeout | Passed: the Platform session signed out to the login page 15 minutes after the last touch, with `endSession(idleTimeout)` in the log |
| 14. Turkish | Passed: with the language switched to Turkish inside the Platform session before step 13's wait, the login page entries and helper text, the Platform home and the connection list read in Turkish; the language was switched back afterwards |
| 15. Logs | Passed: the app's logcat for the whole run holds no JWT, no `Bearer` value, no e-mail address at all, no `subjectEmail` and no Platform error message text |
| 16. Teardown | Passed: the owner confirmed that the test user cannot sign in to Platform and holds no grant on any connection, and the app's grant lists show the play-review account still holding its 4 read grants (Postgres Air, Lego, Titanic, Periodic Table); the license page's seats in use were not read, so the admin seat comparison of step 4 is open; on the phone the app lock stayed off, the app is signed out and build P is installed |

Notes:

- The admin account had not used Platform before this run, so its first Platform call may have taken an admin seat; the license page was not read before or after the run.
- The idle timeout ends the app session but keeps the Keycloak session, so with `OIDC_PROMPT=omit` the Platform sign-in after it showed no Keycloak form.
- The phone's network resolves every name, `studio.invalid` included, to its router, so build U met an untrusted certificate rather than a failed lookup, and Studio's liveness logged `network.cert_invalid`.
- Two of the four Studio sign-outs logged a `GET /connections/managed` answered 401 and "No refresh token available" right after the session was cleared; the login page showed no message.
