# Crash reporting

The app reports errors to Sentry when a production build carries a DSN, and masks personal data and credentials before anything leaves the device.
No DSN is committed: the repository is public, and a committed DSN would let any build of the code send events to the project.
Give it at build time:

```shell
fvm flutter build apk --release --target lib/main/main_prod.dart \
  --dart-define=SENTRY_DSN=https://PUBLIC_KEY@oXXX.ingest.sentry.io/PROJECT_ID
```

- **No DSN, or a dev or test build:** `AppDependencies.createAnalyticsService()` returns `LogAnalyticsService`, errors go to `AppLogger`, and nothing is sent.
- **A DSN in a prod build:** `AppBootstrap.run` starts `SentryFlutter.init` and the analytics service is `SentryAnalyticsService`.
  `SentryNavigatorObserver` records each route change as a breadcrumb; screen views add none of their own, so each navigation is recorded once.

The options are set in `configureSentryOptions` (`lib/app/bootstrap/sentry_start.dart`), including the trace sample rate of `0.2`.

## The release options

Each option below is set explicitly on both SDKs, even where it equals today's default, so an SDK upgrade that changes a default cannot start sending more.
The Dart side sets them in `configureSentryOptions`, the Android side in `NativeSentry.configure` (`android/app/src/main/kotlin/org/libredb/mobile/NativeSentry.kt`), and a unit test on each side starts from the unsafe value and fails when one is not set.

| Option | Dart (`SentryFlutterOptions`) | Android (`SentryAndroidOptions`) |
| --- | --- | --- |
| Default personal data | `sendDefaultPii = false` | `isSendDefaultPii = false` |
| Screenshot attachment | `attachScreenshot = false` | `isAttachScreenshot = false` |
| View hierarchy attachment | `attachViewHierarchy = false` | `isAttachViewHierarchy = false` |
| Request bodies | `maxRequestBodySize = MaxRequestBodySize.never` | `maxRequestBodySize = RequestSize.NONE` |
| Session Replay | `replay.sessionSampleRate = 0`, `replay.onErrorSampleRate = 0` | `sessionReplay.sessionSampleRate = 0.0`, `sessionReplay.onErrorSampleRate = 0.0` |
| Network bodies in a replay | `replay.networkCaptureBodies = false` | `sessionReplay.isNetworkCaptureBodies = false` |
| Print breadcrumbs | `enablePrintBreadcrumbs = false` | Not applicable |

Sentry Logs come only from an explicit call of the SDK's logger, and the app makes none.
sentry_flutter 10 has no option to turn logs off and collects none by itself, and sentry-android keeps `logs.isEnabled` on, as sentry_flutter would set it, for such explicit calls.
No `AppLogger` line becomes a log or a breadcrumb: print breadcrumbs are off, and `test/infrastructure/analytics/sentry_logs_test.dart` logs a line at every level inside the Sentry zone and finds none of them in what the SDK sends.
No logcat line becomes a log: only the Sentry Android Gradle plugin rewrites `android.util.Log` calls into Sentry logs, and `test/architecture/sentry_native_scrub_patterns_test.dart` fails when that plugin or the `sentry_logging` package comes in.

## Studio errors

Only uncaught errors reach Sentry; a repository returns a `Failure` and reports nothing.
An uncaught error is sent with its `toString`, and the scrubber knows emails and credentials but cannot tell a database's words or a statement from other text.
So the types the Studio layer builds keep that text out of their `toString`:

- An `AppException` from `ApiClient` prints the error body without the members Studio fills with database text and statements (`error`, `details` and `fixStatement`); `serverMessage`, `fixStatement` and `position` keep them for the screen that shows them.
- An `AppError` prints its type and its code, never its message, which for a Studio failure is the server's own words.

`test/app/analytics/crash_reporter_studio_error_test.dart` sends both, built from a Studio answer that carries a database error, a statement, an email and a token, through `CrashReporter` and the scrubber, and finds none of them in the event or in the log.

## What the Dart hooks mask

`sentryBeforeSend` (`lib/infrastructure/analytics/sentry_scrub.dart`) changes every event before it leaves the device:

- The `Authorization`, `Cookie` and `Set-Cookie` headers are dropped, whatever their case.
- Any other header whose name contains `password`, `otp`, `token`, `secret`, `authorization` or an api-key name (`api-key`, `api_key`, `apikey`), or is an OpenID Connect key, such as `X-Auth-Token`, `Proxy-Authorization` or `X-Api-Key`, keeps its name and has its whole value replaced with `[REDACTED]`.
- A tag named like a credential body key has its whole value masked, and every other tag value has its email addresses, JWTs and the secrets `maskSecrets` finds masked.
- The user's id, username, email, IP address and name have their email addresses, JWTs and secrets masked, and the user's data is masked like a breadcrumb's data.
- Every other request header value and every `request.env` value has its email addresses, JWTs and secrets masked; the header names are kept.
- The values of body keys whose names contain `password`, `otp`, `token` or `secret` (case-insensitive substring) are replaced with `[REDACTED]` at any depth.
- Email addresses and JWT-shaped strings (three base64url segments) in exception values, the event message and the request body are replaced with `[REDACTED_EMAIL]` and `[REDACTED_JWT]`.
  Only an HTTP integration such as `sentry_dio` attaches a request body; the app has none today.
- Email addresses and JWTs in the request URL (`request.url`, query string, fragment) and the transaction name are masked the same way.
- In the same text, the value of a JSON member or a `name=value` pair whose name contains one of those words, and the credentials of a `Bearer` authorization, are replaced with `[REDACTED]` by `maskSecrets`, which `AppLogger` also runs over every line it prints.

`sentryBeforeBreadcrumb` masks the email addresses, JWTs and secrets in the message and the data of every breadcrumb when it is recorded, and the value of every credential key of the data.
That covers the breadcrumbs of `SentryAnalyticsService`, the navigation breadcrumbs, and the http and ui breadcrumbs that `sentry_dio` or `SentryUserInteractionWidget` would add.
`installSentryScrubbers` installs both hooks, and `configureSentryOptions` calls it.
It also installs a second layer for what leaves the device without passing `beforeSend`, with the same policy: `sentryBeforeSendSpan` masks the name and the string attributes of each span sent on its own (the SDK's default trace lifecycle), `sentryBeforeSendTransaction` masks a transaction's event fields and the description and data of its spans, and `sentryBeforeSendLog` masks the body and the string attributes of a Sentry log.
It also turns print breadcrumbs off, so no printed line and no `AppLogger` line becomes a breadcrumb: a scrubber cannot find a password or a code in free text.

The policy itself, which names and shapes count as sensitive, is in `lib/core/security/sensitive_data_scrubber.dart`, shared with the log, so the two exits cannot drift apart.
Review it whenever the app starts handling a new kind of personal data.

## The native SDKs

The native Sentry SDKs record breadcrumbs and send events of their own (activity and app lifecycle, system events, Java and Kotlin exceptions, ANR events, native crash reports), and none of them pass through the Dart hooks.

On Android the host app starts sentry-android itself (`MainApplication.kt` and `NativeSentry.kt` under `android/app/src/main/kotlin`) with `beforeSend` and `beforeBreadcrumb` hooks that mask them with a Kotlin copy of the same rules (`NativeSentryScrubber.kt`), and the Dart side turns `autoInitializeNativeSdk` off on Android only.
`test/architecture/sentry_native_scrub_patterns_test.dart` fails when the Kotlin patterns drift from the Dart ones, and the fixtures in `test/fixtures/` run both in the Dart tests and in the Android JVM unit tests:

```shell
cd android && ./gradlew :app:testDebugUnitTest -Ptarget=lib/main/main_prod.dart
```

Gradle needs JDK 17 there, and the Gradle wrapper is not committed: any Flutter Android build writes it, for example `fvm flutter build apk --config-only --target lib/main/main_prod.dart`.
The lifecycle breadcrumbs of sentry-android keep their `state` (such as `resumed` or `foreground`); a copy that Sentry merges into a Dart event still shows it masked.

| Platform | Dart events and breadcrumbs | Native breadcrumbs | Native events and crash reports |
| --- | --- | --- | --- |
| Android | Scrubbed | Scrubbed | Scrubbed |
| iOS | Scrubbed | Not scrubbed | Not scrubbed |

Native scrubbing is not done on iOS yet: sentry_flutter starts sentry-cocoa there, and what it records itself leaves the device unmasked.
Until a native scrubber covers iOS (roadmap M6), do not give an iOS release build a Sentry DSN.
Sentry's server-side data scrubbing (Advanced Data Scrubbing in the project settings) is a useful complement on every platform, but it runs after the data has left the device, so it does not replace the hooks.

On Android, Gradle passes the DSN to the native SDK only for a `lib/main/main_prod.dart` build (`android/app/build.gradle.kts`), the only entry point that selects the prod environment in which the Dart side starts Sentry.
Renaming that entry point means changing the check there too.
When the two disagree, or the host app does not answer the check, the app throws a `StateError` at start in a debug or profile build, and a release build logs the error and runs exactly as without a DSN: no Sentry SDK and the log-only analytics.
A native option set in `configureSentryOptions` does not reach the Android SDK, so set it in `NativeSentry.kt` as well; Session Replay would need its recorder wired there before it can be turned on.

## The device check

A release build with a DSN can send one test event and one native crash, so the check needs no code change.
Both exist only in a build with `--dart-define=SENTRY_DEVICE_CHECK=true`: the Dart check sits behind a `const` the compiler drops without the define, and Gradle writes `BuildConfig.SENTRY_DEVICE_CHECK` as true only for a `lib/main/main_prod.dart` build with it.
A build without the define never reads the intent extra: `SentryDeviceCheck.crashIfAsked` tests the constant first, so the compiler drops the read.
Never ship a build with that define.

1. Build and install a release APK with the DSN of a test project:

   ```shell
   fvm flutter build apk --release --target lib/main/main_prod.dart \
     --dart-define-from-file=<your prod defines> \
     --dart-define=SENTRY_DSN=<test project DSN> --dart-define=SENTRY_DEVICE_CHECK=true
   adb -s <serial> install -r build/app/outputs/flutter-apk/app-release.apk
   ```

2. Start the app.
   Right after it starts, it records a user action breadcrumb with the email `device.check@example.com` and a JWT-shaped token, then throws, from a microtask, an uncaught `AuthError` built by `studioError` from a refused database credential whose answer carries the database text `permission denied for table device_check_payroll`, the email, the token, and the statement `GRANT SELECT ON device_check_payroll TO device_check_reader` (`lib/app/bootstrap/sentry_device_check.dart`).
   It does not throw from a timer: on an Android release build an error thrown in a root-zone timer callback reached neither `PlatformDispatcher.onError` nor the log.
3. Crash the native side:

   ```shell
   adb -s <serial> shell am start -S -n org.libredb.mobile/.MainActivity --ez sentry_device_check_native_crash true
   ```

   `SentryDeviceCheck.kt` throws a `RuntimeException` that names the same email and a `Bearer` token, and sentry-android sends it on the next start.
4. Start the app once more, so the crash report is sent.
5. In Sentry, open both events and confirm that neither carries the email, the token, `device_check_payroll` or the statement: the Dart event shows `AuthError(code: studio.database_auth)` and a breadcrumb whose target is `[REDACTED_EMAIL]`, and the native crash shows `[REDACTED_EMAIL]` and `Bearer [REDACTED_JWT]`.

## The user's steps

These steps need the Sentry account, so they are the user's and not the repository's:

- Create the Sentry project for the app.
- Turn on its server-side data scrubbing (Data Scrubber, and Advanced Data Scrubbing rules for anything the app must never store), as a second layer behind the hooks.
- Put the DSN into the CI secrets, from which the release build passes it as `SENTRY_DSN` (#194); never commit it, and never write it into an issue, a pull request or a log.

