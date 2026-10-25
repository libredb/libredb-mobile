# Security

This page describes the protections inside the app: how it keeps a prod build on https, how it stores tokens and statement text, how the user removes what it keeps, how it checks the server's certificate, how it hides sensitive screens, how it masks sensitive result values, how it copies them, how it asks before a statement that may write runs, and when it signs an idle user out.
What the app sends to Studio and what it never holds is in [architecture.md](architecture.md#security), and what leaves the device in a crash report is in [crash-reporting.md](crash-reporting.md).

## Encryption in transit

A prod build (`lib/main/main_prod.dart`) talks to Studio, Keycloak, Sentry and, in Platform mode, LibreDB Platform over https only, which the privacy policy and the Play Data safety answer "data is encrypted in transit" rely on.
`AppConfig.fromEnvironment` (`lib/infrastructure/config/environment.dart`) stops the start with a `ProdHttpsConfigError` when `PROD_API_URL`, `OIDC_ISSUER`, a set `SENTRY_DSN` or a set `PLATFORM_API_URL` is not an absolute https URL with a host, a loopback http issuer included; there is no fallback and no downgrade.
The rule is one pattern, `AppConfig.httpsUrlPattern`: the scheme in any case, optional user info, a host name or an IPv6 literal, an optional port, then the end or a path, query or fragment.
`OIDC_ISSUER` is trimmed first, as the sign-in reads it, while `PROD_API_URL`, `SENTRY_DSN` and `PLATFORM_API_URL` are refused with surrounding whitespace, since they are used as given.
The error names the define and never its value, because the DSN carries the project's key.
On Android the host app starts the native Sentry SDK before the Flutter engine, so `NativeSentry.requireHttpsDsn` (`android/app/src/main/kotlin/org/libredb/mobile/NativeSentry.kt`) refuses such a DSN there first, with the same pattern and message.
An https issuer is not enough on its own: its discovery document names the endpoints the app then uses.
`OidcClient` (`lib/infrastructure/auth/oidc/oidc_client.dart`) refuses a discovery document whose `authorization_endpoint`, `pushed_authorization_request_endpoint`, `token_endpoint`, `jwks_uri` or `end_session_endpoint` is not an https URL with a host, before it opens the browser or sends a code, a PKCE verifier, a refresh token or an ID token hint.
A sign-in then fails with `OidcFailure.insecureEndpoint`, shown as `auth.oidc_config`, a refresh keeps the session without sending the refresh token, and a provider logout is not opened; every log line names only the endpoint's key.
Only an http issuer, which a prod build never starts with, may name http endpoints, and only on its own host.
The OpenID Connect client follows no redirect either, since oidc_core takes any status under 400 as success: a 3xx to discovery or the JWKS fails the sign-in as `auth.oidc_discovery`, and the log names only the request's role.
A 3xx from the token endpoint is refused the same way, so no code, PKCE verifier or refresh token goes to its `Location`: the sign-in fails as `auth.oidc_failed`, and a refresh is `RotationUnavailable`, which keeps the session, since a redirect says nothing about the refresh token.
`ApiClient` (`lib/infrastructure/http/api_client.dart`) follows no redirect: Studio's API answers JSON and never redirects, so a 3xx, to an http `Location` above all, is an error answer that `studioError` maps, and no request goes to the `Location`, a retry's included.
An unset `OIDC_ISSUER` still starts and fails closed on the login page ([oidc.md](oidc.md)), and an unset `SENTRY_DSN` leaves Sentry off.
The release stops before the build on the same rule (`tool/release/check_defines.sh`, [release.md](release.md)).
`AppConfig.httpsOnlyDefines` lists the three, and `test/architecture/android_release_setup_test.dart` fails when the release passes a URL define that is not in it, or when the script or `NativeSentry.kt` does not carry the pattern verbatim.
Mock and local builds, `main_mock.dart` and `main_local.dart`, check none of them; tool/studio-dev serves Studio and Keycloak over https through Caddy, so its `studio-dev.env` passes.

## Token storage

The provider's tokens live in `flutter_secure_storage` (`lib/infrastructure/storage/secure_storage.dart`).
On Android it encrypts them with AES-GCM under an RSA-OAEP wrapped Android Keystore key.
On iOS the Keychain accessibility is pinned to `first_unlock_this_device`, so a background refresh can read the tokens while the device is locked, and they never move to another device through a backup or iCloud Keychain.
The session's target (Studio or Platform) is stored with the tokens in secure storage, cleared with them, and holds no credential.
A mode switch in the profile sheet rewrites only that target, atomically, under the session it started in, so a sign-out during the switch leaves no target stored; the tokens stay as they are.

## Statement text on the device

A statement can carry customer data and credentials in its literals, such as an e-mail in a `WHERE` or `ALTER ROLE app PASSWORD '...'`.
The editor's drafts (one per connection, with its catalog) and the statement history are the only statement text the app keeps after it closes, and they are kept encrypted, per signed-in account, through `IStatementTextStore` (`lib/features/sql_editor/domain/repositories/statement_text_store.dart`) over `EncryptedTextFileStore` (`lib/infrastructure/storage/encrypted_text_file_store.dart`).

- Place: `<application support>/statement_text/<subjectHash>/`, where `subjectHash` is the SHA-256 hex of Studio's subject (`lib/shared/utils/subject_hash.dart`), so the subject itself is never stored.
  Each connection's draft is a file named by the SHA-256 hex of the connection id, and the history is one `history` file, newest first.
- Cipher: AES-256-GCM through the pure Dart `DartAesGcm` of `cryptography` 2.9.0, run in `Isolate.run`.
  A file is a version byte (1), a random 12-byte nonce, the ciphertext and the 16-byte tag.
  The additional data is `libredb.statement_text.v1`, the subject hash and the file name, so a file copied under another account or name fails authentication instead of showing someone else's text.
  This is plain AES-GCM, which pointycastle also reads, so the package can be replaced without a migration.
- Key: 32 bytes from `Random.secure()` per account, in base64 in `flutter_secure_storage`, written before the account's first file, under a name derived from the subject hash that does not contain it.
  A sign-out keeps the key and the files, so the same account reads its text after the next sign-in, and another account never reads it.
  Neither the text nor the key is kept in memory between calls.
  A key that is malformed while the account has no files left is deleted, so a discard recovers; with files left it reads as unreadable.
- Writes go to `<name>.tmp`, flushed, and are then renamed over the file, so an interrupted write leaves the old file; a stale `.tmp` is never read.
  One queue per directory, shared by every store instance, runs every call, so a draft save and a history append never interleave and two instances never make two keys.
- Bounds, counted as `String.length`: a draft keeps at most 100,000 characters, and a longer one removes the connection's saved draft, so an older and shorter one is never restored, and the editor says it was not kept.
  The history keeps at most 500 entries (Studio's `MAX_HISTORY_ITEMS`) and 1,000,000 characters of statement text, dropping the oldest entries first; an entry over 100,000 characters is kept without its text and marked.
  It never keeps the database's error text.
  The editor adds one entry for each run that reached Studio, Succeeded or Failed (`IStatementHistoryRepository`, `lib/features/sql_editor/domain/repositories/statement_history_repository.dart`); a run that never left the phone or never reached Studio (a cancelled confirmation, a text refused on the phone, offline) adds none, and a page of Load more adds none.
  The History sheet puts an entry's text in the editor without running it, and asks first when that would replace a different text.
  A tapped entry, of the open connection or another one, is opened as an editor open request (`openEditor`, `lib/app/router/app_routes_constants.dart`), which carries the text to the SQL tab as go_router `extra` and never in the location, since go_router logs every location it goes to; the `extra` encodes as null, so state restoration never saves the text.
- Unreadable: a missing key while files are left, a failed authentication, an unknown version or content that does not decode answers `editor.saved_text_unreadable`, which the screen shows with Discard behind a confirmation.
  It is never treated as empty and never deleted on its own; until the user discards it no write replaces that file, and with the key gone no new key is made over the account's files.
  A key is lost when an iOS backup is restored on another device (the files come back, the `first_unlock_this_device` Keychain item does not) or when the Android plugin deletes a key it cannot decrypt.
- A write the device refuses answers `editor.saved_text_not_stored`, which the screen shows.
- Backups: Android excludes `statement_text/` in the `file` domain from cloud backup and device transfer (`data_extraction_rules.xml`, `backup_rules.xml`).
  iOS keeps the default, so a backup may hold the files but never the key; excluding the directory needs Swift that no build here checks, and moves to M6 with the iOS build.
- Clears: `clearSubject` deletes the account's key first and its files after it, so an interrupted clear leaves only ciphertext no key opens, and it reports a failure.
  `clearAll` does that for every account directory, then deletes every key of the store left in `flutter_secure_storage` (found by its name prefix, such as a key whose directory is gone after an iOS reinstall), and only then the whole `statement_text/` directory.
  'Remove my data' runs `clearSubject` for the signed-in account (see below); a plain sign-out keeps the text.
- Logs and errors carry no text, key, subject, subject hash or path; a decode failure is reported without the decrypted bytes.

The statements and database error texts of Platform's audit log (`GET /api/v1/audit`, [platform.md](platform.md#audit-log)) are held in memory only, never stored and never logged.

## Removing the app's data

A sign-out forgets the session: the tokens, the HTTP cache, the files the share sheet got and what the app holds in memory.
What the app keeps per account outlives it on purpose, so the same account finds it again and another account never reads it.
'Remove my data', in the Privacy section of Settings while signed in, removes that too, for the signed-in account only, and then signs out through the usual sign-out (Studio's logout record, the wipe, the identity provider's end-session).
A Platform session keeps no data of an account on the device: `SignedInAccountScope` names no subject there, so Settings shows no 'Remove my data', and `test/architecture/user_data_registry_test.dart` fails when a Platform file reaches the secure store, the device preferences or the device directories.
Its sign-out sends nothing to Studio, since it has no Studio session and Platform v1 has no logout route; it wipes the session and starts the identity provider's end-session like a Studio sign-out ([oidc.md](oidc.md#logout)).
A mode switch between Studio and Platform is not a sign-out: it rewrites only the stored target, clears what the app holds in memory about the mode it leaves, and removes no stored data, so the account finds its Studio data again when it switches back.

- `UserDataRegistry` (`lib/shared/user_data/user_data_registry.dart`) lists every store that keeps data of an account, and `AppDependencies.createUserDataRegistry` fills it: the drafts and the history (`clearSubject`), the starred and recent connections, the last open connection, the database of each server-level connection, the collapsed sections of the connection list, whose keys are Studio's environment and group names, and the share files.
- The share files (`TemporaryShareFiles`, `lib/infrastructure/storage/temporary_share_files.dart`): an object source longer than 100,000 characters is shared as a file in `<temporary directory>/share_files/`, removed once the share sheet answers.
  On Android share_plus copies a shared file into `<cache>/share_plus/` and keeps it until the next share, since the receiving app reads that copy after the sheet has closed.
  Both folders go with every sign-out (`AuthSessionRepository.clear`) and with 'Remove my data'; a removal the phone refuses is shown, and the sign-out then says that data stayed behind.
  A sign-in removes them too before it stores the new session (`SsoAuthRepository`), for a share the app was killed in before a session that ended without the wipe, and a removal the phone refuses refuses the sign-in.
- The language, the theme and the result view mode are device preferences and stay.
- `test/architecture/user_data_registry_test.dart` fails when a class that keeps per-account data is not cleared by an entry, when a `StorageKeys` value is neither cleared nor named a device preference, when a `SecureStorageKeys` value is not a session value (a token or the session target) that a sign-out deletes, or when a file outside its list reaches a device directory through path_provider.
- Every store is tried even when one fails; then the user stays signed in and sees the failure with Retry, which names no stored value, and the log names only the store and the error type.
  The favorites, the open connection and its database are then read again from what is left, so a later change never writes back what was cleared.
- Uninstalling the app removes its files and preferences, but on iOS a Keychain item can outlive a reinstall, so the key of an account's statement text may be left.
  'Remove my data' runs `clearSubject`, which deletes the signed-in account's key even when its files are gone; the keys of other accounts stay, and only `clearAll`, which nothing calls yet, would delete them.

## Certificate pinning

A release build can pin the public keys of Studio's, Keycloak's and Platform's servers, which defends against a user-installed root CA, a rogue intermediate and other ways the device's trust store can be compromised.
Pinning is off by default: all three defines below are empty unless the build sets them, because a wrong pin locks every installed app out of the server.

### The defines

| Define | Host it pins | Read from |
| --- | --- | --- |
| `STUDIO_CERT_PINS` | the host of `PROD_API_URL` | `AppConfig.certificatePins` |
| `OIDC_CERT_PINS` | the host of `OIDC_ISSUER` | `AppConfig.oidcCertificatePins` |
| `PLATFORM_CERT_PINS` | the host of `PLATFORM_API_URL` | `AppConfig.platform` |

Each is a comma-separated list of base64 SHA-256 values, read only in the prod environment (`AppConfig.fromEnvironment` in `lib/infrastructure/config/environment.dart`):

```shell
fvm flutter build apk --release --target lib/main/main_prod.dart \
  --dart-define=PROD_API_URL=https://studio.example.com/api \
  --dart-define=OIDC_ISSUER=https://keycloak.example.com/realms/libredb \
  --dart-define=OIDC_CLIENT_ID=libredb-mobile \
  --dart-define=STUDIO_CERT_PINS=<current key pin>,<backup key pin> \
  --dart-define=OIDC_CERT_PINS=<current key pin>,<backup key pin>
```

- An empty define leaves that host on the system trust store.
- A set `PLATFORM_CERT_PINS` without `PLATFORM_API_URL` stops the start, because a pin without a host is a build mistake.
- A set define needs at least two distinct pins: the key the server uses now and a backup key that is not deployed yet.
- Each pin must be exactly what the command below prints: 44 characters of standard base64 ending in `=`, 32 bytes once decoded.
- A define that breaks either rule stops a prod build at start with `CertificatePinsConfigError`, as `ProdApiUrlConfigError` does; it never falls back to an unpinned connection.

### What is checked

A pin is the SHA-256 of the certificate's SubjectPublicKeyInfo (RFC 7469), not of the whole certificate, so a certificate renewed over the same key keeps its pin.
`CertificatePinner` (`lib/infrastructure/http/certificate_pinner.dart`) reads the SubjectPublicKeyInfo with a small DER walker that only follows the TLV structure of `tbsCertificate` and hashes that element's bytes as they are; a certificate it cannot read matches no pin.

A pinned client uses `SecurityContext(withTrustedRoots: false)`, so every certificate reaches `badCertificateCallback` for the pin check, including one a system CA signed (`createPinnedHttpClient` in `lib/infrastructure/http/certificate_pinning_adapter.dart`).

Which certificate is checked, as measured on 2026-10-24: dart:io hands the callback the server's **leaf** certificate, once per handshake, whatever the server sends above it.
Against tool/studio-dev (Caddy 2.10.2, `tls internal`), the callback on both `localhost:8443` and `localhost:9443` received the leaf issued by "Caddy Local Authority - ECC Intermediate", from a Dart program on the host and from a release build on the API 33 emulator, where a build that pinned only the intermediate's key was refused.
`test/infrastructure/http/certificate_pinning_adapter_test.dart` keeps that result: a server that sends leaf, intermediate and root passes with the leaf's pin and fails with the intermediate's and the root's.
So an operator pins the key of the leaf certificate; a CA key cannot be pinned.

Both hosts' requests go through a pinned client when their define is set:

- Studio: `ApiClient` installs the pinned Dio adapter for every request, retries included (`ResilienceInterceptor` sends them through the same adapter).
- Keycloak: `OidcClient` sends discovery, the key set, the token exchange, the token refresh and the logout discovery through a pinned `package:http` client (`AppDependencies.createOidcClient`).
- Two Keycloak pages open in the system browser (a Custom Tab on Android, `ASWebAuthenticationSession` on iOS), which the app cannot pin, so they trust the device's store as any browser does:
  - The sign-in page.
    The authorization code it returns is worthless without the PKCE verifier, which only the pinned token exchange sends.
  - The provider logout page (`OidcClient._endProviderSession`), whose URL carries the ID token as `id_token_hint` when `OIDC_LOGOUT_HINT` is on.
    An interceptor that reads that URL gets the ID token, not the access token: Studio refuses an ID token as bearer, because its bearer channel accepts only a token whose audience is `OIDC_BEARER_AUDIENCE`, which Keycloak puts into the access token only ([studio.md](studio.md)).

### A mismatch

- A pin mismatch fails the TLS handshake with a `CertificatePinningException` (`lib/infrastructure/http/certificate_pinner.dart`) before any request is written, so no bearer, refresh token or code leaves the device.
- On Studio, Dio reports `DioExceptionType.unknown` with that exception as its `error`, not `DioExceptionType.badCertificate` (Dio raises that only for `IOHttpClientAdapter.validateCertificate`).
  `ResilienceInterceptor` neither retries it nor counts it toward opening the endpoint's circuit.
  `CacheInterceptor` never answers it from cache: the connection may be intercepted, so the request fails instead of showing earlier data.
  `ApiClient` throws it as an `UntrustedCertificateException` (`lib/core/errors/app_api_exception.dart`), a `FetchDataException` whose message names the host and port for the log.
  `studioError` and the other repositories report it as an `AppError` with the `AppErrorCode.networkCertInvalid` key, and the screens show its translated message instead of the exception text.
  At launch the Studio status check meets it first, so the app shows that message on its "Can't reach Studio" page.
- On Keycloak, a sign-in ends with `OidcFailure.untrustedCertificate`, the login page shows `networkCertInvalid`, and no session is stored; a refresh ends with `RotationUnavailable`, which keeps the session, since the refresh token was never sent.
- No other TLS failure is answered from cache either, pinning or not: a certificate the device does not trust (expired, self-signed, a wrong device clock, a captive portal or an intercepting proxy), a hostname mismatch, or a handshake closed before it completed ("Connection terminated during handshake") fails the request.
  A dropped network can close a handshake too, but so can anything between the device and the server, so that case fails closed as well.
  A handshake reset before it completed is a connection error instead, which the cache answers like a lost connection.
  `ApiClient` throws such a failure, and a certificate that `IOHttpClientAdapter.validateCertificate` rejects (`DioExceptionType.badCertificate`), as an `UntrustedCertificateException` too, so the screens show the same translated message; the exception message keeps the TLS error for the log.
  `ResilienceInterceptor` does not count it toward opening the endpoint's circuit, so a circuit-open error never replaces it.

### Reading a pin

From the live server, for each host:

```shell
openssl s_client -servername studio.example.com -connect studio.example.com:443 < /dev/null 2>/dev/null \
  | openssl x509 -pubkey -noout \
  | openssl pkey -pubin -outform der \
  | openssl dgst -sha256 -binary \
  | openssl enc -base64
```

`openssl s_client` prints the leaf first, and `openssl x509` reads only that first certificate, which is the one the app checks.
For the backup pin, make a key that is kept offline until it is needed and read its pin from the key itself:

```shell
openssl ecparam -name prime256v1 -genkey -noout -out backup.key
openssl pkey -in backup.key -pubout -outform der | openssl dgst -sha256 -binary | openssl enc -base64
```

### Keys that outlive renewals

Pin only a key that outlives certificate renewals.
A Caddy edge, such as tool/studio-dev or a LibreDB Platform installer environment, makes a new key at each renewal unless its site is set to reuse it, so a pin of a default Caddy leaf breaks at the next renewal: about every 60 days with a public CA, and about every 8 hours with `tls internal`, whose 12-hour certificate is renewed when a third of its life is left.
Set `reuse_private_keys` in the site's `tls` block before pinning a Caddy edge:

```caddyfile
studio.example.com {
	tls {
		reuse_private_keys
	}
}
```

Other ACME clients have the same choice, for example certbot's `--reuse-key`.

### Rotating a key

Rotate a key in three steps, so that no installed version is left without a pin for the server's key:

1. Ship a release whose define holds the current pin and the pin of the next key, the backup, and wait until the installed base has updated.
2. Move the server to a certificate over the next key.
   On a Caddy edge, either put the backup key in place of the site's key in Caddy's storage and have Caddy renew the certificate, which with `reuse_private_keys` set keeps that key, or serve a certificate issued for the backup key with `tls <cert> <key>`.
3. Ship a release whose define drops the old pin and adds a new backup pin.

The tool/studio-dev stack runs unpinned: its CA and keys are made anew with each fresh volume, so `tool/studio-dev/studio-dev.env` lists the two defines as comments only.

## Screen capture protection

The screens that show data keep out of screenshots, screen recordings and the recent-apps preview while they are on screen.
Display masking is no reason to skip this: it hides only the columns whose names match a pattern, so an unmasked column of customer data is on screen in clear.

Protected while on screen:

| Area | Where |
| --- | --- |
| A result, empty or not: the editor's single run and each statement of a script, Browse rows, and a key value shown as a result | `ResultView` (`lib/shared/widgets/result_view/result_view.dart`) |
| A row's detail | `RowDetailSheet` (`lib/shared/widgets/result_view/row_detail_sheet.dart`) |
| A script's answer, its statement cards included, with rows open or not | `ScriptResultView` (`lib/features/sql_editor/presentation/widgets/script_result_view.dart`) |
| The database's own words of a refused statement or read, which can repeat a value, as a duplicate key error does | `BrowseDatabaseWords` (`lib/shared/widgets/browse_database_words.dart`), in the editor, Browse rows and the key value page |
| A key's text value, a string or a JSON document | `KeyValuePage` (`lib/features/object_browser/presentation/pages/key_value_page.dart`) |
| An object's source, on the source page and the detail page's Source tab | `ObjectSourceView` (`lib/features/object_browser/presentation/widgets/object_source_view.dart`) |

Everything else stays capturable: the connection list, the Browse lists, the editor with no result on screen, a key's name and Studio's `TYPE` answer, and the settings.

How it works:

- `ScreenCaptureGuard` (`lib/core/security/screen_capture_guard.dart`) wraps a value area, not a whole page, and holds a lease of the app's one `ScreenCaptureProtection` while it is on screen; `AppScope` provides that protection.
- `ScreenCaptureProtection` (`lib/core/security/screen_capture_protection.dart`) counts leases: the first turns protection on and the last release turns it off, so closing a row's detail over a result leaves the result protected.
  A release without a lease throws a `StateError`, since the count would no longer say what is on screen.
- On screen means mounted with its tickers on (`ScreenCaptureProtected` in `lib/core/security/screen_capture_protected.dart`).
  A route covered by an opaque page, or the shell hidden under the refusal page or the "Can't reach Studio" page, has its tickers off and holds no lease, so the screen shown above it can be captured; a sheet over a result leaves the result's tickers on.
  The shell's tabs are routes of one `ShellRoute`, so a tab change disposes the editor and its result: nothing of it stays mounted offstage.
  The detail page's tab view keeps the Source tab alive off screen, so that tab turns its tickers off while none of it is in view, and the Columns tab shown in its place can be captured.
- The platform calls sit behind `IScreenCapturePlatform` (`lib/core/security/screen_capture_platform.dart`), so a widget test counts leases on its own instance without a platform channel (`test/support/screen_capture.dart`).
  A failed platform call is logged at error level and keeps the lease count, so the leases stay balanced.
- On Android, `ScreenCapturePlatform` sets and clears `FLAG_SECURE` through the `org.libredb.mobile/screen_capture` channel of `MainActivity` (`SecureWindow.kt`), which answers whether the flag is set on the window afterwards, read back from the window.
  An answer other than the one asked for throws a `ScreenCaptureFlagException`, and no window or a window that throws answers an error, so a protection that did not take is logged at error level and never assumed.
  The app does not use `screen_protector` on Android, because its 1.5.3 plugin answers success with no activity attached and the Dart side drops its answer (#205).
- A guard without a `ScreenCaptureProtection` above it fails with `ProviderNotFoundException` when it mounts, on screen or offstage, rather than show the data unprotected.

### The switch

`SCREEN_CAPTURE_PROTECTION` is read at build time in `AppConfig.fromEnvironment` (`lib/infrastructure/config/environment.dart`):

| Value | Prod build | Dev and test builds |
| --- | --- | --- |
| absent or empty | On | Off, so a developer can capture the emulator |
| `true` | On | On |
| `false` | Off | Off |

Any other value stops the app at start with `ScreenCaptureProtectionConfigError`, so a typo never decides it.
Switched off, a guard takes no lease and every screen can be captured; a deployment that wants screenshots builds with:

```shell
fvm flutter build apk --release --target lib/main/main_prod.dart --dart-define=SCREEN_CAPTURE_PROTECTION=false
```

### The platforms

| Platform | What happens |
| --- | --- |
| Android | `FLAG_SECURE`: a screenshot and a screen recording are black, and the recent-apps preview is black. |
| iOS | iOS offers no API to block a screenshot. `screen_protector` blurs the task-switcher snapshot, so the app preview shows no value; a screenshot taken in the foreground still succeeds (#199 checks this on a device). |

## Result masking

The phone masks a statement's result before any row reaches a widget, the clipboard, a share or an export, so an account never sees more than Studio's web grid shows the same account.
It is display masking and not a control: Studio masks only in the browser and answers clear values to a bearer too (S-07), so the values do cross the network.

The rules are a Dart port of Studio's defaults in `lib/shared/security/result_masking/`, from `src/lib/data-masking.ts` at libredb-studio c9989a6b5, and `masking_config_test.dart` pins the pattern list and mask types to that commit.

- A column is masked when an enabled built-in pattern (email, password, SSN, card, phone, token or key, address, IP, financial, birthdate) matches its whole name, ignoring case; a repeated column numbered `email (2)` is matched as `email`, and the first matching pattern wins.
- Matching reads column names only, so a sensitive value inside a Redis hash or a nested document stays clear, as in Studio's grid (S-22).
- NULL stays NULL; any other value is masked as JavaScript's `String` prints it, so a document is `[object Object]` and never masked from its own text.
- An engine may exempt a column (`ProviderMeta.maskingExemptColumns`, such as a Modbus register `address`); an exemption Dart cannot compile exempts nothing and logs one warning.
- The per-user masking config is not safely readable from the phone (S-08), so the phone always uses the defaults.

The role comes from `StudioRoleScope`, which `AppShell` provides from Studio's `GET /api/auth/me`.
`MaskingPolicy.forRole` gives the admin Studio's admin settings, and a user, a role the app does not know and an identity not yet loaded or failed the user settings.
Studio gives an unknown role the admin settings; the phone gives it the least on purpose.
Every role masks: the admin's toggle and reveal stay off until M7-13 (#35).
The screen that runs a statement builds one policy per result of one connection and hands it to the result view, which masks every later page with it.
The masked result replaces the clear one, so no state, bloc, cache or log keeps the clear rows.

Three of Studio's mask functions have open bugs, which the port corrects until Studio merges its own fixes:

- `partial` (Token/Key) shows 8 of 9 or 10 characters in Studio (libredb/libredb-studio#1915); the phone masks up to 8 characters fully and from 9 on shows `min(4, floor(n / 8))` characters at each end, keeping the length.
- `email` prints `undefined` for an empty local part or domain in Studio (#1915); the phone gives `***@***.***`.
- `date` (Birthdate) keeps the last two characters of any value in Studio (#1917), so a timestamp shows `****-**-0Z`; the phone keeps the day only of a bare `YYYY-MM-DD` date and masks anything else as `****-**-**`.

## Clipboard

A result value or a whole row reaches the clipboard only through `SensitiveClipboard` (`lib/shared/utils/sensitive_clipboard.dart`), a method channel that `MainActivity` and `AppDelegate` answer.
It copies what the screen shows, so a masked field is copied as its mask.
A selected part of a value in the row sheet is copied the same way, from the toolbar's Copy or with Ctrl+C (`SensitiveSelectableText`), and that toolbar has no Share, Look Up or Search Web, which would hand the value to another app or the system.
A screen reader's Copy on a value copies the whole value through `SensitiveClipboard` too: the editable text's own Copy action writes the plain clipboard directly, so its semantics are replaced by a node that reads the value and copies it, and a screen reader user cannot copy a part of a value.

- On Android 13 (API 33) and later the clip carries `ClipDescription.EXTRA_IS_SENSITIVE`, so the system's clipboard preview hides the value.
  Android below 13 shows no preview, and the clip is plain there.
- On iOS the item expires after 2 minutes and is local only (`UIPasteboard` `setItems(_:options:)` with `.expirationDate` and `.localOnly`), so Universal Clipboard does not carry it to the user's other devices.
- A failed copy is shown to the user with its error code and logged with its error type, never with the value.

The source viewer, the copy of an object's name and the copy of a failed statement keep the plain clipboard: they hold no row value.

## Write confirmation

The SQL editor asks the user to confirm a statement before it is sent unless `InterimWriteCheck` (`lib/features/sql_editor/domain/interim_write_check.dart`) can clear it.
The check is pure and fail closed: it reads exactly the text that will be sent, logs nothing, and answers `RunsWithoutAsking` or `AsksBeforeRunning` with every reason that applies.
It replaces Studio's own reading, about 4,500 lines of grammar code in `src/lib/sql`, which the phone does not port, until Studio offers an analysis endpoint (S-06, #122 and #123); it then stays as that analysis's fallback.

A SQL text runs without asking only when all three of these hold:

- The raw text holds no deny word, comments and quotes included, in any ASCII case, where a deny word counts when its left neighbour is not an ASCII letter or `_` and its right neighbour is not an ASCII letter, digit or `_`; so `deleted` is not `DELETE`, while `x$delete`, `çdelete` and `1DELETE` hold it, since T-SQL reads `SELECT 1DELETE FROM orders` as a SELECT and a DELETE.
  Inside a run of ASCII letters, digits and `_` that starts with a digit every deny word counts wherever it sits, because T-SQL ends a number at the first character that cannot continue it: `SELECT 0xKILL 52` and `SELECT 1eKILL 52` ask, while `SELECT 0x1F` and `SELECT 1e5` run.
  The first deny word by position is named, the longest when several start there.
  A text that holds `U&` directly followed by a double quote, in any ASCII case and anywhere, asks too, naming `U&"`: a PostgreSQL Unicode-escaped identifier spells a name the scan cannot read, and review#111 ran `dblink_exec` as `U&"dblink_exe\0063"(...)` on PostgreSQL 17.6.
- No `;` is followed by anything but white space, and no line holds only `GO` or only `/` (trimmed, in any case).
- Its first keyword, read after leading comments only, is `SELECT`, `SHOW`, `DESCRIBE`, `DESC`, `EXPLAIN`, `VALUES`, `TABLE` or `WITH`.
  A leading comment counts only when every engine reads it the same way; otherwise the text has no first keyword and asks.
  So a text asks when a leading comment never closes, when a leading `--` comment holds a bare carriage return (one no line feed follows), a vertical tab, a form feed, U+0085, U+2028 or U+2029, or is not followed by white space, when a leading `/* */` comment holds another `/*`, and when a leading comment starts with `/*!` or `/*M!`.
  A first keyword `EXPLAIN` asks, naming `PLAN` or `ALL`, when its next word, read the same way, is `PLAN` or `ALL`, or when a comment the engines read differently stands before that word: Oracle and DB2 write the plan of `EXPLAIN PLAN` into a table, and DB2's `EXPLAIN ALL` writes its explain tables.
  ClickHouse's `EXPLAIN PLAN`, a read, asks too, which is accepted, while `EXPLAIN (FORMAT JSON) SELECT 1` and SQLite's `EXPLAIN QUERY PLAN` run.

The deny words are `INSERT`, `UPDATE`, `DELETE`, `MERGE`, `UPSERT`, `TRUNCATE`, `DROP`, `ALTER`, `CREATE`, `GRANT`, `REVOKE`, `DENY`, `CALL`, `EXEC`, `EXECUTE`, `DO`, `COPY`, `LOCK`, `SET`, `RESET`, `COMMIT`, `ROLLBACK`, `BEGIN`, `VACUUM`, `REINDEX`, `CLUSTER`, `REFRESH`, `INTO`, `ANALYZE` and `ANALYSE`, and the T-SQL statements that need no separator and change data, rights, sessions or the server: `KILL`, `SHUTDOWN`, `BACKUP`, `RESTORE`, `DBCC`, `RECONFIGURE`, `DISABLE`, `ENABLE`, `SEND`, `RECEIVE`, `WRITETEXT`, `UPDATETEXT` and `SETUSER`.
The built-ins whose call has an effect the check cannot see in the text are deny words too, since they are rare as names; the list is closed at 94, and a deny word may hold `$` (Snowflake's `SYSTEM$` functions), which matches only itself:

- They run statement text: `DBLINK`, `DBLINK_EXEC`, `DBLINK_SEND_QUERY`, `DBLINK_OPEN`, `QUERY_TO_XML`, `QUERY_TO_XML_AND_XMLSCHEMA`, `QUERY_TO_XMLSCHEMA`.
- They keep or end remote dblink state: `DBLINK_FETCH`, `DBLINK_CLOSE`, `DBLINK_CONNECT`, `DBLINK_CONNECT_U`, `DBLINK_DISCONNECT`, `DBLINK_CANCEL_QUERY` (`dblink_fetch` advances a remote cursor, `dblink_close` can issue the COMMIT that `dblink_open` left open, and a named connection stays on Studio's shared provider).
- They write, move or remove large objects: `LO_CREAT`, `LO_CREATE`, `LO_FROM_BYTEA`, `LO_PUT`, `LOWRITE`, `LO_TRUNCATE`, `LO_TRUNCATE64`, `LO_UNLINK`, `LO_IMPORT`, `LO_EXPORT`.
- They take or release advisory locks, at session or transaction level: `PG_ADVISORY_LOCK`, `PG_ADVISORY_LOCK_SHARED`, `PG_ADVISORY_UNLOCK`, `PG_ADVISORY_UNLOCK_SHARED`, `PG_ADVISORY_UNLOCK_ALL`, `PG_ADVISORY_XACT_LOCK`, `PG_ADVISORY_XACT_LOCK_SHARED`, `PG_TRY_ADVISORY_LOCK`, `PG_TRY_ADVISORY_LOCK_SHARED`, `PG_TRY_ADVISORY_XACT_LOCK`, `PG_TRY_ADVISORY_XACT_LOCK_SHARED` (a session-level lock or an unlock can outlive the request on Studio's provider, which every user of the connection shares).
- They end or cancel another session's work (`PG_TERMINATE_BACKEND`, `PG_CANCEL_BACKEND`), change a setting or a sequence (`SET_CONFIG`, `SETVAL`, `NEXTVAL`), or load code (`LOAD_EXTENSION`).
- They send a notification (`PG_NOTIFY`), or signal the server or a session (`PG_RELOAD_CONF`, `PG_ROTATE_LOGFILE`, `PG_LOG_BACKEND_MEMORY_CONTEXTS`).
- They control backup, recovery and the WAL: `PG_BACKUP_START`, `PG_BACKUP_STOP`, `PG_START_BACKUP` and `PG_STOP_BACKUP` (the names before PostgreSQL 15), `PG_CREATE_RESTORE_POINT`, `PG_SWITCH_WAL`, `PG_PROMOTE`, `PG_WAL_REPLAY_PAUSE`, `PG_WAL_REPLAY_RESUME`, `PG_LOG_STANDBY_SNAPSHOT`.
- They create, copy, drop, advance or consume replication slots and origins, or write to the WAL stream those read: `PG_CREATE_PHYSICAL_REPLICATION_SLOT`, `PG_CREATE_LOGICAL_REPLICATION_SLOT`, `PG_COPY_PHYSICAL_REPLICATION_SLOT`, `PG_COPY_LOGICAL_REPLICATION_SLOT`, `PG_DROP_REPLICATION_SLOT`, `PG_REPLICATION_SLOT_ADVANCE`, `PG_LOGICAL_SLOT_GET_CHANGES`, `PG_LOGICAL_SLOT_GET_BINARY_CHANGES`, `PG_SYNC_REPLICATION_SLOTS`, `PG_REPLICATION_ORIGIN_CREATE`, `PG_REPLICATION_ORIGIN_DROP`, `PG_REPLICATION_ORIGIN_ADVANCE`, `PG_REPLICATION_ORIGIN_SESSION_SETUP`, `PG_REPLICATION_ORIGIN_SESSION_RESET`, `PG_REPLICATION_ORIGIN_XACT_SETUP`, `PG_REPLICATION_ORIGIN_XACT_RESET`, `PG_LOGICAL_EMIT_MESSAGE`.
- They maintain indexes: `BRIN_SUMMARIZE_NEW_VALUES`, `BRIN_SUMMARIZE_RANGE`, `BRIN_DESUMMARIZE_RANGE`, `GIN_CLEAN_PENDING_LIST`.
- They reset statistics: `PG_STAT_RESET`, `PG_STAT_RESET_SHARED`, `PG_STAT_RESET_SINGLE_TABLE_COUNTERS`, `PG_STAT_RESET_SINGLE_FUNCTION_COUNTERS`, `PG_STAT_RESET_SLRU`, `PG_STAT_RESET_REPLICATION_SLOT`, `PG_STAT_RESET_SUBSCRIPTION_STATS`.
- They write the catalog or server files: `PG_IMPORT_SYSTEM_COLLATIONS`, and adminpack's `PG_FILE_WRITE`, `PG_FILE_RENAME`, `PG_FILE_UNLINK`, `PG_FILE_SYNC` (PostgreSQL 16 and earlier).
- They hold or release a MySQL or MariaDB named lock, which a commit or rollback does not release, so it outlives the request on Studio's shared connection: `GET_LOCK`, `RELEASE_LOCK`, `RELEASE_ALL_LOCKS`.
- They end or cancel Snowflake sessions, transactions or queries, as `PG_TERMINATE_BACKEND` and `PG_CANCEL_BACKEND` do on PostgreSQL: `SYSTEM$ABORT_SESSION`, `SYSTEM$ABORT_TRANSACTION`, `SYSTEM$CANCEL_QUERY`, `SYSTEM$CANCEL_ALL_QUERIES`.

The read-only dblink helpers (`dblink_get_connections`, `dblink_error_message`, `dblink_is_busy`, `dblink_get_result`, `dblink_get_notify`, `dblink_get_pkey` and the `dblink_build_sql_*` builders) are not deny words.
The administration functions come from PostgreSQL 17's 'System Administration Functions' and statistics resets: every one there that changes state is a deny word, because a Studio connection can run as a superuser or an owner role; the reads there, such as `current_setting`, `pg_current_wal_lsn` and `pg_logical_slot_peek_changes`, and MySQL's `IS_FREE_LOCK`, are not.
So `SELECT nextval('s')` and `SELECT dblink_exec('dbname=app', chr(68) || 'ELETE FROM orders')` ask, while a column such as `my_nextval_col` does not.
`ANALYZE` and `ANALYSE` cover `EXPLAIN ANALYZE` in every spelling, `EXPLAIN (FORMAT JSON, ANALYZE)` included, so a data-modifying CTE and `EXPLAIN ANALYZE` of a write, which Studio's own check still misses (libredb/libredb-studio#1862 and #1863), ask.
`REPLACE` is not a deny word: it is a string function in every dialect, and its statement forms are caught by `INTO`, `CREATE`, the separator rule and the first-keyword rule.

Comments are not removed before the scan, because the engines disagree about them, as Studio's own readers record from measurements (`src/lib/sql/update-target.ts:187-226`, `src/lib/sql/optimizer-hints.ts:1-44`): PostgreSQL and SQL Server end a `--` comment at a bare carriage return while SQLite, MySQL, MariaDB and DuckDB end it at the line feed, PostgreSQL and SQL Server nest `/* */` comments while the others end one at the first `*/`, MySQL and MariaDB run the body of `/*!` and `/*M!`, and MySQL needs white space after `--`.
Each of these could hide the real first keyword behind a leading comment: on PostgreSQL 17.6 `/* /* */ SELECT 1 */ COMMENT ON TABLE orders IS 'x'` ran, and on SQLite `-- x`, a bare carriage return, `SELECT 1`, a line feed and `PRAGMA user_version = 5` ran, which is why such a comment leaves no first keyword.
So `SELECT 1 -- x`, a bare carriage return and `; DELETE FROM t`, two statements to PostgreSQL, asks, and so do `SELECT * FROM t /*!50000 INTO OUTFILE '/tmp/x' */` and `SELECT 1 --1 INTO OUTFILE '/tmp/f'`.
T-SQL needs no separator between statements, so `SELECT 1 KILL 52` asks on its deny word.
With the deny scan and the separator rule on the raw text no quote or comment can hide a word or a separator, so a backslash, a `$`, a `#` or an unclosed quote does not ask by itself.

Everything else asks, with every reason that applies:

- May write: a deny word anywhere, or a first keyword off the allow list or none; the sheet names the first deny word, else that first keyword, and its line.
- Several statements: a `;` followed by more text, or a `GO` or `/` line.
- Not SQL: every text on an engine that does not speak SQL (MongoDB, Redis and the others), read as one statement and never split.

This asks for more than Studio on purpose: `INSERT`, `CREATE`, a write word inside a comment or a string (`select 1 -- delete`, `SELECT * FROM audit WHERE op = 'DELETE'`), `SELECT 'a;b'` and every Redis or MongoDB command ask.
A false prompt costs one tap, or the typed name on production; a missed write costs data.

The known limits, which Studio's check shares and #123 fixes:

- The check reads words, not what a user-defined function or procedure, or a built-in off the deny list, does when an allowed statement calls it, and such a function can run any statement or write a server file.
  `dblink_exec` ran a statement built at run time and deleted every row of a table before it joined the deny list, and `lo_export` writes a server file; both ask now, but `SELECT my_func(1)` runs without asking whatever `my_func` does.
- A T-SQL statement whose keyword is not on the deny list is not seen.

`WriteConfirmationSheet` (`lib/features/sql_editor/presentation/widgets/`) shows the connection's name and environment, every reason in words, and every line of the text in a lazily built list, never an excerpt, so a write far down a script can be found.
Lines are split at a line feed, a carriage return and a CRLF pair, as the check counts them, so a statement after a bare carriage return shows on a line of its own.
On a connection Studio refuses writes on (`StudioConnection.readOnlyForUser`) it says so, and words the two causes apart: a read grant is one an administrator can raise, and the connection's own read-only flag is the operator's setting.
On a production connection the header is in the error colour and Run stays disabled until the user types the connection's name; that step is the phone's own and applies to every confirmation on such a connection.
The typed name follows Studio's typed confirmation (`src/components/typed-confirm.tsx`): the comparison is exact, an empty field never matches, a connection without a name shows a sentence in place of the field and keeps Run disabled, the field turns autocorrect, suggestions, capitalisation and smart punctuation off, and it is empty each time the sheet opens.
The sheet answers confirmed or cancelled and keeps no statement after it closes; neither the check nor the sheet logs, and no translated string carries the statement.

## Inactivity sign-out

`IdleTimeoutObserver` (`lib/core/security/idle_timeout_observer.dart`) signs the user out after a period without input.

- `AppConfig.idleTimeout` sets the period: `AppConfig.prod()` sets 15 minutes, and `AppConfig.mock()`, `AppConfig.local()` and `AppConfig.test()` set `null`, which turns it off, so a hot reload, a mocked session or a run against a development stack is never signed out.
- `main_local.dart` is the weakest profile on purpose: no certificate pinning, no screen-capture protection and no idle timeout. It exists for hand testing against a development stack on a developer's own machine, never for a build anyone else installs; only `main_prod.dart` is shipped.
- Every entry point shares one `applicationId`, `org.libredb.mobile`, so installing the local build replaces the prod build **and inherits its secure storage**. A session stored by a `main_prod.dart` build is therefore reachable from a build that never times out idle and allows screenshots, screen recordings and the recent-apps preview of every data screen. Sign out before switching between the two, or clear the app's data.
- On iOS a Dart `Timer` pauses while the app is suspended, so the observer also records the wall-clock time on each lifecycle change; a resume past the period signs out at once.
- When the period ends, the user sees a translated snackbar ("You were signed out due to inactivity.") and the router goes to the sign-in page.
  The session ends with `SessionExpiredReason.idleTimeout`, so the log and the UI can tell it from a sign-out the user chose.
- A touch or drag, mouse wheel and trackpad scrolling, and hardware key presses reset the timer, so a user who only scrolls a long page stays signed in.
  Typing on the on-screen keyboard usually does not: the system keyboard sends text through the text input channel, not as key events.
  Moving the mouse without a button pressed does not count, and neither do the key events Flutter synthesizes to match the keyboard state.

Compliance baselines that expect an inactivity timeout include SOC 2 CC6.1, ISO 27001 A.9.4.2 and GDPR Art. 32.

## App lock

With the app lock on, a phone left unlocked does not hand a stranger a client that can run statements: the app asks for the device's biometrics, with its screen lock (PIN, pattern or password) as the fallback, on a cold start that restores a session and on a return after a set time in the background.
The feature lives in `lib/features/app_lock/`; `AppLockBloc` (`application/app_lock_bloc.dart`) decides when to lock.

When it locks:

- A cold start that restores a stored session locks; a sign-in at the identity provider opens unlocked, since Keycloak just proved who the user is.
  A session that the restore's late answer brings back after its time limit (`SessionExpiredReason.storageTimeout`) counts as a restore and locks.
  A restore that arrives while the settings are still read locks with no open state between, and no signed-in page shows until the lock has decided.
- A return after at least the chosen time in the background locks: immediately, 1, 5 (the default) or 15 minutes.
  The time away is measured by the wall clock from the moment the app leaves the screen (`hidden` or `paused`) to its return, as `IdleTimeoutObserver` measures it, since a timer does not run while the phone suspends the app.
  A system sheet over the app, which only makes it `inactive`, is not time away.
  The PIN screen that the prompt opens is not time away either, so unlocking with the PIN does not lock again on the return.
- It never locks while nobody is signed in, and a sign-out removes the lock screen.
- When the time away also reaches the idle period of the inactivity sign-out (15 minutes in prod), the idle sign-out wins: the pages stay hidden behind a spinner until the session has ended, and no lock shows over the login page.

The lock screen:

- `AppLockGate` (`lib/app/lock/app_lock_gate.dart`) puts it above the router in the `MaterialApp` builder, over the "Can't reach Studio" page too.
  The pages stay mounted under it, offstage, so an editor's text and a shown result are as they were once it opens; offstage they are not painted, take no touch, are left out of the semantics tree, so a screen reader reads only the lock screen, have their tickers off, so their screen capture guards give their leases back, and lose the focus, so the keyboard and a hardware key reach no hidden field.
- The system back does nothing while it covers the app: the gate is a binding observer registered before the router's back button dispatcher and takes the back first.
- Unlock opens the system prompt (`local_auth` 3.0.2, biometrics with the device credential as fallback); a cancelled or failed prompt keeps the app locked and nothing is retried by itself.
  Too many attempts say to try later.
- Sign out runs the app's sign-out (Studio's logout record, the wipe, the identity provider's end-session) without a confirmation, so a user who cannot authenticate can still leave and wipe the session; the pages stay hidden until the login page shows.
- On a device without a screen lock the lock screen says to set one and offers only Sign out; it offers Unlock again once the user has set one and comes back.
- A check of the device that fails never opens the app: it is logged at error level and the lock screen says the check failed, with Unlock and Sign out; with `APP_LOCK_REQUIRED` a sign-in then lands on that screen too.

The settings:

- The switch and the timeout are device preferences (`StorageKeys.appLockEnabled` and `appLockTimeout`, `StorageScope.device`): no sign-out removes them, and 'Remove my data' keeps them.
- Turning the lock on asks the system prompt first, so only the device's owner can turn it on; turning it off or changing the timeout does not.
- A device without a screen lock shows why the switch cannot be turned on; a lock left on after the screen lock was removed can still be turned off.
- Stored settings that cannot be read keep the lock on with the default timeout, logged at error level: the lock fails closed.

### The switch

`APP_LOCK_REQUIRED` is read at build time in `AppConfig.fromEnvironment` (`lib/infrastructure/config/environment.dart`): `true` forces the lock on in every environment, `false` or absent leaves it to the user, and any other value stops the app at start (`AppLockRequiredConfigError`).
A required lock shows the switch on and disabled ("Required by your organization"), and on a device without a screen lock a signed-in user sees only the lock screen with Sign out, after a sign-in too.
After a sign-in, a required lock keeps the pages hidden behind a spinner until the device has answered whether it can lock.

### The recent-apps preview

While the lock is on, the recent-apps screen shows no content of the app:

| Platform | How |
| --- | --- |
| Android 13 (API 33) and later | `Activity.setRecentsScreenshotEnabled(false)` through the `org.libredb.mobile/recents_preview` channel of `MainActivity` (`RecentsPreview.kt`); measured on the API 33 emulator: the recents card is blank. Opening the recents screen from inside the app shows the launcher's live view of the current window, which is the lock screen whenever the app is locked. |
| Android below 13 | `MainActivity` answers that it has no switch, and `AppLockBloc` holds a lease of `ScreenCaptureProtection` (`FLAG_SECURE`) from the moment the app starts to leave the screen (`inactive`) until it is back; measured on the API 30 emulator: the recents card is blank with the lock on and shows the connection list with it off, and a screenshot works again after the return. The lease does nothing in a build with `SCREEN_CAPTURE_PROTECTION=false`. |
| iOS | No switch: the same lease, which blurs the task-switcher snapshot; #199 checks Face ID and the snapshot on a device. |

### Platform setup

- `MainActivity` is a `FlutterFragmentActivity`, which `local_auth` needs for `BiometricPrompt`, and the launch and normal themes inherit from `Theme.AppCompat`, without which the prompt crashes on Android 8 (`test/architecture/app_lock_platform_setup_test.dart`).
- The `USE_BIOMETRIC` permission comes from `local_auth_android`'s manifest through the manifest merger; the main manifest does not declare it.
- `ios/Runner/Info.plist` has `NSFaceIDUsageDescription`, with English and Turkish texts in `en.lproj` and `tr.lproj/InfoPlist.strings`.
