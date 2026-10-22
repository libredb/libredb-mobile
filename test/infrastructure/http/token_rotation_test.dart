import 'package:dio/dio.dart';
import 'package:libredb_mobile/infrastructure/http/token_rotation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // A misconfigured build cannot reach the identity provider, so it never refreshes a stored session.
  group('RefusingTokenRotation', () {
    test('refuses every refresh', () async {
      expect(await const RefusingTokenRotation().rotate('provider-refresh-token'), isA<RotationRefused>());
    });
  });

  group('TokensRotated', () {
    test('masks every token in toString', () {
      final text = TokensRotated(
        accessToken: 'access-token-123456',
        refreshToken: 'refresh-token-654321',
        oidcIdToken: 'id-token-abcdef',
        accessTokenExpiresAt: DateTime.utc(2026, 10, 21, 12),
      ).toString();

      expect(text, allOf(isNot(contains('access-token-123456')), isNot(contains('refresh-token-654321'))));
      expect(text, isNot(contains('id-token-abcdef')));
      expect(text, contains('2026-10-21'));
    });
  });

  group('isUnauthorized', () {
    DioException errorWith(int? statusCode) {
      final options = RequestOptions(path: '/api/users');
      return DioException(
        requestOptions: options,
        response: statusCode == null ? null : Response(requestOptions: options, statusCode: statusCode),
      );
    }

    test('accepts a 401', () => expect(isUnauthorized(errorWith(401)), isTrue));

    test('refuses a 403', () => expect(isUnauthorized(errorWith(403)), isFalse));

    test('refuses an error without a response', () => expect(isUnauthorized(errorWith(null)), isFalse));
  });
}

/// Records every request that reaches it, then passes it on.
