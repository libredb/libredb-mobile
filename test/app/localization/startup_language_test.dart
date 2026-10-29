import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/app/localization/startup_language.dart';

/// The language the first run opens in, before anything is stored on the device.
///
/// A pure function, so these cases need no binding and no platform channel: the device list goes in, a language code
/// comes out. `[en, tr]` stands in for `S.delegate.supportedLocales`, which is what the app passes.
void main() {
  const supported = [Locale('en'), Locale('tr')];

  group('resolveStartupLanguage', () {
    test('follows a Turkish phone, region and all', () {
      expect(resolveStartupLanguage(const [Locale('tr', 'TR')], supported), 'tr');
    });

    test('follows a Turkish phone that names no region', () {
      expect(resolveStartupLanguage(const [Locale('tr')], supported), 'tr');
    });

    test('follows an English phone', () {
      expect(resolveStartupLanguage(const [Locale('en', 'US')], supported), 'en');
    });

    test('falls back to English for a language the app does not have', () {
      expect(resolveStartupLanguage(const [Locale('de', 'DE')], supported), 'en');
    });

    test('takes the first supported entry, not the first entry', () {
      expect(resolveStartupLanguage(const [Locale('de', 'DE'), Locale('tr', 'TR')], supported), 'tr');
    });

    test('falls back to English when the phone reports no locale at all', () {
      expect(resolveStartupLanguage(const [], supported), 'en');
    });

    test('falls back to English for an undetermined locale', () {
      expect(resolveStartupLanguage([Locale.fromSubtags(languageCode: 'und')], supported), 'en');
    });

    test('answers the supported spelling, not the phone spelling', () {
      // The phone may report a region the app does not list; the app still shows its own `tr`.
      expect(resolveStartupLanguage(const [Locale('tr', 'CY')], supported), 'tr');
    });

    test('honours another fallback when one is named', () {
      expect(resolveStartupLanguage(const [Locale('de', 'DE')], supported, fallback: 'tr'), 'tr');
    });
  });
}
