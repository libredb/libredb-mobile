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
The fix is tracked in the template's [cevheri/flutter-bloc-advanced#177](https://github.com/cevheri/flutter-bloc-advanced/issues/177); until it lands here, do not give an iOS release build a Sentry DSN (roadmap M6).
Sentry's server-side data scrubbing (Advanced Data Scrubbing in the project settings) is a useful complement on every platform, but it runs after the data has left the device, so it does not replace the hooks.

On Android, Gradle passes the DSN to the native SDK only for a `lib/main/main_prod.dart` build (`android/app/build.gradle.kts`), the only entry point that selects the prod environment in which the Dart side starts Sentry.
Renaming that entry point means changing the check there too.
When the two disagree, or the host app does not answer the check, the app throws a `StateError` at start in a debug or profile build, and a release build logs the error and runs exactly as without a DSN: no Sentry SDK and the log-only analytics.
A native option set in `configureSentryOptions` does not reach the Android SDK, so set it in `NativeSentry.kt` as well; Session Replay would need its recorder wired there before it can be turned on.
