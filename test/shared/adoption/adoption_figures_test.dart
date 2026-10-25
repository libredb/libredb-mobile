import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/shared/adoption/adoption_figures.dart';

/// What the app reads from `assets/adoption.json`, which `scripts/generate_adoption.sh` writes and commits.
///
/// The app never fetches these figures, so nothing here touches the network. What it has to survive is an asset that
/// is missing, truncated or written by an older version of the script: onboarding shows the fallback rather than a
/// zero, because "0 engines" reaches a user as a claim about the product.
void main() {
  group('AdoptionFigures.fromJson', () {
    test('reads the three figures and the day they were measured', () {
      final figures = AdoptionFigures.fromJson(const {
        'engines': 42,
        'channels': 48,
        'listings': 31,
        'measuredOn': '2026-10-25',
      });
      expect(figures.engines, 42);
      expect(figures.channels, 48);
      expect(figures.listings, 31);
      expect(figures.measuredOn, '2026-10-25');
    });

    test('falls back when a figure is missing', () {
      final figures = AdoptionFigures.fromJson(const {'engines': 42, 'measuredOn': '2026-10-25'});
      expect(figures, AdoptionFigures.fallback);
    });

    test('falls back when a figure is not a whole number', () {
      for (final bad in <Object?>['42', 42.5, null, true]) {
        final figures = AdoptionFigures.fromJson({
          'engines': bad,
          'channels': 48,
          'listings': 31,
          'measuredOn': '2026-10-25',
        });
        expect(figures, AdoptionFigures.fallback, reason: 'engines: $bad');
      }
    });

    test('falls back on a figure of zero, which would read as a claim about the product', () {
      final figures = AdoptionFigures.fromJson(const {
        'engines': 0,
        'channels': 48,
        'listings': 31,
        'measuredOn': '2026-10-25',
      });
      expect(figures, AdoptionFigures.fallback);
    });

    test('keeps the figures when the measured day is missing, which decides nothing', () {
      final figures = AdoptionFigures.fromJson(const {'engines': 42, 'channels': 48, 'listings': 31});
      expect(figures.engines, 42);
      expect(figures.measuredOn, isNull);
    });
  });

  group('AdoptionFigures.parse', () {
    test('reads the asset the script writes', () {
      final figures = AdoptionFigures.parse('{"engines":42,"channels":48,"listings":31,"measuredOn":"2026-10-25"}');
      expect(figures.engines, 42);
      expect(figures.measuredOn, '2026-10-25');
    });

    test('falls back on content that is not JSON, so a truncated asset never throws', () {
      expect(AdoptionFigures.parse('{"engines":42,'), AdoptionFigures.fallback);
      expect(AdoptionFigures.parse(''), AdoptionFigures.fallback);
      expect(AdoptionFigures.parse('[1,2,3]'), AdoptionFigures.fallback);
    });
  });

  group('the committed asset', () {
    test('is what the script writes and the app can read', () async {
      // Reads assets/adoption.json through the bundle, as the app will. It is committed, so this fails if someone
      // edits it by hand into a shape AdoptionFigures refuses, or forgets to register it in pubspec.yaml.
      TestWidgetsFlutterBinding.ensureInitialized();
      final source = await rootBundle.loadString('assets/adoption.json');
      final figures = AdoptionFigures.parse(source);
      expect(figures.isFallback, isFalse, reason: 'the committed asset must parse, not fall back');
      expect(figures.engines, greaterThan(0));
      expect(figures.channels, greaterThan(0));
      expect(figures.listings, greaterThan(0));
      expect(figures.measuredOn, matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')));
    });
  });

  group('the fallback', () {
    test('carries figures that were true when it was written, never zero', () {
      expect(AdoptionFigures.fallback.engines, greaterThan(0));
      expect(AdoptionFigures.fallback.channels, greaterThan(0));
      expect(AdoptionFigures.fallback.listings, greaterThan(0));
    });

    test('says it is a fallback, so a caller can tell it from a read asset', () {
      expect(AdoptionFigures.fallback.isFallback, isTrue);
      expect(AdoptionFigures.parse('{"engines":42,"channels":48,"listings":31}').isFallback, isFalse);
    });
  });
}
