// The SDK deprecates `extra` in favour of `contexts` and still sends it, so an event still carries both and these
// tests still set both. See the comment at the call site in sentry_scrub.dart.
// ignore_for_file: deprecated_member_use

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/app/bootstrap/sentry_device_check.dart';
import 'package:libredb_mobile/core/errors/app_api_exception.dart';
import 'package:libredb_mobile/infrastructure/analytics/sentry_analytics_service.dart';
import 'package:libredb_mobile/infrastructure/analytics/sentry_scrub.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// The four kinds of secret the device check of `docs/crash-reporting.md` puts into one event: an address, a
/// password, a bearer token and a statement. None of them may appear in the JSON the transport sends, through any
/// of the fields a real event carries. They are the check's own values, so this test and the dashboard check read
/// the same four strings, and the repository holds no second set of secret-shaped constants.
const String email = sentryDeviceCheckEmail;
const String password = sentryDeviceCheckPassword;
const String token = sentryDeviceCheckToken;
const String statement = sentryDeviceCheckStatement;

/// The secrets as a repository or a Studio answer carries them: under their own keys, which is the only shape a
/// scrubber can find. A password in free text has none, which is why no line may ever write one.
const String secretJson = '{"password":"$password","statement":"$statement","email":"$email","note":"Bearer $token"}';

Map<String, dynamic> secretMap() => <String, dynamic>{
  'password': password,
  'statement': statement,
  'email': email,
  'note': 'Bearer $token',
};

void main() {
  late List<String> sentEvents;

  setUp(() async {
    sentEvents = [];
    await Sentry.init((options) {
      options.dsn = 'https://public@example.invalid/1';
      options.transport = _CapturingTransport(sentEvents);
      installSentryScrubbers(options);
    });
    addTearDown(Sentry.close);
  });

  // One event through every field a real crash report carries, with the SDK's own hooks installed: what the owner
  // confirms in the Sentry dashboard (docs/crash-reporting.md, "What the dashboard must show") is this JSON.
  test('an event through every exit leaves with the email, the password, the token and the statement masked', () async {
    SentryAnalyticsService().logUserAction(
      action: 'sentry_device_check',
      target: email,
      parameters: {'password': password, 'statement': statement, 'note': 'Bearer $token'},
    );
    await Sentry.configureScope((scope) async {
      await scope.setUser(SentryUser(id: email, username: email, email: email));
      scope.setTag('last_user', email);
      // Where a navigation's route arguments land (PR #398), and the context that the SDK's own documentation
      // offers as the replacement for the deprecated `extra`.
      await scope.setExtra('route_settings_arguments', secretMap());
      await scope.setContexts('studio_request', secretMap());
    });

    await Sentry.captureEvent(
      SentryEvent(
        message: SentryMessage('device check failed: $secretJson'),
        exceptions: [
          SentryException(
            type: 'StudioApiException',
            value: 'Unauthorized: {"path":"/api/users/$email"} Authorization: Bearer $token',
          ),
        ],
        request: SentryRequest(
          url: 'https://studio.example.test/api/users/$email',
          queryString: 'email=$email&access_token=$token',
          headers: {'Authorization': 'Bearer $token', 'X-Debug-Context': token},
          data: secretMap(),
        ),
      ),
    );

    final sent = sentEvents.single;
    for (final secret in [email, password, token, statement]) {
      expect(sent, isNot(contains(secret)), reason: 'the event carries "$secret"');
    }
    // Positive controls, one per exit, so the test cannot pass by sending nothing.
    expect(sent, contains('"formatted":"device check failed: {\\"password\\":\\"[REDACTED]\\"'), reason: 'message');
    expect(
      sent,
      contains('"value":"Unauthorized: {\\"path\\":\\"/api/users/[REDACTED_EMAIL]\\"}'),
      reason: 'exception',
    );
    expect(sent, contains('"X-Debug-Context":"[REDACTED_JWT]"'), reason: 'request headers');
    expect(sent, isNot(contains('"Authorization"')), reason: 'the Authorization header is dropped, not masked');
    expect(sent, contains('"last_user":"[REDACTED_EMAIL]"'), reason: 'tags');
    expect(sent, contains('"id":"[REDACTED_EMAIL]"'), reason: 'user');
    expect(sent, contains('"route_settings_arguments":{"password":"[REDACTED]"'), reason: 'extra');
    expect(sent, contains('"studio_request":{"password":"[REDACTED]"'), reason: 'contexts');
    expect(sent, contains('"message":"sentry_device_check"'), reason: 'breadcrumb');
  });

  // An event may carry its own breadcrumbs: the scope keeps the ones the event brought and adds none of its own
  // (Scope.applyToEvent), and those never passed beforeBreadcrumb. The Kotlin scrubber masks event.breadcrumbs;
  // the Dart one must too, which is the gap PR #398 found in `extra`.
  test('masks the breadcrumbs an event carries itself, which no beforeBreadcrumb hook ever saw', () async {
    await Sentry.captureEvent(
      SentryEvent(
        message: SentryMessage('device check'),
        breadcrumbs: [
          Breadcrumb(category: 'ui.action', message: 'opened $email', data: {'password': password, 'note': token}),
        ],
      ),
    );

    final sent = sentEvents.single;
    for (final secret in [email, password, token]) {
      expect(sent, isNot(contains(secret)), reason: 'the event carries "$secret"');
    }
    expect(sent, contains('"message":"opened [REDACTED_EMAIL]"'));
    expect(sent, contains('"password":"[REDACTED]"'));
  });

  // The exception a repository turns into a Failure, thrown uncaught instead: the statement and the database text
  // of a Studio answer travel in its message, and neither may reach Sentry.
  test('masks the statement and the database text of a Studio answer thrown as an uncaught error', () async {
    await Sentry.captureException(
      UnauthorizedException(
        '{"code":"AUTH_ERROR","fixStatement":"$statement","detail":"permission denied for $email"}',
        statusCode: 401,
        errorCode: 'AUTH_ERROR',
      ),
    );

    final sent = sentEvents.single;
    expect(sent, isNot(contains(statement)));
    expect(sent, isNot(contains(email)));
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
