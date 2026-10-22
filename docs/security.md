# Security

This page describes the protections inside the app: how it stores tokens, how it checks the server's certificate, how it hides sensitive screens and when it signs an idle user out.
What the app sends to Studio and what it never holds is in [architecture.md](architecture.md#security), and what leaves the device in a crash report is in [crash-reporting.md](crash-reporting.md).

## Token storage

The provider's tokens live in `flutter_secure_storage` (`lib/infrastructure/storage/secure_storage.dart`).
On Android it encrypts them with AES-GCM under an RSA-OAEP wrapped Android Keystore key.
On iOS the Keychain accessibility is pinned to `first_unlock_this_device`, so a background refresh can read the tokens while the device is locked, and they never move to another device through a backup or iCloud Keychain.

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
