import 'package:libredb_mobile/core/logging/log_sanitizer.dart';
import 'package:libredb_mobile/features/auth/domain/entities/auth_session.dart';
import 'package:libredb_mobile/shared/models/session_target.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AuthSession.toString', () {
    test('masks idToken and refreshToken', () {
      const session = AuthSession(
        target: SessionTarget.studio,
        idToken: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.payload.signature',
        refreshToken: 'refresh-token-value-12345',
      );

      final rendered = session.toString();

      expect(rendered.contains('payload'), isFalse);
      expect(rendered.contains('refresh-token-value-12345'), isFalse);
    });

    test('renders empty marker when refreshToken is null', () {
      const session = AuthSession(target: SessionTarget.studio, idToken: 'eyJhbGc.payload.signature');
      expect(session.toString(), contains('refreshToken: <empty>'));
    });

    test('masks the OIDC ID token and prints the access token expiry', () {
      final session = AuthSession(
        target: SessionTarget.studio,
        idToken: 'access-token-value-12345',
        oidcIdToken: 'eyJhbGciOiJSUzI1NiJ9.oidc-payload.oidc-signature',
        accessTokenExpiresAt: DateTime.utc(2026, 10, 21, 12),
      );

      final rendered = session.toString();

      expect(rendered.contains('oidc-payload'), isFalse);
      expect(rendered, contains('oidcIdToken: ${maskToken('eyJhbGciOiJSUzI1NiJ9.oidc-payload.oidc-signature')}'));
      expect(rendered, contains('accessTokenExpiresAt: 2026-10-21 12:00:00.000Z'));
    });

    test('prints a session without the OIDC fields, and no username or role, which it does not hold', () {
      const session = AuthSession(
        target: SessionTarget.studio,
        idToken: 'eyJhbGc.payload.signature',
        refreshToken: 'refresh-token-value-12345',
      );

      expect(
        session.toString(),
        'AuthSession(target: SessionTarget.studio, idToken: eyJh…ture, refreshToken: refr…2345)',
      );
    });

    // The target is not a secret, so it is printed as it is.
    test('prints the platform target', () {
      expect(
        const AuthSession(target: SessionTarget.platform, idToken: 'eyJhbGc.payload.signature').toString(),
        'AuthSession(target: SessionTarget.platform, idToken: eyJh…ture, refreshToken: <empty>)',
      );
    });

    test('prints only the OIDC field that is set', () {
      expect(
        const AuthSession(
          target: SessionTarget.studio,
          idToken: 'eyJhbGc.payload.signature',
          oidcIdToken: 'oidc-id-token-value',
        ).toString(),
        'AuthSession(target: SessionTarget.studio, idToken: eyJh…ture, refreshToken: <empty>, oidcIdToken: oidc…alue)',
      );
      expect(
        AuthSession(
          target: SessionTarget.studio,
          idToken: 'eyJhbGc.payload.signature',
          accessTokenExpiresAt: DateTime.utc(2026, 10, 21, 12),
        ).toString(),
        'AuthSession(target: SessionTarget.studio, idToken: eyJh…ture, refreshToken: <empty>, '
        'accessTokenExpiresAt: 2026-10-21 12:00:00.000Z)',
      );
    });
  });

  group('AuthSession equality', () {
    final expiresAt = DateTime.utc(2026, 10, 21, 12);

    test('sessions with the same OIDC ID token and expiry are equal', () {
      expect(
        AuthSession(target: SessionTarget.studio, idToken: 'T', oidcIdToken: 'ID', accessTokenExpiresAt: expiresAt),
        AuthSession(target: SessionTarget.studio, idToken: 'T', oidcIdToken: 'ID', accessTokenExpiresAt: expiresAt),
      );
    });

    test('a different OIDC ID token makes a different session', () {
      expect(
        const AuthSession(target: SessionTarget.studio, idToken: 'T', oidcIdToken: 'ID'),
        isNot(const AuthSession(target: SessionTarget.studio, idToken: 'T', oidcIdToken: 'OTHER')),
      );
    });

    test('a different access token expiry makes a different session', () {
      expect(
        AuthSession(target: SessionTarget.studio, idToken: 'T', accessTokenExpiresAt: expiresAt),
        isNot(
          AuthSession(
            target: SessionTarget.studio,
            idToken: 'T',
            accessTokenExpiresAt: expiresAt.add(const Duration(seconds: 1)),
          ),
        ),
      );
    });

    test('a different target makes a different session', () {
      expect(
        const AuthSession(target: SessionTarget.studio, idToken: 'T'),
        isNot(const AuthSession(target: SessionTarget.platform, idToken: 'T')),
      );
    });

    test('the OIDC fields default to null', () {
      const session = AuthSession(target: SessionTarget.studio, idToken: 'T');

      expect(session.oidcIdToken, isNull);
      expect(session.accessTokenExpiresAt, isNull);
    });
  });
}
