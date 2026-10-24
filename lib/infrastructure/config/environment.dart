import 'dart:convert';

import 'package:flutter/foundation.dart';

/// This file is used to set the environment
enum Environment { dev, prod, test }

final class AppConfig {
  const AppConfig({
    required this.environment,
    required this.apiBaseUrl,
    required this.certificatePins,
    required this.idleTimeout,
    this.oidcCertificatePins = const <String>[],
    this.screenCaptureProtection = false,
    this.appLockRequired = false,
    this.sentryDsnDefine = const String.fromEnvironment('SENTRY_DSN'),
  });

  const AppConfig.dev({this.screenCaptureProtection = false, this.appLockRequired = false})
    : environment = Environment.dev,
      apiBaseUrl = null,
      certificatePins = const <String>[],
      oidcCertificatePins = const <String>[],
      idleTimeout = null,
      sentryDsnDefine = const String.fromEnvironment('SENTRY_DSN');

  const AppConfig.test({this.screenCaptureProtection = false, this.appLockRequired = false})
    : environment = Environment.test,
      apiBaseUrl = null,
      certificatePins = const <String>[],
      oidcCertificatePins = const <String>[],
      idleTimeout = null,
      sentryDsnDefine = const String.fromEnvironment('SENTRY_DSN');

  const AppConfig.prod({
    String this.apiBaseUrl = prodApiUrl,
    this.certificatePins = const <String>[],
    this.oidcCertificatePins = const <String>[],
    this.screenCaptureProtection = true,
    this.appLockRequired = false,
    this.sentryDsnDefine = const String.fromEnvironment('SENTRY_DSN'),
  }) : environment = Environment.prod,
       idleTimeout = const Duration(minutes: 15);

  /// The config the app starts with in [environment].
  ///
  /// Throws [ProdApiUrlConfigError] in the prod environment when [prodApiUrlDefine], the `PROD_API_URL` define unless
  /// a test passes its own, is empty: such a build has no server to call.
  ///
  /// Throws [ProdHttpsConfigError] in the prod environment when one of [httpsOnlyDefines] is set but is not an https
  /// URL: [prodApiUrlDefine], [oidcIssuerDefine] or [sentryDsnDefine], the `PROD_API_URL`, `OIDC_ISSUER` and
  /// `SENTRY_DSN` defines unless a test passes its own. The store build declares that its traffic is encrypted in
  /// transit, so it never starts with a plain http server. An unset `OIDC_ISSUER` still starts and fails closed on the
  /// login page, and an unset `SENTRY_DSN` leaves Sentry off. Dev and test check none of them.
  ///
  /// Throws [CertificatePinsConfigError] in the prod environment when [studioCertPinsDefine] or [oidcCertPinsDefine],
  /// the `STUDIO_CERT_PINS` and `OIDC_CERT_PINS` defines unless a test passes its own, is set but breaks a pin rule:
  /// such a build never falls back to an unpinned connection. Dev and test read neither define.
  ///
  /// [screenCaptureProtectionDefine], the `SCREEN_CAPTURE_PROTECTION` define unless a test passes its own, sets
  /// [screenCaptureProtection]: `true` or `false`, or empty for the environment's default, on in prod and off in dev
  /// and test. Any other value throws [ScreenCaptureProtectionConfigError] in every environment, so a typo never
  /// decides it.
  ///
  /// [appLockRequiredDefine], the `APP_LOCK_REQUIRED` define unless a test passes its own, sets [appLockRequired]:
  /// `true` or `false`, or empty for false, in every environment. Any other value throws [AppLockRequiredConfigError].
  factory AppConfig.fromEnvironment(
    Environment environment, {
    @visibleForTesting String prodApiUrlDefine = prodApiUrl,
    @visibleForTesting String oidcIssuerDefine = oidcIssuer,
    @visibleForTesting String sentryDsnDefine = sentryDsnOfTheBuild,
    @visibleForTesting String studioCertPinsDefine = studioCertPins,
    @visibleForTesting String oidcCertPinsDefine = oidcCertPins,
    @visibleForTesting String screenCaptureProtectionDefine = screenCaptureProtectionSwitch,
    @visibleForTesting String appLockRequiredDefine = appLockRequiredSwitch,
  }) {
    if (environment == Environment.prod) {
      if (prodApiUrlDefine.isEmpty) throw ProdApiUrlConfigError();
      _requireHttps('PROD_API_URL', prodApiUrlDefine);
      // Trimmed first, as OidcSettings reads it; an unset issuer fails closed on the login page instead.
      if (oidcIssuerDefine.trim().isNotEmpty) _requireHttps('OIDC_ISSUER', oidcIssuerDefine.trim());
      if (sentryDsnDefine.isNotEmpty) _requireHttps('SENTRY_DSN', sentryDsnDefine);
    }
    final protection = _screenCaptureProtectionOf(screenCaptureProtectionDefine);
    final lockRequired = _appLockRequiredOf(appLockRequiredDefine);
    return switch (environment) {
      Environment.dev => AppConfig.dev(screenCaptureProtection: protection ?? false, appLockRequired: lockRequired),
      Environment.prod => AppConfig.prod(
        apiBaseUrl: prodApiUrlDefine,
        sentryDsnDefine: sentryDsnDefine,
        certificatePins: _pins('STUDIO_CERT_PINS', studioCertPinsDefine),
        oidcCertificatePins: _pins('OIDC_CERT_PINS', oidcCertPinsDefine),
        screenCaptureProtection: protection ?? true,
        appLockRequired: lockRequired,
      ),
      Environment.test => AppConfig.test(screenCaptureProtection: protection ?? false, appLockRequired: lockRequired),
    };
  }

  /// LibreDB Studio's API, its origin plus `/api`, given at build time with
  /// `--dart-define=PROD_API_URL=https://studio.example.com/api` (docs/studio.md).
  static const String prodApiUrl = String.fromEnvironment('PROD_API_URL');

  /// The identity provider's issuer, given at build time with `--dart-define=OIDC_ISSUER=...` (docs/oidc.md);
  /// `AuthDefines` reads it for the sign-in, and [AppConfig.fromEnvironment] only checks its scheme in prod.
  static const String oidcIssuer = String.fromEnvironment('OIDC_ISSUER');

  /// The `--dart-define=SENTRY_DSN=...` value of the build, empty when it is absent (docs/crash-reporting.md).
  static const String sentryDsnOfTheBuild = String.fromEnvironment('SENTRY_DSN');

  /// The defines a prod build accepts only as https URLs ([AppConfig.fromEnvironment], docs/security.md, "Encryption
  /// in transit").
  static const Set<String> httpsOnlyDefines = {'PROD_API_URL', 'OIDC_ISSUER', 'SENTRY_DSN'};

  /// Whether [value] is an absolute https URL with a host: the scheme in any case, optional user info, a host name
  /// or an IPv6 literal, an optional port, then the end or a path, query or fragment. A space or an ASCII control
  /// character never belongs to the user info or the host.
  /// The same pattern runs in `NativeSentry.requireHttpsDsn` and `tool/release/check_defines.sh`, so the three never
  /// disagree; it is written without a case flag because the regex engines read one differently.
  static bool isHttpsUrl(String value) => _httpsUrl.hasMatch(value);

  /// The pattern of [isHttpsUrl], which `test/architecture/android_release_setup_test.dart` finds verbatim in the
  /// other two.
  static const String httpsUrlPattern =
      r'^[Hh][Tt][Tt][Pp][Ss]://([^/?#@\x00-\x20\x7F]*@)?'
      r'(\[[0-9A-Fa-f:.]+\]|[^/?#@:\[\]\x00-\x20\x7F]+)(:[0-9]*)?([/?#]|$)';

  static final _httpsUrl = RegExp(httpsUrlPattern);

  /// Throws [ProdHttpsConfigError] unless [value], the define [name], is an https URL without surrounding whitespace.
  static void _requireHttps(String name, String value) {
    if (value.trim() != value) throw ProdHttpsConfigError(name, whitespace: true);
    if (!isHttpsUrl(value)) throw ProdHttpsConfigError(name);
  }

  /// The pins of the host of [prodApiUrl], given at build time with `--dart-define=STUDIO_CERT_PINS=<pin>,<pin>`
  /// (docs/security.md, "Certificate pinning"); empty leaves that host on the system trust store.
  static const String studioCertPins = String.fromEnvironment('STUDIO_CERT_PINS');

  /// The pins of the host of `OIDC_ISSUER`, given at build time with `--dart-define=OIDC_CERT_PINS=<pin>,<pin>`
  /// (docs/security.md, "Certificate pinning"); empty leaves that host on the system trust store.
  static const String oidcCertPins = String.fromEnvironment('OIDC_CERT_PINS');

  /// The bytes of a SHA-256 digest, which a pin encodes.
  static const _pinBytes = 32;

  /// The pins of [value], the define [name]: none for an empty value, else at least two distinct base64 SHA-256
  /// values in the canonical padded form `CertificatePinner.computePin` prints, so string comparison matches.
  static List<String> _pins(String name, String value) {
    if (value.trim().isEmpty) return const <String>[];
    final pins = value.split(',').map((pin) => pin.trim()).toList();
    for (final (index, pin) in pins.indexed) {
      if (!_isPin(pin)) {
        throw CertificatePinsConfigError(
          name,
          'entry ${index + 1} must be the base64 SHA-256 of a public key, 44 characters ending in =, but it is "$pin"',
        );
      }
    }
    final distinct = pins.toSet().toList(growable: false);
    if (distinct.length < 2) {
      throw CertificatePinsConfigError(
        name,
        'needs at least two distinct pins, the current key and a backup key, but it has ${distinct.length}',
      );
    }
    return List.unmodifiable(distinct);
  }

  static bool _isPin(String pin) {
    try {
      final bytes = base64.decode(pin);
      return bytes.length == _pinBytes && base64.encode(bytes) == pin;
    } on FormatException {
      return false;
    }
  }

  /// The `--dart-define=SCREEN_CAPTURE_PROTECTION=true|false` value, empty when it is absent (docs/security.md,
  /// "Screen capture protection").
  static const String screenCaptureProtectionSwitch = String.fromEnvironment('SCREEN_CAPTURE_PROTECTION');

  /// The switch [value] sets, or null for the environment's default.
  static bool? _screenCaptureProtectionOf(String value) => switch (value) {
    '' => null,
    'true' => true,
    'false' => false,
    _ => throw ScreenCaptureProtectionConfigError(value),
  };

  /// The `--dart-define=APP_LOCK_REQUIRED=true|false` value, empty when it is absent (docs/security.md, "App lock").
  static const String appLockRequiredSwitch = String.fromEnvironment('APP_LOCK_REQUIRED');

  /// Whether [value] requires the app lock: `true`, or `false` and empty for no.
  static bool _appLockRequiredOf(String value) => switch (value) {
    '' || 'false' => false,
    'true' => true,
    _ => throw AppLockRequiredConfigError(value),
  };

  final Environment environment;
  final String? apiBaseUrl;

  /// The pins of Studio's host, the host of [apiBaseUrl], from `STUDIO_CERT_PINS`; empty when pinning is off for it.
  /// `ApiClient` installs them on every Studio request, retries and the token refresh included.
  final List<String> certificatePins;

  /// The pins of the identity provider's host, the host of `OIDC_ISSUER`, from `OIDC_CERT_PINS`; empty when pinning
  /// is off for it. The OpenID Connect client sends discovery, the key set, the token exchange and the refresh
  /// through them; the sign-in page in the system browser is never pinned.
  final List<String> oidcCertificatePins;
  final Duration? idleTimeout;

  /// Whether the screens that show data (results, a row's detail, a key's value, an object's source) keep out of
  /// screenshots, screen recordings and the recent-apps preview while they are on screen: on in prod, off in dev and
  /// test, and set by `SCREEN_CAPTURE_PROTECTION` ([AppConfig.fromEnvironment]).
  final bool screenCaptureProtection;

  /// Whether the build forces the app lock on, from `APP_LOCK_REQUIRED` ([AppConfig.fromEnvironment]): the settings
  /// show the switch on and disabled, and a device without a screen lock offers only Sign out while signed in.
  final bool appLockRequired;

  /// The `--dart-define=SENTRY_DSN=...` value, empty when it is absent.
  /// [sentryDsn] reads it in the prod environment only.
  final String sentryDsnDefine;

  bool get isProduction => environment == Environment.prod;
  bool get isDevelopment => environment == Environment.dev;
  bool get isTest => environment == Environment.test;

  /// Production-only DSN passed via `--dart-define=SENTRY_DSN=...`.
  /// Returns null in non-prod, or when the define is absent / empty.
  /// **Never** commit a DSN to source: the repository is public.
  String? get sentryDsn {
    if (!isProduction) return null;
    return sentryDsnDefine.isEmpty ? null : sentryDsnDefine;
  }

  /// This config without a Sentry DSN, for a run that must behave exactly
  /// as one without the define: no Sentry SDK, the log-only analytics and
  /// no Sentry navigator observer.
  AppConfig withoutSentry() => AppConfig(
    environment: environment,
    apiBaseUrl: apiBaseUrl,
    certificatePins: certificatePins,
    oidcCertificatePins: oidcCertificatePins,
    idleTimeout: idleTimeout,
    screenCaptureProtection: screenCaptureProtection,
    appLockRequired: appLockRequired,
    sentryDsnDefine: '',
  );
}

/// A prod build without `PROD_API_URL`, which stops the app at start instead of calling an empty base URL.
final class ProdApiUrlConfigError extends Error {
  @override
  String toString() => "PROD_API_URL is empty, but a prod build needs LibreDB Studio's API URL (docs/studio.md)";
}

/// A prod build whose `PROD_API_URL`, `OIDC_ISSUER` or `SENTRY_DSN` is set but is not an https URL, which stops the
/// app at start instead of sending a bearer, a sign-in or a crash report over plain http.
final class ProdHttpsConfigError extends Error {
  ProdHttpsConfigError(this.define, {this.whitespace = false});

  /// The define that is not https. Its value is never printed, because the DSN carries the project's key.
  final String define;

  /// Whether the value has leading or trailing whitespace, which a prod build refuses rather than trims.
  final bool whitespace;

  @override
  String toString() => whitespace
      ? '$define has leading or trailing whitespace; a prod build needs an https URL (docs/security.md, '
            '"Encryption in transit")'
      : '$define must be an https URL in a prod build (docs/security.md, "Encryption in transit")';
}

/// A prod build whose `STUDIO_CERT_PINS` or `OIDC_CERT_PINS` breaks a pin rule, which stops the app at start instead
/// of connecting unpinned or with a pin set that a key change would lock out.
final class CertificatePinsConfigError extends Error {
  CertificatePinsConfigError(this.define, this.rule);

  /// The define that breaks the rule.
  final String define;

  /// The rule, written for the person who builds the app; a pin is not a secret, so it may quote one.
  final String rule;

  @override
  String toString() => '$define $rule (docs/security.md, "Certificate pinning")';
}

/// A build whose `SCREEN_CAPTURE_PROTECTION` is neither `true` nor `false`, which stops the app at start instead of
/// guessing whether the data screens may be captured.
final class ScreenCaptureProtectionConfigError extends Error {
  ScreenCaptureProtectionConfigError(this.value);

  /// The define's value, which is no secret.
  final String value;

  @override
  String toString() => 'SCREEN_CAPTURE_PROTECTION must be true or false, but it is "$value" (docs/security.md)';
}

/// A build whose `APP_LOCK_REQUIRED` is neither `true` nor `false`, which stops the app at start instead of guessing
/// whether the app lock is required.
final class AppLockRequiredConfigError extends Error {
  AppLockRequiredConfigError(this.value);

  /// The define's value, which is no secret.
  final String value;

  @override
  String toString() => 'APP_LOCK_REQUIRED must be true or false, but it is "$value" (docs/security.md)';
}
