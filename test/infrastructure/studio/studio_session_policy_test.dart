import 'package:dio/dio.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/infrastructure/studio/studio_session_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  DioException errorWith(int? statusCode, [Object? body]) {
    final options = RequestOptions(path: '/api/db/query');
    return DioException(
      requestOptions: options,
      response: statusCode == null ? null : Response(requestOptions: options, statusCode: statusCode, data: body),
    );
  }

  group('isStudioSessionExpired', () {
    test('accepts a 401 AUTH_REQUIRED, as text or as a decoded map', () {
      expect(isStudioSessionExpired(errorWith(401, '{"error":"Invalid access token","code":"AUTH_REQUIRED"}')), isTrue);
      expect(isStudioSessionExpired(errorWith(401, {'error': 'x', 'code': 'AUTH_REQUIRED'})), isTrue);
    });

    // GET /api/auth/me answers {"authenticated":false}, and a backend without codes answers a bare 401.
    test('accepts a 401 without a code', () {
      expect(isStudioSessionExpired(errorWith(401, '{"authenticated":false}')), isTrue);
      expect(isStudioSessionExpired(errorWith(401, 'Unauthorized')), isTrue);
      expect(isStudioSessionExpired(errorWith(401)), isTrue);
    });

    // A wrong database password or a rejected model key leaves the session as it is.
    test('refuses a 401 with any other code', () {
      for (final code in ['AUTH_ERROR', 'LLM_AUTH']) {
        expect(isStudioSessionExpired(errorWith(401, '{"error":"x","code":"$code"}')), isFalse, reason: code);
      }
    });

    // libredb-studio#1922 refuses an account with a role or identity it cannot use with a 403, which no refresh fixes.
    test('refuses a 403 that refuses the account', () {
      for (final code in ['BEARER_NO_ROLE', 'BEARER_NO_IDENTITY']) {
        expect(isStudioSessionExpired(errorWith(403, '{"error":"x","code":"$code"}')), isFalse, reason: code);
        expect(isStudioSessionRefused(errorWith(403, '{"error":"x","code":"$code"}')), isFalse, reason: code);
      }
    });

    test('refuses another status, or no response', () {
      expect(isStudioSessionExpired(errorWith(403, '{"error":"x","code":"AUTH_REQUIRED"}')), isFalse);
      expect(isStudioSessionExpired(errorWith(503, '{"code":"IDENTITY_PROVIDER_UNAVAILABLE"}')), isFalse);
      expect(isStudioSessionExpired(errorWith(null)), isFalse);
    });
  });

  // After a refresh, only AUTH_REQUIRED means Studio refuses the token Keycloak has just issued. A 401 without a code
  // is also what GET /api/auth/me answers when Studio cannot reach Keycloak, which a new session would not fix.
  group('isStudioSessionRefused', () {
    test('accepts a 401 AUTH_REQUIRED, as text or as a decoded map', () {
      expect(isStudioSessionRefused(errorWith(401, '{"error":"Invalid access token","code":"AUTH_REQUIRED"}')), isTrue);
      expect(isStudioSessionRefused(errorWith(401, {'error': 'x', 'code': 'AUTH_REQUIRED'})), isTrue);
    });

    test('refuses a 401 without a code', () {
      expect(isStudioSessionRefused(errorWith(401, '{"authenticated":false}')), isFalse);
      expect(isStudioSessionRefused(errorWith(401, 'Unauthorized')), isFalse);
      expect(isStudioSessionRefused(errorWith(401)), isFalse);
    });

    test('refuses a 401 with any other code', () {
      for (final code in ['AUTH_ERROR', 'LLM_AUTH']) {
        expect(isStudioSessionRefused(errorWith(401, '{"error":"x","code":"$code"}')), isFalse, reason: code);
      }
    });

    test('refuses another status, or no response', () {
      expect(isStudioSessionRefused(errorWith(403, '{"error":"x","code":"AUTH_REQUIRED"}')), isFalse);
      expect(isStudioSessionRefused(errorWith(null)), isFalse);
    });
  });

  // From libredb-studio#1922 on, a verified token whose account Studio does not accept is refused with 403 and its own
  // code on every route that reads the bearer; the shell shows the refusal page for it.
  group('studioAccountRefusal', () {
    test('gives the code of a 403 BEARER_NO_ROLE or BEARER_NO_IDENTITY, as text or as a decoded map', () {
      expect(
        studioAccountRefusal(errorWith(403, '{"error":"x","code":"BEARER_NO_ROLE"}')),
        AppErrorCode.studioAccountHasNoRole,
      );
      expect(
        studioAccountRefusal(errorWith(403, {'error': 'x', 'code': 'BEARER_NO_IDENTITY'})),
        AppErrorCode.studioAccountHasNoIdentity,
      );
    });

    test('gives nothing for any other answer', () {
      expect(studioAccountRefusal(errorWith(401, '{"error":"x","code":"BEARER_NO_ROLE"}')), isNull);
      expect(studioAccountRefusal(errorWith(403, '{"error":"x","code":"AUTH_ERROR"}')), isNull);
      expect(studioAccountRefusal(errorWith(403, '{"error":"x","code":"PERMISSION_DENIED"}')), isNull);
      expect(studioAccountRefusal(errorWith(403, 'Forbidden')), isNull);
      expect(studioAccountRefusal(errorWith(401, '{"error":"x","code":"AUTH_REQUIRED"}')), isNull);
      expect(studioAccountRefusal(errorWith(503, '{"error":"x","code":"IDENTITY_PROVIDER_UNAVAILABLE"}')), isNull);
      expect(studioAccountRefusal(errorWith(null)), isNull);
    });
  });
}
