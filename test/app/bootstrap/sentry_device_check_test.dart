import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/app/bootstrap/sentry_device_check.dart';
import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:libredb_mobile/infrastructure/analytics/sentry_analytics_service.dart';
import 'package:libredb_mobile/infrastructure/analytics/sentry_scrub.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../../mocks/mock_classes.dart';

void main() {
  /// What must not leave the device: the database text, the statement, the email and the token of the check.
  final secrets = [
    sentryDeviceCheckDatabaseText,
    sentryDeviceCheckStatement,
    sentryDeviceCheckEmail,
    sentryDeviceCheckToken,
  ];

  test('is off in a build without the SENTRY_DEVICE_CHECK define', () {
    expect(sentryDeviceCheckDefined, isFalse);
  });

  // The const guard is what keeps the check out of a build without the define: the AOT compiler drops the call.
  test('runs from AppBootstrap only behind the define', () {
    final source = File('lib/app/bootstrap/app_bootstrap.dart').readAsStringSync();

    expect(source, contains('if (sentryDeviceCheckDefined) runSentryDeviceCheck(analytics);'));
    expect(RegExp('runSentryDeviceCheck').allMatches(source), hasLength(1));
  });

  test('records a breadcrumb with an email and a token, then throws the AppError of a Studio answer', () {
    final analytics = MockAnalyticsService();
    final thrown = <Object>[];

    runSentryDeviceCheck(analytics, throwUncaught: thrown.add);

    final action = verify(
      () => analytics.logUserAction(
        action: 'sentry_device_check',
        target: captureAny(named: 'target'),
        parameters: captureAny(named: 'parameters'),
      ),
    ).captured;
    expect('$action', allOf(contains(sentryDeviceCheckEmail), contains(sentryDeviceCheckToken)));
    final error = thrown.single as AuthError;
    expect(error.message, allOf(contains(sentryDeviceCheckDatabaseText), contains(sentryDeviceCheckEmail)));
    expect(error.fixStatement, sentryDeviceCheckStatement);
    for (final secret in secrets) {
      expect(error.toString(), isNot(contains(secret)));
    }
  });

  test('sends one uncaught error event without the database text, the statement, the email or the token', () async {
    final sentEvents = <String>[];
    final done = Completer<void>();

    await Sentry.init(
      (options) {
        options.dsn = 'https://public@example.invalid/1';
        options.transport = _CapturingTransport(sentEvents);
        installSentryScrubbers(options);
      },
      appRunner: () {
        runSentryDeviceCheck(SentryAnalyticsService());
        Timer(const Duration(milliseconds: 50), done.complete);
      },
    );
    await done.future;
    await Sentry.close();

    final sent = sentEvents.single;
    for (final secret in secrets) {
      expect(sent, isNot(contains(secret)), reason: 'found "$secret"');
    }
    // Positive controls: the event is the check's, and the breadcrumb is there with its email masked.
    expect(sent, contains('AuthError(code: studio.database_auth)'));
    expect(sent, contains('"message":"sentry_device_check"'));
    expect(sent, contains('[REDACTED_EMAIL]'));
  });
}

/// Keeps the JSON of every event the SDK sends, as it would go over the wire, and sends nothing.
class _CapturingTransport implements Transport {
  _CapturingTransport(this._sentEvents);

  final List<String> _sentEvents;

  @override
  Future<SentryId?> send(SentryEnvelope envelope) async {
    for (final item in envelope.items) {
      if (item.originalObject is SentryEvent) _sentEvents.add(utf8.decode(await item.dataFactory()));
    }
    return SentryId.newId();
  }
}
