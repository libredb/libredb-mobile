import 'package:dio/dio.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/infrastructure/http/api_target.dart';
import 'package:libredb_mobile/infrastructure/http/token_rotation.dart';

/// The only error code by which LibreDB Platform says that the bearer is not valid (libredb-platform
/// `src/shared/lib/bearer/errors.ts`).
const platformSessionEndedCode = 'BEARER_INVALID';

/// The [SessionExpiredPredicate] of LibreDB Platform: a 401 whose `error.code` is `BEARER_INVALID`, which starts one
/// token refresh.
///
/// A 401 without Platform's envelope, or with any other code, is not Platform refusing the token, so it reaches the
/// caller as an error and the session is kept. A 502 or 503 never ends the session, whatever its code.
bool isPlatformSessionExpired(DioException error) => _isBearerInvalid(error);

/// The [SessionRefusedPredicate] of LibreDB Platform: a 401 `BEARER_INVALID` for a request sent again with the token
/// the identity provider has just issued, which ends the session.
///
/// A deployment whose `libredb-mobile` token lacks Platform's audience answers this to every call, so its session ends
/// after the one refresh (docs/platform.md).
bool isPlatformSessionRefused(DioException error) => _isBearerInvalid(error);

bool _isBearerInvalid(DioException error) =>
    error.response?.statusCode == 401 &&
    const PlatformErrorEnvelope().codeOf(error.response?.data) == platformSessionEndedCode;

/// The [AccountRefusal] of LibreDB Platform: a 403 `ADMIN_ROLE_REQUIRED` (the token lacks the Platform admin role) or
/// `LICENSE_ADMIN_SEATS` (the license has no admin seat left for this account), on any route.
///
/// `LICENSE_EXPIRED`, `LICENSE_INVALID` and `LICENSE_USER_SEATS` are not refusals of the account: a grant `PUT` can
/// answer them (libredb-platform `docs/api/v1.md`), and refusing the whole account over one grant would lock the admin
/// out, so the caller shows them.
AppErrorCode? platformAccountRefusal(DioException error) {
  if (error.response?.statusCode != 403) return null;
  return switch (const PlatformErrorEnvelope().codeOf(error.response?.data)) {
    'ADMIN_ROLE_REQUIRED' => AppErrorCode.platformAdminRoleRequired,
    'LICENSE_ADMIN_SEATS' => AppErrorCode.platformLicenseAdminSeats,
    _ => null,
  };
}
