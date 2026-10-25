import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';

part 'platform_account_refusal_state.dart';

/// Whether LibreDB Platform refuses the signed-in admin itself, which the Platform shell shows as one full-screen page
/// in place of every screen.
///
/// Platform answers 403 `ADMIN_ROLE_REQUIRED` for a token without the Platform admin role and 403
/// `LICENSE_ADMIN_SEATS` when the license has no admin seat left for the account, on every route; a fresh token is
/// refused the same way, so this never refreshes or ends the session: the admin retries once the account or the
/// license has changed, or signs out.
class PlatformAccountRefusalCubit extends Cubit<PlatformAccountRefusalState> {
  PlatformAccountRefusalCubit() : super(const PlatformAccountAccepted());

  static const _refusals = {AppErrorCode.platformAdminRoleRequired, AppErrorCode.platformLicenseAdminSeats};

  /// Platform refused the account with [code], one of its two account codes.
  void refuse(AppErrorCode code) {
    if (!_refusals.contains(code)) throw ArgumentError.value(code, 'code', 'is not a refusal of the account');
    emit(PlatformAccountRefused(code));
  }

  /// Platform accepted the account again, or the admin signed out.
  void clear() => emit(const PlatformAccountAccepted());
}
