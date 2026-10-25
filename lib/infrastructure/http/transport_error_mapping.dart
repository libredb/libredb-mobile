import 'package:libredb_mobile/core/errors/app_api_exception.dart';
import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';

/// The [AppError] of a failure before any response arrived, the same for every server: `studioError` and
/// `platformError` both use it.
AppError transportError(AppException error) {
  if (error is UntrustedCertificateException) {
    return NetworkError(error.toString(), code: AppErrorCode.networkCertInvalid.key);
  }
  if (error is RequestCancelledException) return RequestCancelledError(error.toString());
  if (error is NoSessionException) return AuthError(error.toString(), code: AppErrorCode.authInvalidAccessToken.key);
  if (error is OfflineException) return NetworkError(error.toString(), code: AppErrorCode.networkOffline.key);
  final message = error.toString();
  if (error is TimeoutBeforeSentException) return TimeoutError(message, sent: false);
  if (message.toLowerCase().contains('timeout')) return TimeoutError(message);
  return NetworkError(message);
}
