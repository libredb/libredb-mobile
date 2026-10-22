/// This file is used to set the environment
enum Environment { dev, prod, test }

final class AppConfig {
  const AppConfig({
    required this.environment,
    required this.apiBaseUrl,
    required this.certificatePins,
    required this.idleTimeout,
    this.sentryDsnDefine = const String.fromEnvironment('SENTRY_DSN'),
  });

  const AppConfig.dev()
    : environment = Environment.dev,
      apiBaseUrl = null,
      certificatePins = const <String>[],
      idleTimeout = null,
      sentryDsnDefine = const String.fromEnvironment('SENTRY_DSN');

  const AppConfig.test()
    : environment = Environment.test,
      apiBaseUrl = null,
      certificatePins = const <String>[],
      idleTimeout = null,
      sentryDsnDefine = const String.fromEnvironment('SENTRY_DSN');

  const AppConfig.prod()
    : environment = Environment.prod,
      apiBaseUrl = prodApiUrl,
      certificatePins = const <String>[],
      idleTimeout = const Duration(minutes: 15),
      sentryDsnDefine = const String.fromEnvironment('SENTRY_DSN');

  factory AppConfig.fromEnvironment(Environment environment) => switch (environment) {
    Environment.dev => const AppConfig.dev(),
    Environment.prod => const AppConfig.prod(),
    Environment.test => const AppConfig.test(),
  };

  /// LibreDB Studio's API, its origin plus `/api`, given at build time with
  /// `--dart-define=PROD_API_URL=https://studio.example.com/api` (docs/studio.md).
  static const String prodApiUrl = String.fromEnvironment('PROD_API_URL');

  final Environment environment;
  final String? apiBaseUrl;
  final List<String> certificatePins;
  final Duration? idleTimeout;

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
    idleTimeout: idleTimeout,
    sentryDsnDefine: '',
  );
}
