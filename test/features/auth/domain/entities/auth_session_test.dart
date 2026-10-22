import 'package:libredb_mobile/core/logging/log_sanitizer.dart';
import 'package:libredb_mobile/features/auth/domain/entities/auth_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AuthSession.toString', () {
    test('masks idToken and refreshToken', () {
      const session = AuthSession(
        idToken: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.payload.signature',
        refreshToken: 'refresh-token-value-12345',
      );

      final rendered = session.toString();

      expect(rendered.contains('payload'), isFalse);
      expect(rendered.contains('refresh-token-value-12345'), isFalse);
    });

    test('renders empty marker when refreshToken is null', () {
      const session = AuthSession(idToken: 'eyJhbGc.payload.signature');
      expect(session.toString(), contains('refreshToken: <empty>'));
    });

    test('masks the OIDC ID token and prints the access token expiry', () {
      final session = AuthSession(
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
      const session = AuthSession(idToken: 'eyJhbGc.payload.signature', refreshToken: 'refresh-token-value-12345');

      expect(session.toString(), 'AuthSession(idToken: eyJh…ture, refreshToken: refr…2345)');
    });

    test('prints only the OIDC field that is set', () {
      expect(
        const AuthSession(idToken: 'eyJhbGc.payload.signature', oidcIdToken: 'oidc-id-token-value').toString(),
        'AuthSession(idToken: eyJh…ture, refreshToken: <empty>, oidcIdToken: oidc…alue)',
      );
      expect(
        AuthSession(
          idToken: 'eyJhbGc.payload.signature',
          accessTokenExpiresAt: DateTime.utc(2026, 10, 21, 12),
        ).toString(),
        'AuthSession(idToken: eyJh…ture, refreshToken: <empty>, accessTokenExpiresAt: 2026-10-21 12:00:00.000Z)',
      );
    });
  });

  group('AuthSession equality', () {
    final expiresAt = DateTime.utc(2026, 10, 21, 12);

    test('sessions with the same OIDC ID token and expiry are equal', () {
      expect(
        AuthSession(idToken: 'T', oidcIdToken: 'ID', accessTokenExpiresAt: expiresAt),
        AuthSession(idToken: 'T', oidcIdToken: 'ID', accessTokenExpiresAt: expiresAt),
      );
    });

    test('a different OIDC ID token makes a different session', () {
      expect(
        const AuthSession(idToken: 'T', oidcIdToken: 'ID'),
        isNot(const AuthSession(idToken: 'T', oidcIdToken: 'OTHER')),
      );
    });

    test('a different access token expiry makes a different session', () {
      expect(
        AuthSession(idToken: 'T', accessTokenExpiresAt: expiresAt),
        isNot(AuthSession(idToken: 'T', accessTokenExpiresAt: expiresAt.add(const Duration(seconds: 1)))),
      );
    });

    test('the OIDC fields default to null', () {
      const session = AuthSession(idToken: 'T');

      expect(session.oidcIdToken, isNull);
      expect(session.accessTokenExpiresAt, isNull);
    });
  });
}
