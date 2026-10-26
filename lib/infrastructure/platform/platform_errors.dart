import 'package:libredb_mobile/core/errors/app_api_exception.dart';
import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/infrastructure/http/transport_error_mapping.dart';

/// The [AppError] for what a request to LibreDB Platform threw: an [AppException] from `PlatformApiClient`, a
/// [FormatException] from reading an answer whose shape is not the documented one, or anything else.
///
/// Platform's error body carries `error.code` (libredb-platform `docs/api/v1.md`); the code decides first, the status
/// after. The message is the exception text, which carries only the status, the code and the field keys, never
/// Platform's own `message`, which can name a user; a screen shows the translated message of the code.
AppError platformError(Object error) {
  if (error is FormatException) {
    return ServerError(error.message, code: AppErrorCode.platformUnreadableAnswer.key);
  }
  if (error is! AppException) return UnknownError(error.toString());
  if (error is PlatformNotConfiguredException) {
    return NotFoundError(error.toString(), code: AppErrorCode.platformNotConfigured.key);
  }

  final message = error.toString();
  final status = error.statusCode;
  switch (error.errorCode) {
    case 'BEARER_INVALID':
      return AuthError(message, code: AppErrorCode.authInvalidAccessToken.key);
    case 'ADMIN_ROLE_REQUIRED':
      return AuthError(message, code: AppErrorCode.platformAdminRoleRequired.key);
    case 'LICENSE_ADMIN_SEATS':
      return AuthError(message, code: AppErrorCode.platformLicenseAdminSeats.key);
    case 'LICENSE_USER_SEATS':
      return AuthError(message, code: AppErrorCode.platformLicenseUserSeats.key);
    case 'LICENSE_EXPIRED':
      return AuthError(message, code: AppErrorCode.platformLicenseExpired.key);
    case 'LICENSE_INVALID':
      return AuthError(message, code: AppErrorCode.platformLicenseInvalid.key);
    case 'API_DISABLED':
      return NotFoundError(message, code: AppErrorCode.platformApiDisabled.key);
    case 'NOT_FOUND':
      return NotFoundError(message, code: AppErrorCode.platformNotFound.key);
    // A grant's field refusals are platformGrantWriteError's: GET /v1/audit also has a subject filter, whose refusal
    // must not say that Keycloak does not know the user.
    case 'VALIDATION_FAILED':
      return ValidationError(message, code: AppErrorCode.platformValidationFailed.key);
    case 'IDENTITY_PROVIDER_UNAVAILABLE':
      return ServerError(message, code: AppErrorCode.platformIdentityProviderUnavailable.key);
    case 'DIRECTORY_UNAVAILABLE':
      return ServerError(message, code: AppErrorCode.platformDirectoryUnavailable.key);
    // KEYCLOAK_NOT_FOUND is the directory failing to read a user's roles (libredb-platform
    // src/shared/lib/keycloak/directory.ts), not an item the admin asked for.
    case 'KEYCLOAK_UNAVAILABLE' || 'KEYCLOAK_AUTH_ERROR' || 'KEYCLOAK_PERMISSION_ERROR' || 'KEYCLOAK_NOT_FOUND':
      return ServerError(message, code: AppErrorCode.platformKeycloakUnavailable.key);
    case 'PLAN_FEATURE_REQUIRED':
      return AuthError(message, code: AppErrorCode.platformPlanFeatureRequired.key);
    case 'PERMISSION_DENIED':
      return AuthError(message, code: AppErrorCode.platformPermissionDenied.key);
    case 'INTERNAL_ERROR':
      return ServerError(message, code: AppErrorCode.platformInternalError.key);
  }

  return switch (status) {
    400 => ValidationError(message),
    401 || 403 => AuthError(message),
    404 => NotFoundError(message),
    // Platform codes every 5xx of its own (libredb-platform `apiV1ErrorResponse`), so one without a code comes from the
    // edge in front of a stopped Platform.
    final int s when s >= 500 && error.errorCode == null => ServerError(
      message,
      code: AppErrorCode.platformUnreachable.key,
    ),
    final int s when s >= 500 => ServerError(message, code: AppErrorCode.platformInternalError.key),
    null => transportError(error),
    _ => UnknownError(message),
  };
}

/// The [AppError] for what a grant `PUT` threw: a 400 `VALIDATION_FAILED` refused on exactly one of the grant's fields,
/// `level`, `subject` or `expiresAt`, gets that field's code; anything else is [platformError].
AppError platformGrantWriteError(Object error) {
  if (error is BadRequestException && error.errorCode == 'VALIDATION_FAILED' && error.fieldErrorKeys.length == 1) {
    final code = switch (error.fieldErrorKeys.single) {
      'level' => AppErrorCode.platformGrantLevelRefused,
      'subject' => AppErrorCode.platformGrantSubjectRefused,
      'expiresAt' => AppErrorCode.platformGrantExpiryRefused,
      _ => null,
    };
    if (code != null) return ValidationError(error.toString(), code: code.key);
  }
  return platformError(error);
}
