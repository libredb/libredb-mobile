import 'package:libredb_mobile/core/errors/app_api_exception.dart';
import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';

/// The [AppError] for what a request to LibreDB Studio threw: an [AppException] from `ApiClient`, a [FormatException]
/// from reading an answer whose shape is not the documented one, or anything else.
///
/// Studio's error body carries a code (`src/lib/api/error-codes.ts` in Studio), and its statuses are overloaded: a 401
/// `AUTH_ERROR` is a database refusing its credential and a 403 `AUTH_ERROR` a connection the user's role may not
/// use, while only `AUTH_REQUIRED` is an ended session. The code decides first, the status after. The message is the
/// server's own words when it sent some, for a screen such as the SQL editor that must show a database error; other
/// screens show the translated message of the code.
AppError studioError(Object error) {
  if (error is FormatException) {
    return ServerError(error.message, code: AppErrorCode.studioUnreadableAnswer.key);
  }
  if (error is! AppException) return UnknownError(error.toString());

  final message = error.serverMessage ?? error.toString();
  final status = error.statusCode;
  switch (error.errorCode) {
    case 'AUTH_REQUIRED':
      return AuthError(message, code: AppErrorCode.authInvalidAccessToken.key);
    case 'AUTH_ERROR':
      final code = status == 403 ? AppErrorCode.studioConnectionNotAvailable : AppErrorCode.studioDatabaseAuth;
      return AuthError(message, code: code.key, fixStatement: error.fixStatement);
    case 'CONNECTION_NOT_FOUND':
      return NotFoundError(message, code: AppErrorCode.studioConnectionNotAvailable.key);
    case 'PERMISSION_DENIED':
      return AuthError(message, code: AppErrorCode.studioPermissionDenied.key);
    case 'CUSTOM_CONNECTIONS_DISABLED':
      return AuthError(message, code: AppErrorCode.studioCustomConnectionsDisabled.key);
    case 'QUERY_ERROR':
      return ValidationError(message, code: AppErrorCode.studioQueryError.key, position: error.position);
    case 'QUERY_CANCELLED':
      return ServerError(message, code: AppErrorCode.studioQueryCancelled.key);
    case 'CONFIG_ERROR':
      return ValidationError(message, code: AppErrorCode.studioConfigError.key);
    case 'TIMEOUT_ERROR':
      return TimeoutError(message, code: AppErrorCode.studioTimeout.key);
    case 'CONNECTION_ERROR' || 'POOL_EXHAUSTED':
      return ServerError(message, code: AppErrorCode.studioDatabaseUnreachable.key);
    case 'GOVERNANCE_UNAVAILABLE' || 'AUDIT_UNAVAILABLE':
      return ServerError(message, code: AppErrorCode.studioGovernanceUnavailable.key);
    case 'IDENTITY_PROVIDER_UNAVAILABLE':
      return ServerError(message, code: AppErrorCode.studioIdentityProviderUnavailable.key);
    // A verified token whose account Studio refuses, answered with 403 from libredb-studio#1922 on.
    case 'BEARER_NO_ROLE':
      return AuthError(message, code: AppErrorCode.studioAccountHasNoRole.key);
    case 'BEARER_NO_IDENTITY':
      return AuthError(message, code: AppErrorCode.studioAccountHasNoIdentity.key);
    case 'TRANSACTION_NOT_OWNED':
      return ValidationError(message, code: AppErrorCode.studioTransactionNotOwned.key);
    case 'TRANSACTION_CREDENTIAL_CHANGED':
      return ServerError(message, code: AppErrorCode.studioTransactionCredentialChanged.key);
  }

  if (error.errorCode == 'RATE_LIMITED' || status == 429) {
    return RateLimitedError(message, code: AppErrorCode.studioRateLimited.key, retryAfter: error.retryAfter);
  }
  return switch (status) {
    400 => ValidationError(message),
    // Only a console engine's text bound answers 413, with a sentence that names the size and never the text.
    413 => ValidationError(message, code: AppErrorCode.studioStatementTooLarge.key),
    401 || 403 => AuthError(message),
    404 => NotFoundError(message),
    final int s when s >= 500 => ServerError(message),
    null => _transportError(error),
    _ => UnknownError(message),
  };
}

/// A failure before any response arrived, as the other repositories report it.
AppError _transportError(AppException error) {
  if (error is UntrustedCertificateException) {
    return NetworkError(error.toString(), code: AppErrorCode.networkCertInvalid.key);
  }
  if (error is RequestCancelledException) return RequestCancelledError(error.toString());
  if (error is OfflineException) return NetworkError(error.toString(), code: AppErrorCode.networkOffline.key);
  final message = error.toString();
  if (message.toLowerCase().contains('timeout')) return TimeoutError(message);
  return NetworkError(message);
}
