import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/app/bootstrap/app_bootstrap_config.dart';
import 'package:libredb_mobile/infrastructure/config/auth_config.dart';
import 'package:libredb_mobile/infrastructure/config/environment.dart';

/// The values an entry point decides for itself. `main_mock.dart` passes none, `main_local.dart` passes the Lima VM's
/// and `main_prod.dart` passes Railway's, each as a `--dart-define` default a build can still override.
void main() {
  group('AppBootstrapConfig', () {
    test('passes the build-time defines through when an entry point names nothing', () {
      const config = AppBootstrapConfig(environment: Environment.mock);
      expect(config.authDefines.issuerDefine, AppConfig.oidcIssuer);
      expect(config.apiBaseUrl, AppConfig.prodApiUrl);
      expect(config.platformApiUrl, AppConfig.platformApiUrl);
    });

    test('carries the issuer, the client id and the base URLs an entry point names', () {
      const config = AppBootstrapConfig(
        environment: Environment.local,
        authDefines: AuthDefines(oidcIssuer: 'https://sso.lab.test/realms/libredb', oidcClientId: 'libredb-mobile'),
        apiBaseUrl: 'https://studio.lab.test/api',
        platformApiUrl: 'https://libredb.lab.test/api',
      );
      expect(config.apiBaseUrl, 'https://studio.lab.test/api');
      expect(config.platformApiUrl, 'https://libredb.lab.test/api');
      final mode = AuthMode.fromDefines(config.authDefines);
      expect(mode, isA<OidcAuthMode>());
      expect((mode as OidcAuthMode).settings.issuer.toString(), 'https://sso.lab.test/realms/libredb');
      expect(mode.settings.clientId, 'libredb-mobile');
    });

    test('exposes the raw issuer, so a prod build checks the one it will sign in through', () {
      const defines = AuthDefines(oidcIssuer: 'http://sso.example.test/realms/libredb', oidcClientId: 'libredb-mobile');
      expect(
        () => AppConfig.fromEnvironment(
          Environment.prod,
          prodApiUrlDefine: 'https://studio.example.test/api',
          oidcIssuerDefine: defines.issuerDefine,
        ),
        throwsA(isA<ProdHttpsConfigError>().having((e) => e.define, 'define', 'OIDC_ISSUER')),
      );
    });
  });

  group('AppBootstrapConfig.startupLanguage', () {
    test('names no language of its own, so the first run can follow the phone', () {
      const config = AppBootstrapConfig(environment: Environment.mock);
      expect(config.defaultLanguage, isNull);
    });

    test('follows the phone when the entry point names no language', () {
      const config = AppBootstrapConfig(environment: Environment.mock);
      expect(config.startupLanguage(deviceLocales: const [Locale('tr', 'TR')]), 'tr');
    });

    test('falls back to English when the phone speaks a language the app does not have', () {
      const config = AppBootstrapConfig(environment: Environment.mock);
      expect(config.startupLanguage(deviceLocales: const [Locale('de', 'DE')]), 'en');
    });

    test('the language an entry point names wins over the phone, so a build can still pin one', () {
      const config = AppBootstrapConfig(environment: Environment.mock, defaultLanguage: 'en');
      expect(config.startupLanguage(deviceLocales: const [Locale('tr', 'TR')]), 'en');
    });

    // No list handed in: the device the app runs on. The device here is the binding's, which the test sets, so each
    // answer is one this case decides — `isIn(['en', 'tr'])` was true of every branch the function has.
    test('reads this device when no list is handed in', () {
      final device = TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher;
      addTearDown(device.clearLocalesTestValue);
      const config = AppBootstrapConfig(environment: Environment.mock);

      device.localesTestValue = const [Locale('tr', 'TR')];
      expect(config.startupLanguage(), 'tr');

      device.localesTestValue = const [Locale('de', 'DE')];
      expect(config.startupLanguage(), 'en', reason: 'a device language the app does not have falls back to English');
    });
  });
}
