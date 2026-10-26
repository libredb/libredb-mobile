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
The release workflow passes both defines when the owner sets them as variables ([release.md](release.md)).
While `PLATFORM_API_URL` is unset, the store build stays Studio-only.

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
  A refresh that was already running when the answer arrived keeps that answered status on the row, and a refresh sent after the answer shows what Platform lists.
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
  A filter set while the search waits for its pause is sent together with that search, in one request; the search chip's delete and clear filters drop the waiting search.
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
| 500 `INTERNAL_ERROR`, or any 5xx with another code | `platformInternalError` | `ServerError` |
| Any 5xx without a code, which only the edge in front of a stopped Platform sends, since Platform codes every 5xx of its own | `platformUnreachable` | `ServerError` |
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
The refusal names the mode the user stays in: a 401 from the other target does not end the session, so it never asks the user to sign in, unlike the login page's text for a refused sign-in.
A switch to Studio that meets a 5xx without Studio's code, as the edge in front of a stopped Studio answers, a failed connection or a timeout says that Studio does not answer (`studio.unreachable`).
Studio's gate of a switch is sent once, past an open circuit, and counts toward no circuit, so a refused switch never holds back the next tap once Studio is back.
A switch to Platform that meets a 5xx without Platform's code, a failed connection or a timeout says that Platform does not answer (`platform.unreachable`), and Platform's gate of a switch is sent as a probe the same way.
A switch is no sign-out: it sends no Studio logout record, writes no warn line, starts no provider end-session, sends the app lock no event and removes no stored data.
A sign-out or an idle timeout while a switch runs ends the session and leaves no target stored.
Such a switch is dropped (`SessionTargetSwitchAbandoned`): its answer shows nothing, in the next session or anywhere else, and it writes one info line and no warn or error line.

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
A Platform screen that loaded and failed while covered, as on a restore while Platform is down, loads again once a check uncovers it: `PlatformShell` reloads a failed identity, which Home shows, and the connection list, the grants of a connection, the directory picker and the audit log reload a failed answer through `OnPlatformReachable` (`lib/shared/widgets/platform_unreachable_status.dart`), never by sending a write again.

A build without a Platform target keeps the Studio gate over the restore, the login page and a Studio session, and its single entry shows no notice.

## Where Platform mode works

Platform mode needs an install that creates the client `libredb-mobile` and turns on both bearer channels: a Docker or VM installer install with `mobile.enabled: true`, a Helm install of chart 1.3.1 or later with `mobile.enabled: true`, or Railway platform-dev.
Chart 1.3.0 and earlier do not create the client; chart 1.3.1 does, as the installer does (libredb-platform `charts/libredb-platform/values.yaml`, section `mobile`, and `docs/deploy/install-kubernetes.md`, "The mobile app"), and [Helm chart check](#helm-chart-check) records the check of it.
The audit log is empty unless a Studio governed by that Platform has run statements: Platform lists the query events such a Studio writes into its `bridge` schema, and nothing else.
The full-system check of 2026-10-26 ran Platform mode against installer 1.3.0 (Platform 1.3.0, Studio 1.1.0) with `mobile.enabled`, on a public certificate; see [Full-system check](#full-system-check).

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

## M11-P walkthrough

The end-to-end walkthrough of milestone M11-P (#271) was run on 2026-10-25 on Railway platform-dev, which ran Platform 1.3.0 and Studio 1.1.0 that day (the image digests the Railway CLI lists, matched to their GHCR tags), with Studio governed by that Platform at the default governance refresh.
Builds P, U, V and S were built from `main` at `1077f3c` with Flutter 3.47.7 as release APKs of `main_prod.dart` signed with the debug key and without `SENTRY_DSN`, with the defines the issue names; P, U and V had `SCREEN_CAPTURE_PROTECTION=false`, S the prod default.
The device was the test phone, a Samsung Galaxy M51 (SM-M515F) on Android 12, reached over wireless debugging.
Every Keycloak sign-in was typed on the phone by the orchestrator, as the dedicated test user with the client role `user`, or as the realm's admin account, which already held an admin seat from the M10-P walkthrough.
The walkthrough connection was Sample: Employees, on which the play-review account holds no grant and one other test user holds a read grant.
To save sign-ins, the grant of step 4 was given in the admin's build U session of step 1, and step 14 ran in the test user's Studio session restored from build V by installing P over it.

| Step | Result |
| --- | --- |
| 0. Baseline | Partly run: the web console was not read, so the license page's seats in use were not recorded; the app's grant lists served as the baseline of the grants |
| 1. Studio unreachable | Passed: a cold start of U shows both entries, not covered by the Studio unreachable page, the Studio entry disabled with "Studio does not answer" and Retry; "Sign in to Platform" as the admin opens the Platform shell with Home, Connections and Audit |
| 2. Switch refused | Passed: in the same session, "Switch to Studio" is refused with a snackbar and the app stays in the Platform shell, signed in; the message is the `network.cert_invalid` one, because the phone's network resolves `studio.invalid` to its router |
| 3. Platform unreachable | Passed: a cold start of V shows the Platform entry disabled with "Platform does not answer" and Retry, and "Sign in to Studio" as the test user lands in the Studio shell, listing Sample: Employees as read only |
| 4. Grant | Passed: the directory search finds the test user with "Takes a user seat", and read with no expiry saves and lists the grant, granted by the admin |
| 5. Seed audit events | Passed: the test user ran the passing `SELECT` and the misspelled statement on Sample: Employees; the app asked to confirm the misspelled one as a possible write on a read-only connection, and Studio answered it with a syntax error |
| 6. Disable | Passed: the confirmation says the connection closes for every Studio user within about 30 seconds, running queries are not stopped and its grants are kept; after Disable the badge reads Inactive, "Connection disabled" shows, and the grant list still shows both grants |
| 7. Gone in Studio | Passed: the test user's first Studio load, 111 seconds after the disable, showed no databases |
| 8. Enable | Passed: the confirmation says the grants can take user seats; Enable was not refused, the badge reads Active and "Connection enabled" shows; the test user's first Studio load, 100 seconds after the enable, lists Sample: Employees again; the connection was disabled for 4 minutes 26 seconds |
| 9. Audit tab | Passed: both events of step 5 are listed first, newest first, with the user, connection, type, status, duration and the redacted statement, since platform-dev captures statements as `redacted` |
| 10. Filters | Passed: status error leaves only the failed statement, type `SELECT` leaves the passing one and older selects, a one-day range from and to today keeps both, and the search text finds both, since the redacted statement keeps that text; the total is under one page, so no Load more showed and paging stays covered by #268's tests |
| 11. Event detail | Passed: the failed event shows its fields, error code 42601, the redacted statement with "Redacted by the connection's capture setting", and the error message as not recorded; "Only this user" and "Only this connection" set those filters on the list |
| 12. Screen capture | Passed for content: on S, a screenshot of the audit list and of the event detail is empty (0 bytes) and the window carries `FLAG_SECURE`; the recent-apps card was not black but showed a stale snapshot of the login page from earlier in the run, with no audit content |
| 13. Mode switch | Passed: the admin switched from Platform to Studio without a Keycloak form (an empty Studio list, since the admin holds no grant), a relaunch restored Studio, the switch back to Platform asked the seat confirmation, and a relaunch restored Platform |
| 14. Non-admin switch | Passed: the test user's "Switch to Platform" asked the seat confirmation and was then refused with "This account is not a Platform admin, so it stays in Studio."; the app stayed in the Studio shell, signed in, and a relaunch restored Studio |
| 15. Turkish | Passed: the disable confirmation, Connections, the Audit tab and list, the filter sheet, the event detail, the profile's switch entry and the login page with "Studio yanıt vermiyor" and "Platform yanıt vermiyor" read in Turkish; the language was reset by clearing the app's data at the end |
| 16. Logs | Passed: the app's logcat for the whole run holds no JWT, no `Bearer` value, no e-mail address at all, no `subjectEmail`, no statement or search text, no database error text and no Platform error message text |
| 17. Teardown | Passed except the seats: the test user's grant was revoked on the phone, the app's grant lists of all 10 connections show the test user holding no grant, Sample: Employees active with its one original grant, and the play-review account still holding its 4 read grants (Postgres Air, Lego, Titanic, Periodic Table); the license page was not read, so the seats in use were not compared with step 0; build P is installed, signed out, with the app lock off |

Notes:

- The reload latency itself (at most `GOVERNANCE_REFRESH_MS`) was not timed in steps 7 and 8: one phone holds one session and no desktop browser watched Studio web, so each check is the first load after a sign-in; it is Studio's behaviour, not the app's.
- `docs/security.md` says the recent-apps preview is black under `FLAG_SECURE`; on this Samsung phone the card keeps the last snapshot taken while the window was not secure.
- One Studio sign-out logged a `GET /connections/managed` answered 401 and "No refresh token available" right after the session was cleared, as in the M10-P walkthrough (#277).

## Full-system check

The full-system check of milestone M12-P (#304) was run on 2026-10-26 on the test phone against the Platform installer environment of [studio.md](studio.md) "Platform installer environment" (#303), whose Studio is governed by that Platform at the default governance refresh.
The install was `libredb-installer version` `release 1.3.0`, with `mobile.enabled: true` and `tls.mode: provided` on a Let's Encrypt certificate for `<platform host>`, `<studio host>` and `<auth host>`.
`libredb-installer images list` printed these digests:

| Image | Digest |
| --- | --- |
| Platform | `ghcr.io/libredb/libredb-platform@sha256:e53ca9b82e337bb995a575ac4082de3da092d33c098a020a13292584fbc49ea9` |
| Studio | `ghcr.io/libredb/libredb-studio@sha256:e91183def05f4c13703c77363ec51ad68bfa45b1b1d3b92dc53c331b67e53d2c` |
| Keycloak | `quay.io/keycloak/keycloak@sha256:79c623a22abacf3fe6c00a5fb30f5b7843d717b234033b80995891c06116d244` |
| PostgreSQL | `docker.io/library/postgres@sha256:74935e72241653ca55e0414067e6d8763aceb8a810eb51b452253ec3dcfc4336` |
| Edge | `docker.io/library/caddy@sha256:685ae3d7c34d9b5f8caeddc5d14051db7bbd88ff1f5a2fa0c16bd8ca328fb7af` |

Builds F, F-pin and F-badpin were built from `main` at `f056028` with Flutter 3.47.7 as release APKs of `main_prod.dart` signed with the debug key and without `SENTRY_DSN`, from defines files kept outside every repository and deleted after the check.
Each had the environment's `PROD_API_URL`, `OIDC_ISSUER` and `PLATFORM_API_URL`, `OIDC_CLIENT_ID=libredb-mobile`, `OIDC_PROMPT=omit` and `SCREEN_CAPTURE_PROTECTION=false`.
F-pin added `PLATFORM_CERT_PINS` with the pin of the key the Platform host served and a backup pin of a new key, and F-badpin two pins of new keys that match no key of the host.
`RELEASE_VARS='{}' tool/release/check_defines.sh` exited 0 on each of the three defines files.
The device was the test phone, a Samsung Galaxy M51 (SM-M515F) on Android 12, reached over wireless debugging.
The owner ruled the environment a demo environment, so an agent typed every Keycloak sign-in on the phone, as the test user `lab-user` with the client role `user` and no grant, or as the realm's admin account `libredb-admin`.
The check connection was `Lab sample PostgreSQL`, the environment's only connection, with a write credential, over the sample data of [studio.md](studio.md) "Sample data".
The install's `queryLog.statementCapture` is `redacted`, the value the event page shows as "Statement capture".
The license is a FREE license with 1 admin seat and 3 user seats, and the tenant's plan carries the audit log.

| Step | Result |
| --- | --- |
| 1. Platform down at the login page | Passed: a cold start shows both entries; with Platform stopped, the first liveness check runs when the login page first needs Platform, so the app was started again to make it fail; the Platform entry is then disabled with "Platform does not answer." and Retry, a Retry keeps it so, and the test user's Studio sign-in works and was signed out; with Platform started again, Retry enables the entry |
| 2. Admin sign-in | Passed: the Platform home shows the tenant name "LibreDB Mobile Lab", the slug "default" and the admin's name, and the navigation shows Home, Connections and Audit; the license page read 1 of 1 admin seats and 0 of 3 user seats before and after, since the admin account had already taken its seat in the web console during the install |
| 3. Connections | Passed: the check connection is listed as active; the filter narrows by name, shows "No connection matches the filter" for a name that matches none, and pull to refresh reloads |
| 4. Studio before the grant | Passed: the test user's Studio list shows no connection; observed in step 1's Studio session, which ran in the same state, without a grant, so the sign-in was not repeated |
| 5. Grant and statements | Passed: the directory search finds the test user with "Takes a user seat", and read with an expiry the next day saves, granted by the admin; the test user's Studio list shows the check connection with the read-only marker after a pull, and `SELECT 1` and a `SELECT` on `customers` return 1 and 3 rows |
| 6. Audit | Passed: after a pull the Audit tab lists both statements of step 5 first, by the test user on the check connection, with the redacted statement; the event page shows "Statement capture" "Redacted" and the statement with its literals replaced; "Only this user" and "Only this connection" each add a chip, and status Success in the filter sheet keeps both events; every event of the install was the test user's on the check connection, so the user and connection filters had nothing else to remove |
| 7. Governance loop | Passed: the change to write saves; the test user's Studio list then shows the check connection without the read-only marker; the disable confirmation says it closes for every Studio user within about 30 seconds, the admin's list shows it Inactive with "Connection disabled", and the test user's first load, 60 seconds after the disable, shows no connection; after Enable the badge reads Active with "Connection enabled", and the test user's first load after it lists the check connection again with write, no read-only marker |
| 8. Mode switch | Passed: in the admin's Platform session "Switch to Studio" opens the Studio home with no confirmation, no sign-out and no Keycloak form; "Switch to Platform" asks "Switch to Platform?", and Switch opens the Platform home with no Keycloak form |
| 9. Studio down | Passed with a finding: with Studio stopped, Connections and Audit of the Platform session load after a pull; "Switch to Studio" is refused with the snackbar "Something went wrong" (#338) and the app stays in the Platform shell, signed in, as a refused switch must ("Session and refusals"), so the Studio unreachable page cannot cover a Studio session reached that way; after a refused switch the circuit breaker of `GET /auth/me` stayed open for its 30 second cooldown, and the switch worked once Studio answered and the cooldown ended; a Studio session started again with Studio stopped is covered by "Can't reach Studio", and with Studio started again its Retry uncovers the Studio screens, though the connection list and the profile's identity keep the failure they met while covered until their own Refresh and Retry (#339); the switch back to Platform asks for confirmation and works |
| 10. Pins | Passed with a finding: F-pin over F restores the Platform session and loads Connections, the grant list and Audit; F-badpin over it covers the session with "Can't reach Platform" and "The connection could not be verified as secure, so it was blocked.", and the log shows `CertificatePinningAdapter` "Pin mismatch: rejecting connection" for the Platform host on `GET /health/live` and `GET /v1/me`, mapped to `network.cert_invalid`; the unreachable page offers no sign-out, so the app's data was cleared to reach the login page, where the Platform entry is disabled with "Platform does not answer." and Studio sign-in works; F was installed over it again |
| 11. Revoke and logs | Passed: the revoke dialog names the test user, write access and the check connection; after Remove the test user's Studio list shows no connection after a pull; the admin signed out of Platform; the logcat capture of the whole run, 111150 lines, holds no JWT, no `Bearer` value, no password, no e-mail address (the only matches were object hashes of the keyboard service), no `subjectEmail`, no statement text, no database error text and no Platform error message text, and was deleted |
| 12. Teardown | Passed for the app: the test user holds no grant on any connection, the check connection is active, the license page reads 1 of 1 admin seats and 0 of 3 user seats, the app is signed out, build F is installed and the phone is on its home screen; the environment stays up, because #196 still runs in it, and its teardown moves to #196 |

Notes:

- Step 9 found two defects, filed as #338 and #339: a switch to Studio that Studio answers with a 5xx without a code says only "Something went wrong" instead of naming Studio as not answering (#338), and the screens behind a Studio unreachable page keep the failure they met while covered after its Retry uncovers them (#339).
- The issue expected the Studio unreachable page after "Switch to Studio" with Studio stopped; the M11-P ruling that a refused switch keeps the current session makes that unreachable, so step 9 covered the Studio gate through a restored Studio session instead.
- Neither unreachable page offers a sign-out, by design, so step 10 reached the login page by clearing the app's data; that keeps the Keycloak session in the browser, so the Studio sign-in after it showed no Keycloak form.
- A cold start while Platform answers runs the login page's first liveness check at once, so a Platform stopped later shows the notice only after a new start, a Retry, a return online or a return after more than 5 minutes in the background.

## Helm chart check

The Helm check of #308 was run on 2026-10-26 from the development machine on a kind cluster of its own, with no phone.
The chart was `libredb-platform` 1.3.1 from the chart repository `https://libredb.org/libredb-platform/`, archive sha256 `ea42e04ff1dd0219f337befecc0bd7e4d67b56f936e230920819bcfe3dc70104`, which pins Platform 1.3.0, Studio 1.1.0 and Keycloak 26.8.1 at the digests of [Full-system check](#full-system-check).
It was installed with the chart's own kind values (libredb-platform `charts/libredb-platform/tests/e2e/values-kind.yaml`, hosts under `.libredb.test`, a managed PostgreSQL and Keycloak, the internal CA), `mobile.enabled=true` and a temporary FREE license for `platform.libredb.test`, kept outside every repository and deleted after the check.
The cluster ran Kubernetes 1.37.0 on kind 0.33.0 with Traefik 41.7.1, in a namespace that enforces the restricted Pod Security Standard.

| Check | Result |
| --- | --- |
| Install | Passed: every pod ran and every job completed in 170 seconds |
| Bearer settings | Passed: the running Platform has `PLATFORM_API_AUDIENCE=libredb-platform-api` and `PLATFORM_API_CLIENT_IDS=libredb-mobile`, and the running Studio `OIDC_BEARER_AUDIENCE=libredb-studio-api` and `OIDC_BEARER_CLIENT_IDS=libredb-mobile` |
| Client `libredb-mobile` | Passed: read through Keycloak's Admin API, it is public, with the standard flow only, PKCE S256, no direct access grants, no implicit flow and no service account; its redirect and post-logout URIs are `org.libredb.mobile:/oauth2redirect`; its default client scopes are `basic`, `profile`, `email` and `libredb-roles` besides the realm's (`acr`, `roles`, `web-origins`); its two `oidc-audience-mapper` mappers add `libredb-studio-api` and `libredb-platform-api` to the access token and not to the ID token, as libredb-platform `installer/README.md` describes the client |
| Sign-in | Passed: the authorization code flow with PKCE S256 through `libredb-mobile`, with `scope` `openid profile email offline_access` (the app's default `openid profile email` plus `offline_access`), as the realm's first admin `libredb-admin`, ended in a redirect to `org.libredb.mobile:/oauth2redirect` with the request's `state`, and the code exchange without a client secret answered 200 |
| Token | Passed: the access token has `typ` `Bearer`, the issuer `https://auth.libredb.test/realms/libredb`, `azp` `libredb-mobile`, `libredb_roles` `admin`, and an `aud` that holds `libredb-studio-api` and `libredb-platform-api` (besides `account` and `libredb`); a refresh with the offline refresh token answered 200 with the same audiences and `azp` |
| Platform mode | Passed: `GET /api/v1/me` with the access token answered 200 with the roles `PLATFORM_ADMIN` |
| Studio mode | Passed: `GET /api/auth/me` with the same access token answered 200 with the role `admin` |
| Password grant | Passed: refused with 400 `unauthorized_client` |
| Teardown | Passed: the cluster was deleted (`kind get clusters` lists none), and the license, the token and the passwords were deleted from the machine |

Notes:

- The phone part of #304 (steps 2, 3, 5, 6 and 7) was not run, because the `.libredb.test` names resolve only inside the cluster and on the development machine, and the internal CA is not one the phone trusts; so the app itself, the browser sign-in on a device and the Platform and Studio screens were not checked on a Helm install.
- The token check used a script that sends the requests the app sends, not the app, and trusted the install's internal CA.
- The realm's first admin starts with the required actions `UPDATE_PASSWORD` and `CONFIGURE_TOTP`, as an installer install does; for this throwaway cluster the check removed `CONFIGURE_TOTP` through the Admin API and set a new password, and Keycloak then asked for the first name, last name and e-mail the account lacked, so a first sign-in from the app on a new Helm install meets those Keycloak pages in the browser before the app gets its token.
