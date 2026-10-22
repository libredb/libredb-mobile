import 'package:dio/dio.dart';
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

    test('refuses another status, or no response', () {
      expect(isStudioSessionExpired(errorWith(403, '{"error":"x","code":"AUTH_REQUIRED"}')), isFalse);
      expect(isStudioSessionExpired(errorWith(503, '{"code":"IDENTITY_PROVIDER_UNAVAILABLE"}')), isFalse);
      expect(isStudioSessionExpired(errorWith(null)), isFalse);
    });
  });
}
