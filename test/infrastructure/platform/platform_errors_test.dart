import 'package:libredb_mobile/core/errors/app_api_exception.dart';
import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/infrastructure/platform/platform_errors.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const text = 'Platform answered with a code';

  AppException response(int status, String? code, {List<String> keys = const []}) => switch (status) {
    400 => BadRequestException(text, statusCode: status, errorCode: code, fieldErrorKeys: keys),
    401 || 403 => UnauthorizedException(text, statusCode: status, errorCode: code),
    _ => FetchDataException(text, statusCode: status, errorCode: code),
  };

  group('platformError maps each Platform code', () {
    final cases = <(int, String, Type, AppErrorCode)>[
      (401, 'BEARER_INVALID', AuthError, AppErrorCode.authInvalidAccessToken),
      (403, 'ADMIN_ROLE_REQUIRED', AuthError, AppErrorCode.platformAdminRoleRequired),
      (403, 'LICENSE_ADMIN_SEATS', AuthError, AppErrorCode.platformLicenseAdminSeats),
      (403, 'LICENSE_USER_SEATS', AuthError, AppErrorCode.platformLicenseUserSeats),
      (403, 'LICENSE_EXPIRED', AuthError, AppErrorCode.platformLicenseExpired),
      (403, 'LICENSE_INVALID', AuthError, AppErrorCode.platformLicenseInvalid),
      (404, 'API_DISABLED', NotFoundError, AppErrorCode.platformApiDisabled),
      (404, 'NOT_FOUND', NotFoundError, AppErrorCode.platformNotFound),
      (503, 'IDENTITY_PROVIDER_UNAVAILABLE', ServerError, AppErrorCode.platformIdentityProviderUnavailable),
      (503, 'DIRECTORY_UNAVAILABLE', ServerError, AppErrorCode.platformDirectoryUnavailable),
      (503, 'KEYCLOAK_UNAVAILABLE', ServerError, AppErrorCode.platformKeycloakUnavailable),
      (502, 'KEYCLOAK_AUTH_ERROR', ServerError, AppErrorCode.platformKeycloakUnavailable),
      (502, 'KEYCLOAK_PERMISSION_ERROR', ServerError, AppErrorCode.platformKeycloakUnavailable),
      (404, 'KEYCLOAK_NOT_FOUND', ServerError, AppErrorCode.platformKeycloakUnavailable),
      (403, 'PLAN_FEATURE_REQUIRED', AuthError, AppErrorCode.platformPlanFeatureRequired),
      (403, 'PERMISSION_DENIED', AuthError, AppErrorCode.platformPermissionDenied),
      (500, 'INTERNAL_ERROR', ServerError, AppErrorCode.platformInternalError),
      (403, 'STUDIO_ROLE_REQUIRED', AuthError, AppErrorCode.platformStudioRoleRequired),
      (404, 'ACCESS_REQUESTS_DISABLED', NotFoundError, AppErrorCode.platformAccessRequestsDisabled),
      (409, 'ACCESS_REQUEST_PENDING', ValidationError, AppErrorCode.platformAccessRequestPending),
      (409, 'ACCESS_ALREADY_GRANTED', ValidationError, AppErrorCode.platformAccessAlreadyGranted),
      (409, 'ACCESS_REQUEST_LIMIT', ValidationError, AppErrorCode.platformAccessRequestLimit),
      (409, 'ACCESS_REQUEST_DECIDED', ValidationError, AppErrorCode.platformAccessRequestDecided),
    ];
    for (final (status, code, type, appCode) in cases) {
      test('$status $code -> $type ${appCode.key}', () {
        final error = platformError(response(status, code));

        expect(error.runtimeType, type);
        expect(error.code, appCode.key);
        expect(error.message, contains(text));
      });
    }
  });

  group('platformError maps a validation failure', () {
    for (final keys in [
      <String>[],
      [''],
      ['body'],
      ['level'],
      ['subject'],
      ['expiresAt'],
      ['level', 'expiresAt'],
      ['q'],
    ]) {
      test('400 VALIDATION_FAILED on $keys -> platformValidationFailed', () {
        final error = platformError(response(400, 'VALIDATION_FAILED', keys: keys));

        expect(error, isA<ValidationError>());
        expect(error.code, AppErrorCode.platformValidationFailed.key);
      });
    }
  });

  group('platformError without a known code', () {
    final cases = <(int, String?, Type, AppErrorCode?)>[
      // Platform answers every 5xx of its own with a code (libredb-platform api-v1-response.ts), so a 5xx without one
      // comes from the edge in front of a stopped Platform (#343).
      (500, null, ServerError, AppErrorCode.platformUnreachable),
      (502, null, ServerError, AppErrorCode.platformUnreachable),
      (503, 'SOMETHING_NEW', ServerError, AppErrorCode.platformInternalError),
      (504, null, ServerError, AppErrorCode.platformUnreachable),
      (400, null, ValidationError, null),
      (400, 'SOMETHING_NEW', ValidationError, null),
      (401, null, AuthError, null),
      (403, 'SOMETHING_NEW', AuthError, null),
      (404, null, NotFoundError, null),
      // Studio's 413 and 429 rows do not apply to Platform.
      (413, null, UnknownError, null),
      (429, null, UnknownError, null),
      (409, 'SOMETHING_NEW', UnknownError, null),
      (409, null, UnknownError, null),
    ];
    for (final (status, code, type, appCode) in cases) {
      test('$status ${code ?? 'without a code'} -> $type ${appCode?.key}', () {
        final error = platformError(response(status, code));

        expect(error.runtimeType, type);
        expect(error.code, appCode?.key);
      });
    }
  });

  group('platformAccessRequestWriteError', () {
    AppError written(int status, String? code, {List<String> keys = const []}) =>
        platformAccessRequestWriteError(response(status, code, keys: keys));

    test('maps a refusal on the reason alone to platformAccessRequestReasonRefused', () {
      final error = written(400, 'VALIDATION_FAILED', keys: ['reason']);

      expect(error, isA<ValidationError>());
      expect(error.code, AppErrorCode.platformAccessRequestReasonRefused.key);
      expect(error.message, contains(text));
    });

    test('maps a refusal on the level alone to the grant level code', () {
      final error = written(400, 'VALIDATION_FAILED', keys: ['level']);

      expect(error, isA<ValidationError>());
      expect(error.code, AppErrorCode.platformGrantLevelRefused.key);
    });

    test('falls back to platformValidationFailed when the reason and the level are both refused', () {
      final error = written(400, 'VALIDATION_FAILED', keys: ['reason', 'level']);

      expect(error, isA<ValidationError>());
      expect(error.code, AppErrorCode.platformValidationFailed.key);
    });

    for (final keys in [
      <String>[],
      [''],
      ['body'],
      ['connectionId'],
      ['expiresAt'],
      ['subject'],
    ]) {
      test('falls back to platformValidationFailed on $keys', () {
        final error = written(400, 'VALIDATION_FAILED', keys: keys);

        expect(error, isA<ValidationError>());
        expect(error.code, AppErrorCode.platformValidationFailed.key);
      });
    }

    test('sends a 400 with another code through platformError', () {
      final error = written(400, 'SOMETHING_NEW', keys: ['reason']);

      expect(error, isA<ValidationError>());
      expect(error.code, isNull);
    });

    for (final (status, code) in <(int, String?)>[
      (409, 'ACCESS_REQUEST_PENDING'),
      (409, 'ACCESS_REQUEST_DECIDED'),
      (403, 'STUDIO_ROLE_REQUIRED'),
      (404, 'ACCESS_REQUESTS_DISABLED'),
      (500, 'INTERNAL_ERROR'),
      (409, null),
    ]) {
      test('sends a $status ${code ?? 'without a code'} through platformError', () {
        final error = written(status, code);
        final direct = platformError(response(status, code));

        expect(error.runtimeType, direct.runtimeType);
        expect(error.code, direct.code);
      });
    }
  });

  group('platformError before any answer', () {
    test('maps the transport failures as the other repositories do', () {
      expect(platformError(OfflineException()), isA<NetworkError>().having((e) => e.code, 'code', 'network.offline'));
      expect(
        platformError(UntrustedCertificateException('Untrusted connection to platform.example.org:443')),
        isA<NetworkError>().having((e) => e.code, 'code', AppErrorCode.networkCertInvalid.key),
      );
      expect(platformError(RequestCancelledException()), isA<RequestCancelledError>());
      expect(
        platformError(NoSessionException('a sign-out is running')),
        isA<AuthError>().having((e) => e.code, 'code', AppErrorCode.authInvalidAccessToken.key),
      );
      expect(platformError(TimeoutBeforeSentException()), isA<TimeoutError>().having((e) => e.sent, 'sent', isFalse));
      expect(platformError(FetchDataException('TimeoutException')), isA<TimeoutError>());
      expect(platformError(FetchDataException('No Internet connection')), isA<NetworkError>());
    });

    test('maps a build without a Platform target to platformNotConfigured', () {
      final error = platformError(PlatformNotConfiguredException());

      expect(error, isA<NotFoundError>());
      expect(error.code, AppErrorCode.platformNotConfigured.key);
    });

    test('maps an answer a model cannot read to platformUnreadableAnswer', () {
      final error = platformError(const FormatException('The Platform identity has no email'));

      expect(error, isA<ServerError>());
      expect(error.code, AppErrorCode.platformUnreadableAnswer.key);
    });

    test('maps anything that is not an AppException to UnknownError', () {
      expect(platformError(StateError('x')), isA<UnknownError>());
    });
  });

  group('platformGrantWriteError', () {
    final grantRows = <(String, AppErrorCode)>[
      ('level', AppErrorCode.platformGrantLevelRefused),
      ('subject', AppErrorCode.platformGrantSubjectRefused),
      ('expiresAt', AppErrorCode.platformGrantExpiryRefused),
    ];
    for (final (key, appCode) in grantRows) {
      test('400 VALIDATION_FAILED on only $key -> ${appCode.key}', () {
        final error = platformGrantWriteError(response(400, 'VALIDATION_FAILED', keys: [key]));

        expect(error, isA<ValidationError>());
        expect(error.code, appCode.key);
      });
    }

    for (final keys in [
      <String>[],
      [''],
      ['body'],
      ['level', 'subject'],
      ['subject', 'expiresAt'],
      ['other'],
    ]) {
      test('400 VALIDATION_FAILED on $keys falls back to platformValidationFailed', () {
        final error = platformGrantWriteError(response(400, 'VALIDATION_FAILED', keys: keys));

        expect(error.code, AppErrorCode.platformValidationFailed.key);
      });
    }

    test('falls back to platformError for every other answer', () {
      for (final (status, code) in [
        (404, 'NOT_FOUND'),
        (403, 'LICENSE_USER_SEATS'),
        (503, 'DIRECTORY_UNAVAILABLE'),
        (400, null),
      ]) {
        final exception = response(status, code, keys: const ['level']);
        expect(platformGrantWriteError(exception), platformError(exception), reason: '$status $code');
      }
      expect(platformGrantWriteError(OfflineException()), platformError(OfflineException()));
    });
  });
}
