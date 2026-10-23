# Security

This page describes the protections inside the app: how it stores tokens and statement text, how it checks the server's certificate, how it hides sensitive screens, how it masks sensitive result values, how it copies them, how it asks before a statement that may write runs, and when it signs an idle user out.
What the app sends to Studio and what it never holds is in [architecture.md](architecture.md#security), and what leaves the device in a crash report is in [crash-reporting.md](crash-reporting.md).

## Token storage

The provider's tokens live in `flutter_secure_storage` (`lib/infrastructure/storage/secure_storage.dart`).
On Android it encrypts them with AES-GCM under an RSA-OAEP wrapped Android Keystore key.
On iOS the Keychain accessibility is pinned to `first_unlock_this_device`, so a background refresh can read the tokens while the device is locked, and they never move to another device through a backup or iCloud Keychain.

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
- Unreadable: a missing key while files are left, a failed authentication, an unknown version or content that does not decode answers `editor.saved_text_unreadable`, which the screen shows with Discard behind a confirmation.
  It is never treated as empty and never deleted on its own; until the user discards it no write replaces that file, and with the key gone no new key is made over the account's files.
  A key is lost when an iOS backup is restored on another device (the files come back, the `first_unlock_this_device` Keychain item does not) or when the Android plugin deletes a key it cannot decrypt.
- A write the device refuses answers `editor.saved_text_not_stored`, which the screen shows.
- Backups: Android excludes `statement_text/` in the `file` domain from cloud backup and device transfer (`data_extraction_rules.xml`, `backup_rules.xml`).
  iOS keeps the default, so a backup may hold the files but never the key; excluding the directory needs Swift that no build here checks, and moves to M6 with the iOS build.
- Clears: `clearSubject` deletes the account's key first and its files after it, so an interrupted clear leaves only ciphertext no key opens, and it reports a failure.
  `clearAll` does that for every account directory, then deletes every key of the store left in `flutter_secure_storage` (found by its name prefix, such as a key whose directory is gone after an iOS reinstall), and only then the whole `statement_text/` directory.
  Both are for 'Remove my data' in M6; a plain sign-out keeps the text.
- Logs and errors carry no text, key, subject, subject hash or path; a decode failure is reported without the decrypted bytes.

## Certificate pinning

The HTTP client can pin the server's certificate, which defends against a user-installed root CA, a rogue intermediate and other ways the device's trust store can be compromised.
Pinning is off: `AppConfig.certificatePins` is empty in every environment, because a wrong pin locks every installed app out of the server.
Milestone M6 turns it on for the release build ([roadmap.md](roadmap.md)).

How it works:

- `AppConfig.certificatePins` (`lib/infrastructure/config/environment.dart`) is a list of base64 SHA-256 hashes.
  An empty list leaves the system trust store in charge.
  A non-empty list installs a Dio adapter (`lib/infrastructure/http/certificate_pinning_adapter.dart`) that uses `SecurityContext(withTrustedRoots: false)`, so every certificate reaches `badCertificateCallback` for the pin check, including one a system CA signed.
- A pin mismatch fails the TLS handshake with a `CertificatePinningException` (`lib/infrastructure/http/certificate_pinner.dart`), so Dio reports `DioExceptionType.unknown` with that exception as its `error`, not `DioExceptionType.badCertificate` (Dio raises that only for `IOHttpClientAdapter.validateCertificate`).
  `ResilienceInterceptor` neither retries it nor counts it toward opening the endpoint's circuit.
  `CacheInterceptor` never answers it from cache: the connection may be intercepted, so the request fails instead of showing earlier data.
  Retries and the token refresh go through the same pinned adapter as the original request.
  `ApiClient` throws it as an `UntrustedCertificateException` (`lib/core/errors/app_api_exception.dart`), a `FetchDataException` whose message names the host and port for the log.
  `studioError` and the other repositories report it as an `AppError` with the `AppErrorCode.networkCertInvalid` key, and the screens show its translated message instead of the exception text.
- No other TLS failure is answered from cache either, pinning or not: a certificate the device does not trust (expired, self-signed, a wrong device clock, a captive portal or an intercepting proxy), a hostname mismatch, or a handshake closed before it completed ("Connection terminated during handshake") fails the request.
  A dropped network can close a handshake too, but so can anything between the device and the server, so that case fails closed as well.
  A handshake reset before it completed is a connection error instead, which the cache answers like a lost connection.
  `ApiClient` throws such a failure, and a certificate that `IOHttpClientAdapter.validateCertificate` rejects (`DioExceptionType.badCertificate`), as an `UntrustedCertificateException` too, so the screens show the same translated message; the exception message keeps the TLS error for the log.
  `ResilienceInterceptor` does not count it toward opening the endpoint's circuit, so a circuit-open error never replaces it.

Read the pin from the live server:

```shell
openssl s_client -servername studio.example.com -connect studio.example.com:443 < /dev/null 2>/dev/null \
  | openssl x509 -outform DER \
  | openssl dgst -sha256 -binary \
  | openssl enc -base64
```

The pin is the hash of the whole certificate, not of its SubjectPublicKeyInfo.
The OWASP recommendation, `SHA-256(SubjectPublicKeyInfo)`, survives a certificate renewal that keeps the key pair; reading it from the DER needs an ASN.1 parser, which the app does not have yet.
Moving to it changes only what is hashed, not the shape of a stored pin.

Rotate a key in three steps, so that no installed version is left without a pin for the server's certificate:

1. Add the new pin to `certificatePins` before the server's key changes, and ship that version.
2. Move the server to the new certificate.
3. Remove the old pin in a later release.

## Screen capture protection

The app can keep a sensitive screen out of screenshots and the task switcher.
No screen uses it yet.

- `ScreenCaptureProtection.enable()` and `.disable()` in `lib/core/security/screen_capture_protection.dart` turn it on and off, counting leases, so popping an inner protected screen leaves it on while an outer one is still mounted.
- The `ScreenCaptureProtected<T>` mixin in `lib/core/security/screen_capture_protected.dart` takes a lease in `initState` and releases it in `dispose`.

The two platforms behave differently:

| Platform | What happens |
| --- | --- |
| Android | `FLAG_SECURE`: screenshots and screen recording are blocked, and the recent-apps preview is black. |
| iOS | iOS offers no API to block a screenshot. The task-switcher snapshot is blurred, so the app preview shows no secret; a screenshot taken in the foreground still succeeds. |

To protect a screen, add the mixin to its state:

```dart
import 'package:libredb_mobile/core/security/screen_capture_protected.dart';

class _QueryResultPageState extends State<QueryResultPage> with ScreenCaptureProtected<QueryResultPage> {
  // ...
}
```

Protect a screen that shows a credential, a token or data the user should not share by accident.
Leave it off where the user is expected to capture the screen.

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

- The raw text holds no deny word, comments and quotes included, matched as a whole word in any ASCII case, where a word is a run of ASCII letters, digits and `_`; so `deleted` is not `DELETE`, while `x$delete` and `çdelete` hold it.
- No `;` is followed by anything but white space, and no line holds only `GO` or only `/` (trimmed, in any case).
- Its first keyword, read after leading comments only, is `SELECT`, `SHOW`, `DESCRIBE`, `DESC`, `EXPLAIN`, `VALUES`, `TABLE` or `WITH`.
  A `--` comment ends at a line feed or a carriage return, a `/* */` comment at the first `*/`, and a text whose leading comment never closes has no first keyword and asks.

The deny words are `INSERT`, `UPDATE`, `DELETE`, `MERGE`, `UPSERT`, `TRUNCATE`, `DROP`, `ALTER`, `CREATE`, `GRANT`, `REVOKE`, `DENY`, `CALL`, `EXEC`, `EXECUTE`, `DO`, `COPY`, `LOCK`, `SET`, `RESET`, `COMMIT`, `ROLLBACK`, `BEGIN`, `VACUUM`, `REINDEX`, `CLUSTER`, `REFRESH`, `INTO`, `ANALYZE` and `ANALYSE`, and the T-SQL statements that need no separator and change data, rights, sessions or the server: `KILL`, `SHUTDOWN`, `BACKUP`, `RESTORE`, `DBCC`, `RECONFIGURE`, `DISABLE`, `ENABLE`, `SEND`, `RECEIVE`, `WRITETEXT`, `UPDATETEXT` and `SETUSER`.
`ANALYZE` and `ANALYSE` cover `EXPLAIN ANALYZE` in every spelling, `EXPLAIN (FORMAT JSON, ANALYZE)` included, so a data-modifying CTE and `EXPLAIN ANALYZE` of a write, which Studio's own check still misses (libredb/libredb-studio#1862 and #1863), ask.
`REPLACE` is not a deny word: it is a string function in every dialect, and its statement forms are caught by `INTO`, `CREATE`, the separator rule and the first-keyword rule.

Comments are not removed before the scan, because the engines disagree about them, as Studio's own readers record from measurements (`src/lib/sql/update-target.ts:187-226`, `src/lib/sql/optimizer-hints.ts:1-44`): PostgreSQL and SQL Server end a `--` comment at a bare carriage return, MySQL and MariaDB run the body of `/*!` and `/*M!`, and MySQL needs a space after `--`.
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

- The check reads keywords, not what a function or procedure called inside an allowed statement does, so `SELECT pg_terminate_backend(42)` and `SELECT nextval('s')` run without asking.
- A T-SQL statement whose keyword is not on the deny list is not seen.

`WriteConfirmationSheet` (`lib/features/sql_editor/presentation/widgets/`) shows the connection's name and environment, every reason in words, and every line of the text in a lazily built list, never an excerpt, so a write far down a script can be found.
Lines are split at a line feed, a carriage return and a CRLF pair, as the check counts them, so a statement after a bare carriage return shows on a line of its own.
On a connection Studio refuses writes on (`StudioConnection.readOnlyForUser`) it says so, and words the two causes apart: a read grant is one an administrator can raise, and the connection's own read-only flag is the operator's setting.
On a production connection the header is in the error colour and Run stays disabled until the user types the connection's name; that step is the phone's own and applies to every confirmation on such a connection.
The typed name follows Studio's typed confirmation (`src/components/typed-confirm.tsx`): the comparison is exact, an empty field never matches, a connection without a name shows a sentence in place of the field and keeps Run disabled, the field turns autocorrect, suggestions, capitalisation and smart punctuation off, and it is empty each time the sheet opens.
The sheet answers confirmed or cancelled and keeps no statement after it closes; neither the check nor the sheet logs, and no translated string carries the statement.

## Inactivity sign-out

`IdleTimeoutObserver` (`lib/core/security/idle_timeout_observer.dart`) signs the user out after a period without input.

- `AppConfig.idleTimeout` sets the period: `AppConfig.prod()` sets 15 minutes, and `AppConfig.dev()` and `AppConfig.test()` set `null`, which turns it off, so a hot reload or a mocked session is never signed out.
- On iOS a Dart `Timer` pauses while the app is suspended, so the observer also records the wall-clock time on each lifecycle change; a resume past the period signs out at once.
- When the period ends, the user sees a translated snackbar ("You were signed out due to inactivity.") and the router goes to the sign-in page.
  The session ends with `SessionExpiredReason.idleTimeout`, so the log and the UI can tell it from a sign-out the user chose.
- A touch or drag, mouse wheel and trackpad scrolling, and hardware key presses reset the timer, so a user who only scrolls a long page stays signed in.
  Typing on the on-screen keyboard usually does not: the system keyboard sends text through the text input channel, not as key events.
  Moving the mouse without a button pressed does not count, and neither do the key events Flutter synthesizes to match the keyboard state.

Compliance baselines that expect an inactivity timeout include SOC 2 CC6.1, ISO 27001 A.9.4.2 and GDPR Art. 32.
