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
}
