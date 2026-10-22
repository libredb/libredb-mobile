import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';

part 'studio_account_refusal_state.dart';

/// Whether Studio refuses the signed-in account itself, which the shell shows as one full-screen page in place of every
/// screen.
///
/// From libredb-studio#1922 on, Studio answers 403 `BEARER_NO_ROLE` or `BEARER_NO_IDENTITY` on every route for a
/// verified token whose account it does not accept, and a fresh token is refused the same way, so this never refreshes
/// or ends the session: the user retries once an administrator has changed the account, or signs out.
class StudioAccountRefusalCubit extends Cubit<StudioAccountRefusalState> {
  StudioAccountRefusalCubit() : super(const StudioAccountAccepted());

  static const _refusals = {AppErrorCode.studioAccountHasNoRole, AppErrorCode.studioAccountHasNoIdentity};

  /// Studio refused the account with [code], one of its account codes.
  void refuse(AppErrorCode code) {
    if (!_refusals.contains(code)) throw ArgumentError.value(code, 'code', 'is not a refusal of the account');
    emit(StudioAccountRefused(code));
  }

  /// Studio accepted the account again, or the user signed out.
  void clear() => emit(const StudioAccountAccepted());
}
