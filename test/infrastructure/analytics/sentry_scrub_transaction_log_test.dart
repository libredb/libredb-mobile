import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/infrastructure/analytics/sentry_scrub.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

// A transaction and a Sentry log leave the device without passing beforeSend, so each has a scrubber of its own with
// the same policy, as a second layer behind the code that names spans and writes logs.
void main() {
  const jwt = 'eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJhYmMifQ.signaturepart';
  late List<({String type, String json})> sent;
  late Completer<void> logScrubbed;
  late Completer<void> spanScrubbed;

  /// Starts the SDK with the scrubbers, sending spans as [lifecycle] says.
  ///
  /// The SDK hands a log or a streamed span to its scrubber only after adding the device's contexts, which on Linux
  /// runs `cat /proc/meminfo` as a subprocess, so no fixed number of event-queue turns is sure to wait for it.
  /// [logScrubbed] and [spanScrubbed] complete once the scrubber has returned; what is left before the item is in the
  /// buffer that [Sentry.close] flushes runs in microtasks, which one more event-queue turn drains.
  Future<void> start({SentryTraceLifecycle lifecycle = SentryTraceLifecycle.stream}) async {
    sent = [];
    logScrubbed = Completer<void>();
    spanScrubbed = Completer<void>();
    await Sentry.init((options) {
      options.dsn = 'https://public@example.invalid/1';
      options.transport = _CapturingTransport(sent);
      options.tracesSampleRate = 1;
      options.traceLifecycle = lifecycle;
      installSentryScrubbers(options);
      final scrubLog = options.beforeSendLog!;
      options.beforeSendLog = (log, hint) async {
        final scrubbed = await scrubLog(log, hint);
        logScrubbed.complete();
        return scrubbed;
      };
      final scrubSpan = options.beforeSendSpan!;
      options.beforeSendSpan = (span, hint) async {
        await scrubSpan(span, hint);
        spanScrubbed.complete();
      };
    });
    addTearDown(Sentry.close);
  }

  test('installs a transaction and a log scrubber', () async {
    final options = SentryOptions(dsn: 'https://public@example.invalid/1');

    installSentryScrubbers(options);

    expect(options.beforeSendTransaction, isNotNull);
    expect(options.beforeSendSpan, isNotNull);
    expect(options.beforeSendLog, isNotNull);
  });

  // Spans stream one by one by default (SentryTraceLifecycle.stream), through beforeSendSpan.
  test('sends a streamed span without the email or the token in its name or its attributes', () async {
    await start();

    await Sentry.startSpan('GET /users/jane.doe@example.com?token=$jwt', (span) async {
      span.setAttribute('refresh_token', SentryAttribute.string('rt-9f8e7d6c'));
      span.setAttribute('url', SentryAttribute.string('https://api.example.test/users/jane.doe@example.com'));
      span.setAttribute('status', SentryAttribute.int(200));
    });
    await spanScrubbed.future;
    await pumpEventQueue(times: 1);
    await Sentry.close();

    final json = sent.where((item) => item.type == 'span').map((item) => item.json).join();
    expect(json, isNot(contains('jane.doe')));
    expect(json, isNot(contains(jwt)));
    expect(json, isNot(contains('rt-9f8e7d6c')));
    expect(json, contains('/users/[REDACTED_EMAIL]'));
    expect(json, contains('"status":{"value":200'));
  });

  test('sends a transaction without the email or the token in its name, its spans or their data', () async {
    await start(lifecycle: SentryTraceLifecycle.static);
    final transaction = Sentry.startTransaction('/users/jane.doe@example.com', 'navigation');
    final span = transaction.startChild('http.client', description: 'GET /users/jane.doe@example.com?token=$jwt');
    span.setData('refresh_token', 'rt-9f8e7d6c');
    span.setData('url', 'https://api.example.test/users/jane.doe@example.com');
    span.setData('status', 200);
    await span.finish();
    await transaction.finish();
    await Sentry.close();

    final json = sent.singleWhere((item) => item.type == 'transaction').json;
    expect(json, isNot(contains('jane.doe')));
    expect(json, isNot(contains(jwt)));
    expect(json, isNot(contains('rt-9f8e7d6c')));
    // Positive controls: the masked values and the harmless data are still there.
    expect(json, contains('"transaction":"/users/[REDACTED_EMAIL]"'));
    expect(json, contains('"refresh_token":"[REDACTED]"'));
    expect(json, contains('"status":200'));
  });

  test('sends a Sentry log without the email or the token in its body or its attributes', () async {
    await start();
    Sentry.logger.info(
      'signed in jane.doe@example.com with Bearer $jwt',
      attributes: {
        'password': SentryAttribute.string('S3cret!pw'),
        'note': SentryAttribute.string('for jane.doe@example.com'),
        'count': SentryAttribute.int(3),
      },
    );
    await logScrubbed.future;
    await pumpEventQueue(times: 1);
    await Sentry.close();

    final json = sent.where((item) => item.type == 'log').map((item) => item.json).join();
    expect(json, isNot(contains('jane.doe')));
    expect(json, isNot(contains(jwt)));
    expect(json, isNot(contains('S3cret!pw')));
    expect(json, contains('signed in [REDACTED_EMAIL]'));
    expect(json, contains('"count":{"value":3'));
  });
}

/// Keeps the JSON of every item the SDK sends, as it would go over the wire, with its type, and sends nothing.
class _CapturingTransport implements Transport {
  _CapturingTransport(this._sent);

  final List<({String type, String json})> _sent;

  @override
  Future<SentryId?> send(SentryEnvelope envelope) async {
    for (final item in envelope.items) {
      _sent.add((type: item.header.type, json: utf8.decode(await item.dataFactory())));
    }
    return SentryId.newId();
  }
}
