import 'dart:async';

import 'package:libredb_mobile/core/analytics/analytics_service.dart';
import 'package:libredb_mobile/core/errors/app_api_exception.dart';
import 'package:libredb_mobile/infrastructure/studio/studio_errors.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Whether the build carries `--dart-define=SENTRY_DEVICE_CHECK=true`, the device check of `docs/crash-reporting.md`.
///
/// A const, so the AOT compiler drops the check from every build without the define.
const bool sentryDeviceCheckDefined = bool.fromEnvironment('SENTRY_DEVICE_CHECK');

/// The database's words that the check's Studio answer carries, which must not reach Sentry.
const String sentryDeviceCheckDatabaseText = 'permission denied for table device_check_payroll';

/// The statement that the check's Studio answer carries, which must not reach Sentry.
const String sentryDeviceCheckStatement = 'GRANT SELECT ON device_check_payroll TO device_check_reader';

/// The email address the check sends, which Sentry must receive masked.
const String sentryDeviceCheckEmail = 'device.check@example.com';

/// A JWT-shaped token the check sends, which Sentry must receive masked. It signs nothing.
const String sentryDeviceCheckToken = 'eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJkZXZpY2UtY2hlY2sifQ.devicecheckonly';

/// A password-shaped value the check sends under a `password` key, which Sentry must receive masked. The app holds
/// no password of its own — sign-in is Keycloak's — so without the check nothing would ever exercise that key on a
/// device, and the dashboard check could not tell a working `password` rule from a missing one. It opens nothing.
const String sentryDeviceCheckPassword = 'device-check-only-not-a-password';

/// The context the check sets, in the shape `SentryNavigatorObserver` gives a navigation's route arguments: the
/// keys of a browse route next to the four secrets, so the dashboard shows which keys were kept and which masked.
const Map<String, String> _checkContext = {
  'connectionId': 'seed:dev-postgres',
  'email': sentryDeviceCheckEmail,
  'password': sentryDeviceCheckPassword,
  'statement': sentryDeviceCheckStatement,
  'note': 'Bearer $sentryDeviceCheckToken',
};

/// Sends the test event of the device check through the path every uncaught error takes: a user action breadcrumb
/// that carries all four kinds of secret — [sentryDeviceCheckEmail], [sentryDeviceCheckPassword],
/// [sentryDeviceCheckToken] and [sentryDeviceCheckStatement] — and a context of the same four, then, thrown as an
/// uncaught error, the [studioError] of a refused database credential whose answer carries
/// [sentryDeviceCheckDatabaseText], the email and the token in its `error` and [sentryDeviceCheckStatement] in its
/// `fixStatement`, as `ApiClient` reads it.
///
/// The context is there because `contexts` is where `Scope.setContexts` puts what the SDK deprecated `extra` in
/// favour of, and `extra` is the field that once reached Sentry unmasked (PR #398): the dashboard check of
/// `docs/crash-reporting.md` reads that section too, so a scrubber that stops masking it is caught on the device.
/// Without an initialised SDK the call is a no-op, which is what a unit test with a double sees.
///
/// `AppBootstrap` calls it only when [sentryDeviceCheckDefined]. [throwUncaught] throws the error outside any caller,
/// so the zone of the Sentry SDK reports it; a test passes its own.
void runSentryDeviceCheck(IAnalyticsService analytics, {void Function(Object error) throwUncaught = _throwUncaught}) {
  analytics.logUserAction(
    action: 'sentry_device_check',
    target: sentryDeviceCheckEmail,
    parameters: {
      'note': 'Bearer $sentryDeviceCheckToken',
      'password': sentryDeviceCheckPassword,
      'statement': sentryDeviceCheckStatement,
    },
  );
  Sentry.configureScope((scope) => scope.setContexts('device_check', _checkContext));
  final answer = UnauthorizedException(
    '{"code":"AUTH_ERROR","statusCode":401}',
    statusCode: 401,
    errorCode: 'AUTH_ERROR',
    serverMessage: '$sentryDeviceCheckDatabaseText for $sentryDeviceCheckEmail with token $sentryDeviceCheckToken',
    fixStatement: sentryDeviceCheckStatement,
  );
  throwUncaught(studioError(answer));
}

/// Throws [error] from a microtask, which the engine reports to `PlatformDispatcher.onError`, where the Sentry SDK and
/// `CrashReporter` see the error object. An error thrown from a timer callback goes instead to the isolate error
/// listener the Sentry SDK adds, which receives only its text (docs/crash-reporting.md), so the check does not use one.
void _throwUncaught(Object error) => scheduleMicrotask(() => throw error);
