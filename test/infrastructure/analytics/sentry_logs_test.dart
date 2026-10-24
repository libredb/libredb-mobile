import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/core/logging/app_logger.dart';
import 'package:libredb_mobile/infrastructure/analytics/sentry_scrub.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

// Sentry Logs come only from an explicit Sentry.logger call. AppLogger prints each line, and a Sentry zone that turned
// printed lines into breadcrumbs, or an integration that forwarded them as logs, would send free text that no scrubber
// can clean. The app runs in the zone that SentryFlutter.init gives it, which Sentry.init with an appRunner takes too.
void main() {
  test('sends no AppLogger line, at any level, as a Sentry log or breadcrumb', () async {
    AppLogger.configure(isProduction: false);
    final sent = <({String type, String json})>[];
    final printed = <String>[];
    final done = Completer<void>();

    await Sentry.init(
      (options) {
        options.dsn = 'https://public@example.invalid/1';
        options.transport = _CapturingTransport(sent);
        installSentryScrubbers(options);
      },
      appRunner: () async {
        await runZoned(
          () async {
            final log = AppLogger.getLogger('LogsCheck');
            log.trace('line-at-trace');
            log.debug('line-at-debug');
            log.info('line-at-info');
            log.warn('line-at-warn');
            log.error('line-at-error');
            // Positive controls: an explicit Sentry log is sent, and an error event carries the scope's breadcrumbs.
            Sentry.logger.info('explicit-sentry-log');
            await Sentry.addBreadcrumb(Breadcrumb(message: 'explicit-breadcrumb'));
            await Sentry.captureException(StateError('a later error'));
          },
          zoneSpecification: ZoneSpecification(
            print: (self, parent, zone, line) {
              printed.add(line);
              parent.print(zone, line);
            },
          ),
        );
        done.complete();
      },
    );
    await done.future;
    await Sentry.close();

    // AppLogger printed a line at every level it passes in a debug configuration; trace is below the lowest level it
    // prints in any configuration.
    for (final level in ['debug', 'info', 'warn', 'error']) {
      expect(printed, contains(contains('line-at-$level')));
    }
    final logs = [
      for (final item in sent)
        if (item.type == 'log') item.json,
    ];
    final events = [
      for (final item in sent)
        if (item.type == 'event') item.json,
    ];
    expect(logs.join(), contains('explicit-sentry-log'));
    expect(events.single, contains('explicit-breadcrumb'));
    for (final item in sent) {
      expect(item.json, isNot(contains('line-at-')), reason: 'a ${item.type} item carries an AppLogger line');
    }
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
