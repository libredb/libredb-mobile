import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/features/auth/domain/services/sso_auto_redirect_gate.dart';
import 'package:libredb_mobile/infrastructure/config/auth_config.dart';
import 'package:libredb_mobile/shared/models/session_target.dart';

/// Whether the login page sends the user to the provider without a tap.
///
/// Four rules decide it, and getting any of them wrong is a redirect loop or a page the user cannot leave. They
/// lived inside the page's `State`, reachable only by pumping the screen with a router, a bloc and two providers
/// (#379).
void main() {
  OidcAuthMode oidc({bool autoRedirect = true}) => OidcAuthMode(
    OidcSettings(issuer: Uri.parse('https://id.example.com'), clientId: 'app', autoRedirect: autoRedirect),
  );

  SessionTarget? target({
    AuthMode? mode,
    List<SessionTarget> entries = const [SessionTarget.studio],
    bool gateIsOpen = true,
    bool hasError = false,
  }) => autoRedirectTarget(
    mode: mode ?? oidc(),
    entries: entries,
    gateIsOpen: () => gateIsOpen,
    hasError: () => hasError,
  );

  test('a build with one entry and nothing in the way redirects to it', () {
    expect(target(), SessionTarget.studio);
  });

  test('a build that did not ask for it never redirects', () {
    expect(target(mode: oidc(autoRedirect: false)), isNull);
  });

  test('a misconfigured build never redirects', () {
    expect(target(mode: const OidcMisconfiguredAuthMode('OIDC_ISSUER is empty')), isNull);
  });

  test('a build that offers a choice lets the user make it', () {
    expect(
      target(entries: const [SessionTarget.studio, SessionTarget.platform]),
      isNull,
      reason: 'picking one of two targets for the user is a choice the app does not get to make',
    );
    expect(target(entries: const []), isNull);
  });

  test('a closed gate stops it', () {
    expect(
      target(gateIsOpen: false),
      isNull,
      reason: 'the gate closes after a redirect, an error, a cancel or a logout',
    );
  });

  test('an error on screen stops it', () {
    expect(target(hasError: true), isNull, reason: 'redirecting over an error is the loop the gate exists to prevent');
  });

  group('the answers it does not need', () {
    test('a build that did not ask is settled without reading the gate or the error', () {
      var asked = 0;
      autoRedirectTarget(
        mode: oidc(autoRedirect: false),
        entries: const [SessionTarget.studio],
        gateIsOpen: () {
          asked++;
          return true;
        },
        hasError: () {
          asked++;
          return false;
        },
      );
      expect(asked, 0, reason: 'the page answers these from providers a build without a redirect may not have');
    });

    test('a build with two entries is settled the same way', () {
      var asked = 0;
      autoRedirectTarget(
        mode: oidc(),
        entries: const [SessionTarget.studio, SessionTarget.platform],
        gateIsOpen: () {
          asked++;
          return true;
        },
        hasError: () {
          asked++;
          return false;
        },
      );
      expect(asked, 0);
    });
  });
}
