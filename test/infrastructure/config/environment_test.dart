import 'dart:convert';
import 'dart:io';

import 'package:libredb_mobile/infrastructure/config/environment.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/pin_test_certificates.dart';

const _studioUrl = 'https://studio.example.test/api';

void main() {
  group('AppConfig', () {
    test('dev config sets development environment', () {
      const config = AppConfig.dev();
      expect(config.isDevelopment, true);
      expect(config.apiBaseUrl, isNull);
    });
    test('test config sets test environment', () {
      const config = AppConfig.test();
      expect(config.isDevelopment, false);
      expect(config.isProduction, false);
      expect(config.isTest, true);
      expect(config.apiBaseUrl, isNull);
    });
    test('prod config sets production environment', () {
      const config = AppConfig.prod(apiBaseUrl: 'https://studio.example.test/api');
      expect(config.isProduction, true);
      expect(config.apiBaseUrl, 'https://studio.example.test/api');
      expect(config.idleTimeout, const Duration(minutes: 15));
      expect(config.certificatePins, isEmpty);
      expect(config.oidcCertificatePins, isEmpty);
    });
    test('fromEnvironment maps each enum value', () {
      expect(AppConfig.fromEnvironment(Environment.dev).isDevelopment, true);
      expect(AppConfig.fromEnvironment(Environment.test).isTest, true);
      expect(
        AppConfig.fromEnvironment(Environment.prod, prodApiUrlDefine: 'https://studio.example.test/api').isProduction,
        true,
      );
    });
  });

  // Run with and without `--dart-define=PROD_API_URL=...` to cover both branches of the define.
  group('PROD_API_URL', () {
    test('is empty unless the build gives it', () {
      const define = String.fromEnvironment('PROD_API_URL');
      expect(AppConfig.prodApiUrl, define.isEmpty ? '' : define);
      expect(const AppConfig.prod().apiBaseUrl, define.isEmpty ? '' : define);
    });

    test('a prod start without it stops with an error that names it', () {
      expect(
        () => AppConfig.fromEnvironment(Environment.prod, prodApiUrlDefine: ''),
        throwsA(isA<ProdApiUrlConfigError>().having((error) => '$error', 'message', contains('PROD_API_URL'))),
      );
    });

    test('a prod start with it calls that URL', () {
      final config = AppConfig.fromEnvironment(Environment.prod, prodApiUrlDefine: 'https://studio.example.test/api');
      expect(config.apiBaseUrl, 'https://studio.example.test/api');
    });

    test('a prod start reads the define of the build', () {
      const define = String.fromEnvironment('PROD_API_URL');
      if (define.isEmpty) {
        expect(() => AppConfig.fromEnvironment(Environment.prod), throwsA(isA<ProdApiUrlConfigError>()));
      } else {
        expect(AppConfig.fromEnvironment(Environment.prod).apiBaseUrl, define);
      }
    });

    test('dev and test need no API URL', () {
      expect(AppConfig.fromEnvironment(Environment.dev, prodApiUrlDefine: '').apiBaseUrl, isNull);
      expect(AppConfig.fromEnvironment(Environment.test, prodApiUrlDefine: '').apiBaseUrl, isNull);
    });
  });

  group('PLATFORM_API_URL and PLATFORM_CERT_PINS', () {
    const platformUrl = 'https://platform.example.test/api';

    AppConfig prod({String url = '', String pins = ''}) => AppConfig.fromEnvironment(
      Environment.prod,
      prodApiUrlDefine: _studioUrl,
      platformApiUrlDefine: url,
      platformCertPinsDefine: pins,
    );

    test('are empty unless the build gives them', () {
      const url = String.fromEnvironment('PLATFORM_API_URL');
      const pins = String.fromEnvironment('PLATFORM_CERT_PINS');
      expect(AppConfig.platformApiUrl, url);
      expect(AppConfig.platformCertPins, pins);
    });

    test('an empty PLATFORM_API_URL gives a prod build without Platform mode', () {
      expect(prod().platform, isA<PlatformNotConfigured>());
      expect(const AppConfig.prod().platform, isA<PlatformNotConfigured>());
    });

    test('an https PLATFORM_API_URL gives that base URL, on the system trust store without pins', () {
      final platform = prod(url: platformUrl).platform;

      expect(platform, isA<PlatformConfigured>().having((p) => p.baseUrl, 'baseUrl', platformUrl));
      expect((platform as PlatformConfigured).certificatePins, isEmpty);
    });

    test('PLATFORM_CERT_PINS pin the Platform host only', () {
      final config = prod(url: platformUrl, pins: '$ecCertificatePin, $rsaCertificatePin');

      expect((config.platform as PlatformConfigured).certificatePins, [ecCertificatePin, rsaCertificatePin]);
      expect(config.certificatePins, isEmpty);
      expect(config.oidcCertificatePins, isEmpty);
    });

    test(
      'a PLATFORM_API_URL that is not https, or has surrounding whitespace, stops the start naming only the define',
      () {
        for (final value in ['http://platform.example.test/api', 'platform.example.test/api', ' $platformUrl']) {
          expect(
            () => prod(url: value),
            throwsA(
              isA<ProdHttpsConfigError>()
                  .having((error) => error.define, 'define', 'PLATFORM_API_URL')
                  .having((error) => '$error', 'message', isNot(contains('platform.example.test'))),
            ),
            reason: value,
          );
        }
      },
    );

    test('PLATFORM_CERT_PINS are checked like the other pins', () {
      expect(
        () => prod(url: platformUrl, pins: ecCertificatePin),
        throwsA(isA<CertificatePinsConfigError>().having((e) => e.define, 'define', 'PLATFORM_CERT_PINS')),
      );
      expect(
        () => prod(url: platformUrl, pins: 'not-a-pin,$ecCertificatePin'),
        throwsA(isA<CertificatePinsConfigError>().having((e) => e.define, 'define', 'PLATFORM_CERT_PINS')),
      );
    });

    test('PLATFORM_CERT_PINS without PLATFORM_API_URL stops the start', () {
      expect(
        () => prod(pins: '$ecCertificatePin,$rsaCertificatePin'),
        throwsA(isA<CertificatePinsConfigError>().having((e) => e.define, 'define', 'PLATFORM_CERT_PINS')),
      );
    });

    test('dev and test call the mock as their Platform, whatever the defines', () {
      for (final environment in [Environment.dev, Environment.test]) {
        final platform = AppConfig.fromEnvironment(environment, platformApiUrlDefine: 'http://x').platform;
        expect(platform, isA<PlatformConfigured>().having((p) => p.baseUrl, 'baseUrl', isNull), reason: '$environment');
      }
      expect(const AppConfig.dev().platform, isA<PlatformConfigured>());
      expect(const AppConfig.test().platform, isA<PlatformConfigured>());
    });

    test('withoutSentry keeps the Platform target', () {
      final config = prod(url: platformUrl).withoutSentry();

      expect(config.platform, isA<PlatformConfigured>().having((p) => p.baseUrl, 'baseUrl', platformUrl));
    });
  });

  group('STUDIO_CERT_PINS and OIDC_CERT_PINS', () {
    AppConfig prod({String studio = '', String oidc = ''}) => AppConfig.fromEnvironment(
      Environment.prod,
      prodApiUrlDefine: _studioUrl,
      studioCertPinsDefine: studio,
      oidcCertPinsDefine: oidc,
    );

    Matcher configError(String define, String rule) => throwsA(
      isA<CertificatePinsConfigError>().having((error) => '$error', 'message', allOf(contains(define), contains(rule))),
    );

    test('are empty unless the build gives them', () {
      const studio = String.fromEnvironment('STUDIO_CERT_PINS');
      const oidc = String.fromEnvironment('OIDC_CERT_PINS');
      expect(AppConfig.studioCertPins, studio);
      expect(AppConfig.oidcCertPins, oidc);
    });

    test('empty defines leave both hosts on the system trust store', () {
      final config = prod();
      expect(config.certificatePins, isEmpty);
      expect(config.oidcCertificatePins, isEmpty);
    });

    test('a define of blanks counts as empty', () {
      expect(prod(studio: '  ', oidc: ' ').certificatePins, isEmpty);
    });

    test('two pins pin Studio host only', () {
      final config = prod(studio: '$ecCertificatePin,$rsaCertificatePin');
      expect(config.certificatePins, [ecCertificatePin, rsaCertificatePin]);
      expect(config.oidcCertificatePins, isEmpty);
    });

    test('two pins pin the issuer host only', () {
      final config = prod(oidc: '$ecCertificatePin,$rsaCertificatePin');
      expect(config.oidcCertificatePins, [ecCertificatePin, rsaCertificatePin]);
      expect(config.certificatePins, isEmpty);
    });

    test('blanks around the pins are dropped', () {
      expect(prod(studio: ' $ecCertificatePin , $rsaCertificatePin ').certificatePins, [
        ecCertificatePin,
        rsaCertificatePin,
      ]);
    });

    test('one pin stops a prod start, since there is no backup pin', () {
      expect(() => prod(studio: ecCertificatePin), configError('STUDIO_CERT_PINS', 'backup'));
      expect(() => prod(oidc: ecCertificatePin), configError('OIDC_CERT_PINS', 'backup'));
    });

    test('the same pin twice counts as one pin', () {
      expect(() => prod(studio: '$ecCertificatePin,$ecCertificatePin'), configError('STUDIO_CERT_PINS', 'backup'));
    });

    final malformed = <String, String>{
      'a value that is not base64': 'not a pin!',
      'a value of 16 bytes': 'AAAAAAAAAAAAAAAAAAAAAA==',
      'a value without its padding': ecCertificatePin.replaceAll('=', ''),
      'a value in the URL-safe alphabet': ecCertificatePin.replaceAll('+', '-'),
      'a hex SHA-256': 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
      'an empty entry': '$ecCertificatePin,,$rsaCertificatePin',
    };
    for (final MapEntry(key: name, value: value) in malformed.entries) {
      test('$name stops a prod start', () {
        expect(() => prod(studio: '$value,$rsaCertificatePin'), configError('STUDIO_CERT_PINS', 'base64 SHA-256'));
        expect(() => prod(oidc: '$value,$rsaCertificatePin'), configError('OIDC_CERT_PINS', 'base64 SHA-256'));
      });
    }

    test('dev and test read neither define', () {
      for (final environment in [Environment.dev, Environment.test]) {
        final config = AppConfig.fromEnvironment(environment, studioCertPinsDefine: 'bad', oidcCertPinsDefine: 'bad');
        expect(config.certificatePins, isEmpty);
        expect(config.oidcCertificatePins, isEmpty);
      }
    });

    test('a prod config without Sentry keeps both pin lists', () {
      final config = prod(studio: '$ecCertificatePin,$rsaCertificatePin', oidc: '$rsaCertificatePin,$ecCertificatePin');
      final withoutSentry = config.withoutSentry();
      expect(withoutSentry.certificatePins, config.certificatePins);
      expect(withoutSentry.oidcCertificatePins, config.oidcCertificatePins);
    });
  });

  // Run with and without `--dart-define=SCREEN_CAPTURE_PROTECTION=...` to cover both branches of the define.
  group('SCREEN_CAPTURE_PROTECTION', () {
    test('a prod build protects the data screens unless the define turns it off', () {
      expect(const AppConfig.prod().screenCaptureProtection, isTrue);
      expect(
        AppConfig.fromEnvironment(
          Environment.prod,
          prodApiUrlDefine: 'https://studio.example.test/api',
          screenCaptureProtectionDefine: '',
        ).screenCaptureProtection,
        isTrue,
      );
    });

    test('dev and test builds leave every screen capturable by default', () {
      expect(const AppConfig.dev().screenCaptureProtection, isFalse);
      expect(const AppConfig.test().screenCaptureProtection, isFalse);
      expect(
        AppConfig.fromEnvironment(Environment.dev, screenCaptureProtectionDefine: '').screenCaptureProtection,
        isFalse,
      );
      expect(
        AppConfig.fromEnvironment(Environment.test, screenCaptureProtectionDefine: '').screenCaptureProtection,
        isFalse,
      );
    });

    test('false turns it off in a prod build', () {
      final config = AppConfig.fromEnvironment(
        Environment.prod,
        prodApiUrlDefine: 'https://studio.example.test/api',
        screenCaptureProtectionDefine: 'false',
      );
      expect(config.screenCaptureProtection, isFalse);
    });

    test('true turns it on in a dev build', () {
      expect(
        AppConfig.fromEnvironment(Environment.dev, screenCaptureProtectionDefine: 'true').screenCaptureProtection,
        isTrue,
      );
    });

    test('any other value stops the start with an error that names the define', () {
      for (final environment in Environment.values) {
        expect(
          () => AppConfig.fromEnvironment(
            environment,
            prodApiUrlDefine: 'https://studio.example.test/api',
            screenCaptureProtectionDefine: 'off',
          ),
          throwsA(
            isA<ScreenCaptureProtectionConfigError>().having(
              (error) => '$error',
              'message',
              allOf(contains('SCREEN_CAPTURE_PROTECTION'), contains('"off"')),
            ),
          ),
        );
      }
    });

    test('a start reads the define of the build', () {
      const define = String.fromEnvironment('SCREEN_CAPTURE_PROTECTION');
      final config = AppConfig.fromEnvironment(Environment.prod, prodApiUrlDefine: 'https://studio.example.test/api');
      expect(config.screenCaptureProtection, define != 'false');
    });

    test('a config without Sentry keeps the switch', () {
      expect(const AppConfig.prod().withoutSentry().screenCaptureProtection, isTrue);
      expect(const AppConfig.dev().withoutSentry().screenCaptureProtection, isFalse);
    });
  });

  // Run with and without `--dart-define=APP_LOCK_REQUIRED=...` to cover both branches of the define.
  group('APP_LOCK_REQUIRED', () {
    test('no build requires the app lock by default', () {
      expect(const AppConfig.prod().appLockRequired, isFalse);
      expect(const AppConfig.dev().appLockRequired, isFalse);
      expect(const AppConfig.test().appLockRequired, isFalse);
      for (final environment in Environment.values) {
        expect(
          AppConfig.fromEnvironment(
            environment,
            prodApiUrlDefine: 'https://studio.example.test/api',
            appLockRequiredDefine: '',
          ).appLockRequired,
          isFalse,
        );
      }
    });

    test('true requires it in every environment', () {
      for (final environment in Environment.values) {
        expect(
          AppConfig.fromEnvironment(
            environment,
            prodApiUrlDefine: 'https://studio.example.test/api',
            appLockRequiredDefine: 'true',
          ).appLockRequired,
          isTrue,
        );
      }
    });

    test('false leaves it to the user', () {
      expect(
        AppConfig.fromEnvironment(
          Environment.prod,
          prodApiUrlDefine: 'https://studio.example.test/api',
          appLockRequiredDefine: 'false',
        ).appLockRequired,
        isFalse,
      );
    });

    test('any other value stops the start with an error that names the define', () {
      for (final environment in Environment.values) {
        expect(
          () => AppConfig.fromEnvironment(
            environment,
            prodApiUrlDefine: 'https://studio.example.test/api',
            appLockRequiredDefine: 'yes',
          ),
          throwsA(
            isA<AppLockRequiredConfigError>().having(
              (error) => '$error',
              'message',
              allOf(contains('APP_LOCK_REQUIRED'), contains('"yes"')),
            ),
          ),
        );
      }
    });

    test('a start reads the define of the build', () {
      const define = String.fromEnvironment('APP_LOCK_REQUIRED');
      final config = AppConfig.fromEnvironment(Environment.prod, prodApiUrlDefine: 'https://studio.example.test/api');
      expect(config.appLockRequired, define == 'true');
    });

    test('a config without Sentry keeps the switch', () {
      expect(
        AppConfig.fromEnvironment(
          Environment.prod,
          prodApiUrlDefine: 'https://studio.example.test/api',
          appLockRequiredDefine: 'true',
        ).withoutSentry().appLockRequired,
        isTrue,
      );
    });
  });

  // The store build declares encryption in transit (#197, #218), so a prod start refuses each of these unless https.
  group('https only in a prod build', () {
    const issuer = 'https://keycloak.example.test/realms/libredb';
    const dsn = 'https://publickey@o1.ingest.sentry.example.test/1';

    AppConfig prod({String studio = _studioUrl, String oidcIssuer = issuer, String sentryDsn = ''}) =>
        AppConfig.fromEnvironment(
          Environment.prod,
          prodApiUrlDefine: studio,
          oidcIssuerDefine: oidcIssuer,
          sentryDsnDefine: sentryDsn,
        );

    Matcher refuses(String define, String value) => throwsA(
      isA<ProdHttpsConfigError>()
          .having((error) => error.define, 'define', define)
          .having((error) => '$error', 'message', allOf(contains(define), contains('https'), isNot(contains(value)))),
    );

    test('checks PROD_API_URL, OIDC_ISSUER, SENTRY_DSN and PLATFORM_API_URL', () {
      expect(AppConfig.httpsOnlyDefines, {'PROD_API_URL', 'OIDC_ISSUER', 'SENTRY_DSN', 'PLATFORM_API_URL'});
    });

    test('a PROD_API_URL that is not https stops the start with an error that names only the define', () {
      for (final value in [
        'http://studio.example.test/api',
        'studio.example.test/api',
        'https:///api',
        'ftp://s/api',
      ]) {
        expect(() => prod(studio: value), refuses('PROD_API_URL', value), reason: value);
      }
    });

    test('an OIDC_ISSUER that is not https stops the start, a loopback http issuer included', () {
      for (final value in ['http://keycloak.example.test/realms/libredb', 'http://localhost:8080/realms/libredb']) {
        expect(() => prod(oidcIssuer: value), refuses('OIDC_ISSUER', value), reason: value);
      }
    });

    test('a SENTRY_DSN that is not https stops the start without printing the DSN', () {
      const value = 'http://publickey@o1.ingest.sentry.example.test/1';
      expect(() => prod(sentryDsn: value), refuses('SENTRY_DSN', value));
    });

    test('https values start, with the DSN', () {
      final config = prod(sentryDsn: dsn);
      expect(config.apiBaseUrl, _studioUrl);
      expect(config.sentryDsn, dsn);
    });

    test('the scheme is read without regard to case', () {
      expect(prod(studio: 'HTTPS://studio.example.test/api').apiBaseUrl, 'HTTPS://studio.example.test/api');
    });

    test('a host with an underscore, a port or an IPv6 literal passes, as everywhere the rule runs', () {
      for (final value in ['https://my_studio.example.test/api', 'https://studio:9443/api', 'https://[::1]:9443/api']) {
        expect(prod(studio: value, sentryDsn: 'https://key@my_sentry.example.test/1').apiBaseUrl, value);
      }
    });

    test('surrounding whitespace in PROD_API_URL or SENTRY_DSN stops the start and says so', () {
      for (final name in ['PROD_API_URL', 'SENTRY_DSN']) {
        for (final value in [' $_studioUrl', '$_studioUrl ', '$_studioUrl\n']) {
          expect(
            () => name == 'PROD_API_URL' ? prod(studio: value) : prod(sentryDsn: value),
            throwsA(
              isA<ProdHttpsConfigError>()
                  .having((error) => error.define, 'define', name)
                  .having((error) => '$error', 'message', contains('whitespace')),
            ),
            reason: '$name=${jsonEncode(value)}',
          );
        }
      }
    });

    test('an OIDC_ISSUER is trimmed first, as the sign-in reads it', () {
      expect(prod(oidcIssuer: '  $issuer\n').isProduction, isTrue);
    });

    test('an unset OIDC_ISSUER or SENTRY_DSN starts: the login page fails closed, and Sentry stays off', () {
      final config = prod(oidcIssuer: '', sentryDsn: '');
      expect(config.sentryDsn, isNull);
    });

    test('the tool/studio-dev values pass', () {
      final defines = {
        for (final line in File('tool/studio-dev/studio-dev.env').readAsLinesSync())
          if (!line.startsWith('#') && line.contains('=')) line.split('=').first: line.substring(line.indexOf('=') + 1),
      };
      expect(
        prod(studio: defines['PROD_API_URL']!, oidcIssuer: defines['OIDC_ISSUER']!).apiBaseUrl,
        defines['PROD_API_URL'],
      );
    });

    test('dev and test check none of them, so main_local.dart keeps working', () {
      for (final environment in [Environment.dev, Environment.test]) {
        final config = AppConfig.fromEnvironment(
          environment,
          prodApiUrlDefine: 'http://studio.example.test/api',
          oidcIssuerDefine: 'http://keycloak.example.test/realms/libredb',
          sentryDsnDefine: 'http://publickey@o1.ingest.sentry.example.test/1',
        );
        expect(config.environment, environment);
        expect(config.sentryDsn, isNull);
      }
    });

    test('a prod start reads the defines of the build', () {
      const studio = String.fromEnvironment('PROD_API_URL');
      const oidcIssuer = String.fromEnvironment('OIDC_ISSUER');
      const sentryDsn = String.fromEnvironment('SENTRY_DSN');
      bool insecure(String value) => value.isNotEmpty && (value.trim() != value || !AppConfig.isHttpsUrl(value));
      AppConfig start() => AppConfig.fromEnvironment(Environment.prod, prodApiUrlDefine: _studioUrl);
      if (insecure(oidcIssuer.trim()) || insecure(sentryDsn)) {
        expect(start, throwsA(isA<ProdHttpsConfigError>()));
      } else {
        expect(start().isProduction, isTrue);
      }
      if (insecure(studio)) {
        expect(() => AppConfig.fromEnvironment(Environment.prod), throwsA(isA<ProdHttpsConfigError>()));
      }
    });
  });
}
