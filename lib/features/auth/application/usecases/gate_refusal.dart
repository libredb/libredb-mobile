import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';

/// The code shown when Studio's gate, `GET /api/auth/me`, refuses a sign-in or a mode switch: Studio's account code of
/// a 403 as it is, [AppErrorCode.studioAccountRefused] for any other [AuthError], which is a 401 that reached the
/// caller, and the code `studioError` gave for anything else.
AppErrorCode studioGateRefusal(AppError error) {
  final code = AppErrorCode.fromKey(error.code);
  return switch (error) {
    AuthError() when code == AppErrorCode.studioAccountHasNoRole || code == AppErrorCode.studioAccountHasNoIdentity =>
      code!,
    AuthError() => AppErrorCode.studioAccountRefused,
    _ => code ?? AppErrorCode.generic,
  };
}

/// The code shown when Platform's gate, `GET /api/v1/me`, refuses a sign-in or a mode switch: a `platform.*` code that
/// `platformError` gave as it is, whatever the error type, [AppErrorCode.platformAccountRefused] for any other
/// [AuthError], which is a 401 that reached the caller (`BEARER_INVALID` again after the refresh, or one without
/// Platform's envelope), and the code the shared transport mapping gave, or the generic one, for anything else.
AppErrorCode platformGateRefusal(AppError error) {
  final code = AppErrorCode.fromKey(error.code);
  return switch (error) {
    _ when code != null && code.key.startsWith('platform.') => code,
    AuthError() => AppErrorCode.platformAccountRefused,
    _ => code ?? AppErrorCode.generic,
  };
}
