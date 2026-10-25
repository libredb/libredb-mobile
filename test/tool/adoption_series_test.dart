import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/adoption/adoption_series.dart';

/// The derivation that `scripts/generate_adoption.sh` runs, over a recorded copy of the three series.
///
/// The fixtures under `test/fixtures/adoption/` are trimmed from the real files but keep every property the
/// derivation has to survive: several metrics in one file, a `date` that repeats, and an order in which neither the
/// first nor the last line of a file holds the answer. A reader that trusts file order fails these tests.
void main() {
  String read(String name) => File('test/fixtures/adoption/$name.jsonl').readAsStringSync();

  group('newestValueOf', () {
    test('reads the newest measurement of the metric, not the first line of the file', () {
      // The first line of engines.jsonl is engines.shipped = 15, the series' oldest entry.
      expect(newestValueOf(read('engines'), 'engines.shipped'), 42);
    });

    test('reads the newest measurement of the metric, not the last line of the file', () {
      // The last line of channels.jsonl is channels.deprecated, a different metric.
      expect(newestValueOf(read('channels'), 'channels.total'), 48);
    });

    test('ignores the other metrics sharing the file', () {
      expect(newestValueOf(read('engines'), 'engines.connectable'), isNot(42));
      expect(newestValueOf(read('channels'), 'channels.live'), isNot(48));
    });

    test('breaks a tie on the same date with measured_at', () {
      const sameDate =
          '{"metric":"m","date":"2026-10-21","value":47,"measured_at":"2026-10-21T05:06:25.605Z"}\n'
          '{"metric":"m","date":"2026-10-21","value":48,"measured_at":"2026-10-21T21:00:33.269Z"}\n';
      expect(newestValueOf(sameDate, 'm'), 48);
      // The same two lines in the other order must give the same answer.
      final reversed = sameDate.trim().split('\n').reversed.join('\n');
      expect(newestValueOf(reversed, 'm'), 48);
    });

    test('returns null for a metric that is not in the series', () {
      expect(newestValueOf(read('engines'), 'engines.vanished'), isNull);
    });

    test('skips a blank or unparseable line instead of throwing', () {
      const withJunk =
          '\n{"metric":"m","date":"2026-01-01","value":7,"measured_at":"2026-01-01T00:00:00Z"}\nnot json\n';
      expect(newestValueOf(withJunk, 'm'), 7);
    });
  });

  group('distinctMetricCount', () {
    test('counts the vendor sites, which no line stores', () {
      expect(distinctMetricCount(read('listings'), 'listings.'), 31);
    });

    test('counts a metric once however many measurements it has', () {
      const repeated =
          '{"metric":"listings.a","date":"2026-01-01","value":1,"measured_at":"2026-01-01T00:00:00Z"}\n'
          '{"metric":"listings.a","date":"2026-02-01","value":2,"measured_at":"2026-02-01T00:00:00Z"}\n'
          '{"metric":"listings.b","date":"2026-01-01","value":1,"measured_at":"2026-01-01T00:00:00Z"}\n';
      expect(distinctMetricCount(repeated, 'listings.'), 2);
    });

    test('counts only the metrics under the prefix', () {
      expect(distinctMetricCount(read('engines'), 'listings.'), 0);
    });
  });

  group('adoptionFiguresFrom', () {
    test('derives the three figures the onboarding shows', () {
      final figures = adoptionFiguresFrom(
        engines: read('engines'),
        channels: read('channels'),
        listings: read('listings'),
      );
      expect(figures, {'engines': 42, 'channels': 48, 'listings': 31});
    });

    test('throws when a metric the onboarding needs has vanished from its series', () {
      // A silent zero would be shown to a user as "0 engines"; the script must fail instead.
      expect(
        () => adoptionFiguresFrom(engines: '', channels: read('channels'), listings: read('listings')),
        throwsA(isA<StateError>()),
      );
    });
  });
}
