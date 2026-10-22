import 'package:libredb_mobile/infrastructure/config/auth_config.dart';
import 'package:flutter_test/flutter_test.dart';

/// The issuer and client id of a valid build, which a row changes one field of.
const _issuer = 'https://id.example.com/realms/demo';
const _clientId = 'demo-app';

/// The settings a build with [defines] parses to; fails the test when the build is misconfigured.
OidcSettings _settings(AuthDefines defines) {
  final mode = AuthMode.fromDefines(defines);
  if (mode is! OidcAuthMode) fail('expected OidcAuthMode, got $mode');
  return mode.settings;
}

void main() {
  group('AuthMode.fromDefines', () {
    test('has no password sign-in: a build without OIDC settings fails closed as a misconfigured oidc build', () {
      final mode = AuthMode.fromDefines(const AuthDefines());

      expect(mode, isA<OidcMisconfiguredAuthMode>().having((m) => m.reason, 'reason', contains('OIDC_ISSUER')));
    });

    test('is misconfigured without an issuer', () {
      final mode = AuthMode.fromDefines(const AuthDefines(oidcClientId: _clientId));

      expect(mode, isA<OidcMisconfiguredAuthMode>().having((m) => m.reason, 'reason', contains('OIDC_ISSUER')));
    });

    test('is misconfigured without a client id', () {
      final mode = AuthMode.fromDefines(const AuthDefines(oidcIssuer: _issuer));

      expect(mode, isA<OidcMisconfiguredAuthMode>().having((m) => m.reason, 'reason', contains('OIDC_CLIENT_ID')));
    });

    test('is misconfigured for an http issuer on a host that is not loopback', () {
      final mode = AuthMode.fromDefines(
        const AuthDefines(oidcIssuer: 'http://keycloak.example.com/realms/x', oidcClientId: _clientId),
      );

      expect(mode, isA<OidcMisconfiguredAuthMode>().having((m) => m.reason, 'reason', contains('OIDC_ISSUER')));
    });

    for (final issuer in ['http://localhost:8080/realms/x', 'http://127.0.0.1:8080/r', 'http://[::1]:8080/r']) {
      test('accepts the loopback http issuer $issuer', () {
        final mode = AuthMode.fromDefines(AuthDefines(oidcIssuer: issuer, oidcClientId: _clientId));

        expect(mode, isA<OidcAuthMode>().having((m) => m.settings.issuer, 'issuer', Uri.parse(issuer)));
      });
    }

    test('accepts an https issuer whose scheme is upper-case', () {
      final mode = AuthMode.fromDefines(
        const AuthDefines(oidcIssuer: 'HTTPS://id.example.com', oidcClientId: _clientId),
      );

      expect(mode, isA<OidcAuthMode>());
    });

    test('is misconfigured for an issuer without a scheme', () {
      final mode = AuthMode.fromDefines(const AuthDefines(oidcIssuer: 'id.example.com', oidcClientId: _clientId));

      expect(mode, isA<OidcMisconfiguredAuthMode>().having((m) => m.reason, 'reason', contains('OIDC_ISSUER')));
    });

    for (final issuer in ['https://id.example.com/realms/demo?x=1', 'https://id.example.com/realms/demo#y']) {
      test('is misconfigured for the issuer $issuer, which has a query or a fragment', () {
        final mode = AuthMode.fromDefines(AuthDefines(oidcIssuer: issuer, oidcClientId: _clientId));

        expect(mode, isA<OidcMisconfiguredAuthMode>().having((m) => m.reason, 'reason', contains('OIDC_ISSUER')));
      });
    }

    test('is misconfigured for a scope without openid', () {
      final mode = AuthMode.fromDefines(
        const AuthDefines(oidcIssuer: _issuer, oidcClientId: _clientId, oidcScope: 'profile email'),
      );

      expect(mode, isA<OidcMisconfiguredAuthMode>().having((m) => m.reason, 'reason', contains('OIDC_SCOPE')));
    });

    test('asks for openid, profile and email when the scope is unset', () {
      final settings = _settings(const AuthDefines(oidcIssuer: _issuer, oidcClientId: _clientId));

      expect(settings.scopes, ['openid', 'profile', 'email']);
    });

    test('splits the scope on white space', () {
      final settings = _settings(
        const AuthDefines(oidcIssuer: _issuer, oidcClientId: _clientId, oidcScope: ' openid  offline_access '),
      );

      expect(settings.scopes, ['openid', 'offline_access']);
    });

    test('prompts for login when the prompt is unset', () {
      final settings = _settings(const AuthDefines(oidcIssuer: _issuer, oidcClientId: _clientId));

      expect(settings.prompt, OidcPrompt.login);
    });

    test('reads a padded mixed-case select_account prompt', () {
      final settings = _settings(
        const AuthDefines(oidcIssuer: _issuer, oidcClientId: _clientId, oidcPrompt: ' Select_Account '),
      );

      expect(settings.prompt, OidcPrompt.selectAccount);
    });

    test('reads the omit prompt', () {
      final settings = _settings(const AuthDefines(oidcIssuer: _issuer, oidcClientId: _clientId, oidcPrompt: 'omit'));

      expect(settings.prompt, OidcPrompt.omit);
    });

    for (final prompt in ['none', 'always']) {
      test('is misconfigured for the prompt $prompt', () {
        final mode = AuthMode.fromDefines(
          AuthDefines(oidcIssuer: _issuer, oidcClientId: _clientId, oidcPrompt: prompt),
        );

        expect(mode, isA<OidcMisconfiguredAuthMode>().having((m) => m.reason, 'reason', contains('OIDC_PROMPT')));
      });
    }

    for (final value in ['true', '1', 'on', 'YES']) {
      test('turns the automatic redirect on for $value', () {
        final settings = _settings(AuthDefines(oidcIssuer: _issuer, oidcClientId: _clientId, oidcAutoRedirect: value));

        expect(settings.autoRedirect, isTrue);
      });
    }

    for (final value in ['false', '0', 'off', 'no', '']) {
      test('leaves the automatic redirect off for "$value"', () {
        final settings = _settings(AuthDefines(oidcIssuer: _issuer, oidcClientId: _clientId, oidcAutoRedirect: value));

        expect(settings.autoRedirect, isFalse);
      });
    }

    test('is misconfigured for an automatic redirect of maybe', () {
      final mode = AuthMode.fromDefines(
        const AuthDefines(oidcIssuer: _issuer, oidcClientId: _clientId, oidcAutoRedirect: 'maybe'),
      );

      expect(mode, isA<OidcMisconfiguredAuthMode>().having((m) => m.reason, 'reason', contains('OIDC_AUTO_REDIRECT')));
    });

    test('sends the logout hint when it is unset', () {
      final settings = _settings(const AuthDefines(oidcIssuer: _issuer, oidcClientId: _clientId));

      expect(settings.logoutHint, isTrue);
    });

    test('leaves the logout hint out when it is off', () {
      final settings = _settings(
        const AuthDefines(oidcIssuer: _issuer, oidcClientId: _clientId, oidcLogoutHint: 'off'),
      );

      expect(settings.logoutHint, isFalse);
    });

    test('uses the app redirect scheme when it is unset', () {
      final settings = _settings(const AuthDefines(oidcIssuer: _issuer, oidcClientId: _clientId));

      expect(settings.redirectScheme, OidcSettings.defaultRedirectScheme);
      expect(settings.redirectScheme, 'org.libredb.mobile');
    });

    test('redirects sign-in and logout to <scheme>:/oauth2redirect', () {
      final settings = _settings(
        const AuthDefines(oidcIssuer: _issuer, oidcClientId: _clientId, oidcRedirectScheme: 'com.acme.db'),
      );

      expect(settings.redirectUri.toString(), 'com.acme.db:/oauth2redirect');
      expect(settings.redirectUri.path, OidcSettings.redirectPath);
    });

    for (final scheme in ['org.libredb_mobile', '9app', 'Org.Libredb.Mobile']) {
      test('is misconfigured for the redirect scheme $scheme', () {
        final mode = AuthMode.fromDefines(
          AuthDefines(oidcIssuer: _issuer, oidcClientId: _clientId, oidcRedirectScheme: scheme),
        );

        expect(
          mode,
          isA<OidcMisconfiguredAuthMode>().having((m) => m.reason, 'reason', contains('OIDC_REDIRECT_SCHEME')),
        );
      });
    }

    test('reads the audience, and leaves an unset audience out', () {
      final withAudience = _settings(
        const AuthDefines(oidcIssuer: _issuer, oidcClientId: _clientId, oidcAudience: ' api '),
      );
      final without = _settings(const AuthDefines(oidcIssuer: _issuer, oidcClientId: _clientId));

      expect(withAudience.audience, 'api');
      expect(without.audience, isNull);
    });
  });

  group('OidcPrompt.parameter', () {
    test('is the prompt value sent to the provider, and none for omit', () {
      expect(OidcPrompt.login.parameter, 'login');
      expect(OidcPrompt.consent.parameter, 'consent');
      expect(OidcPrompt.selectAccount.parameter, 'select_account');
      expect(OidcPrompt.omit.parameter, isNull);
    });
  });
}
