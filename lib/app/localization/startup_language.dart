import 'dart:ui';

/// The language the app opens in on a device that has none stored yet — the first run, onboarding included.
///
/// [deviceLocales] is the phone's language list, most preferred first (`PlatformDispatcher.instance.locales`), and
/// [supported] the languages the app has (`S.delegate.supportedLocales`). The answer is the language code of the first
/// device entry the app supports, so a phone that asks for German before Turkish still opens in Turkish rather than
/// in [fallback]. Only the language is matched: the app ships one translation per language, so `tr-TR` and `tr-CY`
/// both answer `tr`, and the answer is always spelled as [supported] spells it.
///
/// [fallback] is the answer when the phone speaks nothing the app has, when it reports no locale at all, and when it
/// reports an undetermined one (`und`), which no supported locale matches.
///
/// A pure function on purpose: it needs no binding, no platform channel and no widget, so every case above is a plain
/// unit test. `AppBootstrapConfig.startupLanguage` is what reads the device and calls it.
String resolveStartupLanguage(Iterable<Locale> deviceLocales, Iterable<Locale> supported, {String fallback = 'en'}) {
  for (final deviceLocale in deviceLocales) {
    for (final supportedLocale in supported) {
      if (supportedLocale.languageCode == deviceLocale.languageCode) return supportedLocale.languageCode;
    }
  }
  return fallback;
}
