import 'package:dio/dio.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/infrastructure/platform/platform_session_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  DioException errorWith(int? statusCode, [Object? body]) {
    final options = RequestOptions(path: '/v1/me');
    return DioException(
      requestOptions: options,
      response: statusCode == null ? null : Response(requestOptions: options, statusCode: statusCode, data: body),
    );
  }

  String envelope(String code) => '{"error":{"code":"$code","message":"The account jane.doe@example.org"}}';

  // A 401 BEARER_INVALID starts one refresh, and the same answer to the request sent again after it ends the session.
  for (final (name, predicate) in [
    ('isPlatformSessionExpired', isPlatformSessionExpired),
    ('isPlatformSessionRefused', isPlatformSessionRefused),
  ]) {
    group(name, () {
      test('accepts a 401 BEARER_INVALID, as text or as a decoded map', () {
        expect(predicate(errorWith(401, envelope('BEARER_INVALID'))), isTrue);
        expect(
          predicate(
            errorWith(401, {
              'error': {'code': 'BEARER_INVALID', 'message': 'x'},
            }),
          ),
          isTrue,
        );
      });

      // A 401 that is not Platform's envelope reaches the caller as an error and never ends the session.
      test('refuses a 401 without the envelope or with another code', () {
        expect(predicate(errorWith(401, 'Unauthorized')), isFalse);
        expect(predicate(errorWith(401, '{"code":"BEARER_INVALID"}')), isFalse);
        expect(predicate(errorWith(401, '{"code":"AUTH_REQUIRED"}')), isFalse);
        expect(predicate(errorWith(401, envelope('ADMIN_ROLE_REQUIRED'))), isFalse);
        expect(predicate(errorWith(401)), isFalse);
      });

      test('refuses every 502 or 503 whatever its code, a 403, and no response', () {
        for (final (status, code) in [
          (503, 'IDENTITY_PROVIDER_UNAVAILABLE'),
          (503, 'DIRECTORY_UNAVAILABLE'),
          (503, 'KEYCLOAK_UNAVAILABLE'),
          (502, 'KEYCLOAK_AUTH_ERROR'),
          (502, 'KEYCLOAK_PERMISSION_ERROR'),
          (503, 'BEARER_INVALID'),
          (403, 'BEARER_INVALID'),
          (403, 'ADMIN_ROLE_REQUIRED'),
          (403, 'LICENSE_EXPIRED'),
        ]) {
          expect(predicate(errorWith(status, envelope(code))), isFalse, reason: '$status $code');
        }
        expect(predicate(errorWith(null)), isFalse);
      });
    });
  }

  group('platformAccountRefusal', () {
    test('reads a 403 ADMIN_ROLE_REQUIRED and a 403 LICENSE_ADMIN_SEATS as refusals of the account', () {
      expect(
        platformAccountRefusal(errorWith(403, envelope('ADMIN_ROLE_REQUIRED'))),
        AppErrorCode.platformAdminRoleRequired,
      );
      expect(
        platformAccountRefusal(errorWith(403, envelope('LICENSE_ADMIN_SEATS'))),
        AppErrorCode.platformLicenseAdminSeats,
      );
    });

    // A grant PUT can answer these, and refusing the whole account over one grant would lock the admin out.
    test('never reads another license code as a refusal of the account', () {
      for (final code in ['LICENSE_EXPIRED', 'LICENSE_INVALID', 'LICENSE_USER_SEATS', 'PLAN_FEATURE_REQUIRED']) {
        expect(platformAccountRefusal(errorWith(403, envelope(code))), isNull, reason: code);
      }
    });

    test('refuses the same codes on another status, a Studio body, and no response', () {
      expect(platformAccountRefusal(errorWith(401, envelope('ADMIN_ROLE_REQUIRED'))), isNull);
      expect(platformAccountRefusal(errorWith(503, envelope('LICENSE_ADMIN_SEATS'))), isNull);
      expect(platformAccountRefusal(errorWith(403, '{"code":"ADMIN_ROLE_REQUIRED"}')), isNull);
      expect(platformAccountRefusal(errorWith(403, '{"code":"BEARER_NO_ROLE"}')), isNull);
      expect(platformAccountRefusal(errorWith(null)), isNull);
    });
  });
}
