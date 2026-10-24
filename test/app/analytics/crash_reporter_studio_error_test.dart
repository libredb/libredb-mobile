import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/app/analytics/crash_reporter.dart';
import 'package:libredb_mobile/core/errors/app_api_exception.dart';
import 'package:libredb_mobile/infrastructure/analytics/sentry_analytics_service.dart';
import 'package:libredb_mobile/infrastructure/analytics/sentry_scrub.dart';
import 'package:libredb_mobile/infrastructure/http/token_rotation.dart';
import 'package:libredb_mobile/infrastructure/config/environment.dart';
import 'package:libredb_mobile/infrastructure/http/api_client.dart';
import 'package:libredb_mobile/infrastructure/studio/studio_errors.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../../support/printed_lines.dart';
import '../../support/test_env.dart';

/// The database's own words, as Studio relays them in `error` and `details.detail` (`src/lib/api/error-body.ts`).
const _databaseText = 'relation "payroll_secret" does not exist';
const _databaseDetail = 'Table payroll_secret was dropped by role finance_admin';

/// The statement the request ran, which the database repeats in its error and Studio in `fixStatement`.
const _statement = 'SELECT salary FROM payroll_secret';
const _fixStatement = 'GRANT CONNECT ON DATABASE payroll_secret TO mobile_reader';

const _jwt = 'eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJhYmMifQ.signaturepart';

// An uncaught error built from a Studio answer goes to Sentry through CrashReporter and SentryAnalyticsService, and
// the scrubber knows emails and tokens but not a database's words or a statement. So the error itself must not print
// them: neither what ApiClient throws nor the AppError that studioError builds from it.
void main() {
  late List<String> sentEvents;
  late ApiClient client;
  late _StudioAdapter adapter;

  setUp(() async {
    sentEvents = [];
    await Sentry.init((options) {
      options.dsn = 'https://public@example.invalid/1';
      options.transport = _CapturingTransport(sentEvents);
      installSentryScrubbers(options);
    });
    addTearDown(Sentry.close);

    client = ApiClient(
      tokenRotation: const RefusingTokenRotation(),
      appConfig: const AppConfig(
        environment: Environment.prod,
        apiBaseUrl: 'https://studio.example.test/api',
        certificatePins: [],
        idleTimeout: null,
      ),
    );
    adapter = _StudioAdapter();
    client.instance.httpClientAdapter = adapter;
    TestEnv.authenticate();
  });

  /// What ApiClient throws for [body] answered with [status] to a statement run.
  Future<AppException> studioFailure(int status, Map<String, Object?> body) async {
    adapter.answer(status, jsonEncode(body));
    try {
      await client.post('/db/query', {'connectionId': 'seed:pg', 'sql': _statement});
    } on AppException catch (e) {
      return e;
    }
    fail('the request did not fail');
  }

  /// The events Sentry sends and the lines the app prints for [error] as an uncaught platform error.
  Future<({String event, List<String> lines})> reportUncaught(Object error) async {
    final previousPlatform = PlatformDispatcher.instance.onError;
    final previousFlutter = FlutterError.onError;
    try {
      final lines = await printedLines(() {
        CrashReporter.install(SentryAnalyticsService());
        PlatformDispatcher.instance.onError!(error, StackTrace.current);
      });
      // SentryAnalyticsService does not wait for the capture it starts.
      await pumpEventQueue();
      return (event: sentEvents.single, lines: lines);
    } finally {
      PlatformDispatcher.instance.onError = previousPlatform;
      FlutterError.onError = previousFlutter;
    }
  }

  final queryError = {
    'error': '$_databaseText in "$_statement" for jane.doe@example.com',
    'code': 'QUERY_ERROR',
    'statusCode': 400,
    'details': {'position': 15, 'detail': _databaseDetail},
  };
  final authError = {
    'error': 'password authentication failed for user "mobile_reader", token $_jwt',
    'code': 'AUTH_ERROR',
    'statusCode': 401,
    'fixStatement': _fixStatement,
  };

  void expectNoStudioText(String text) {
    for (final secret in [
      _databaseText,
      _databaseDetail,
      _statement,
      _fixStatement,
      'payroll_secret',
      'mobile_reader',
      'jane.doe',
      _jwt,
    ]) {
      expect(text, isNot(contains(secret)), reason: 'found "$secret"');
    }
  }

  for (final (name, status, body, code, type) in [
    ('QUERY_ERROR', 400, queryError, 'studio.query_error', 'ValidationError'),
    ('AUTH_ERROR', 401, authError, 'studio.database_auth', 'AuthError'),
  ]) {
    test('sends the ApiClient exception of a Studio $name without its database text or statement', () async {
      final exception = await studioFailure(status, body);
      expect(exception.serverMessage, contains('payroll_secret').or(contains('mobile_reader')));

      final (:event, :lines) = await reportUncaught(exception);

      expectNoStudioText(event);
      expectNoStudioText(lines.join('\n'));
      // Positive controls: the event and the log line still name the failure.
      expect(event, contains('"statusCode\\":$status'));
      expect(lines.join('\n'), contains('PlatformError'));
    });

    test('sends the AppError of a Studio $name without its database text or statement', () async {
      final error = studioError(await studioFailure(status, body));
      expect(error.message, contains('payroll_secret').or(contains('mobile_reader')));

      final (:event, :lines) = await reportUncaught(error);

      expectNoStudioText(event);
      expectNoStudioText(lines.join('\n'));
      expect(event, contains('$type(code: $code)'));
    });
  }
}

extension on Matcher {
  Matcher or(Matcher other) => anyOf(this, other);
}

/// Answers every request with the next queued Studio answer.
class _StudioAdapter implements HttpClientAdapter {
  final _answers = <(int, String)>[];

  void answer(int status, String body) => _answers.add((status, body));

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final (status, body) = _answers.removeAt(0);
    return ResponseBody.fromString(
      body,
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
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
