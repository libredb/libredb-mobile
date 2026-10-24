import 'dart:async';

import 'package:libredb_mobile/core/analytics/analytics_service.dart';
import 'package:libredb_mobile/core/errors/app_api_exception.dart';
import 'package:libredb_mobile/infrastructure/studio/studio_errors.dart';

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

/// Sends the test event of the device check through the path every uncaught error takes: a user action breadcrumb
/// that carries [sentryDeviceCheckEmail] and [sentryDeviceCheckToken], then, thrown as an uncaught error, the
/// [studioError] of a refused database credential whose answer carries [sentryDeviceCheckDatabaseText], the email and
/// the token in its `error` and [sentryDeviceCheckStatement] in its `fixStatement`, as `ApiClient` reads it.
///
/// `AppBootstrap` calls it only when [sentryDeviceCheckDefined]. [throwUncaught] throws the error outside any caller,
/// so the zone of the Sentry SDK reports it; a test passes its own.
void runSentryDeviceCheck(IAnalyticsService analytics, {void Function(Object error) throwUncaught = _throwUncaught}) {
  analytics.logUserAction(
    action: 'sentry_device_check',
    target: sentryDeviceCheckEmail,
    parameters: {'note': 'Bearer $sentryDeviceCheckToken'},
  );
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
/// `CrashReporter` see it. An error thrown from a timer callback reached neither on an Android release build (Flutter
/// 3.47.7), so the check does not use one.
void _throwUncaught(Object error) => scheduleMicrotask(() => throw error);
