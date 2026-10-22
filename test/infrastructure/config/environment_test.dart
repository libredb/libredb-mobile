import 'package:libredb_mobile/infrastructure/config/environment.dart';
import 'package:flutter_test/flutter_test.dart';

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
}
