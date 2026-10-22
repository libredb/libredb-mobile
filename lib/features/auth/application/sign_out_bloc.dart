import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/core/logging/app_logger.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/auth/application/usecases/logout_usecase.dart';
import 'package:libredb_mobile/features/auth/application/usecases/sso_sign_out_usecase.dart';
import 'package:libredb_mobile/shared/utils/event_transformers.dart';

part 'sign_out_event.dart';
part 'sign_out_state.dart';

/// The sign-out the user starts.
class SignOutBloc extends Bloc<SignOutEvent, SignOutState> {
  SignOutBloc({required this._logoutUseCase, this._ssoSignOutUseCase}) : super(const SignOutInitial()) {
    // A sign-out waits for Studio's record, so a second tap meanwhile would post a second record and start a second
    // provider logout.
    on<SignOutRequested>(_onSignOutRequested, transformer: EventTransformers.dropConcurrent());
    on<_ProviderLogoutFailed>((event, emit) => emit(const SignedOutWithProviderSessionLeft()));
  }

  static final _log = AppLogger.getLogger('SignOutBloc');

  final LogoutUseCase _logoutUseCase;

  /// The logout that also ends the session at the identity provider, which runs instead of [_logoutUseCase]; null in
  /// a misconfigured build, which cannot reach the provider.
  final SsoSignOutUseCase? _ssoSignOutUseCase;

  /// Signs out even when the logout cannot clear all that the session stored, as SessionCubit.endSession does: the
  /// user asked to leave, and staying signed in would keep the session open on this device. [SignedOutWithDataLeft]
  /// then tells AppSessionListeners to say that stored data stayed behind, and [SignedOutWithProviderSessionLeft] that
  /// the session at the identity provider may still be active.
  Future<void> _onSignOutRequested(SignOutRequested event, Emitter<SignOutState> emit) async {
    emit(const SignOutInProgress());
    final ssoSignOut = _ssoSignOutUseCase;
    if (ssoSignOut != null) return _onSsoSignOut(ssoSignOut, emit);
    final result = await _logoutUseCase();
    switch (result) {
      case Success():
        emit(const SignedOut());
      case Failure(:final error) when error.code == AppErrorCode.authOidcLogoutIncomplete.key:
        emit(const SignedOutWithProviderSessionLeft());
      case Failure(:final error):
        emit(const SignedOutWithDataLeft());
        _log.error('END:onSignOutRequested signed out, but the stored session was not fully cleared: {}', [
          error.message,
        ]);
    }
  }

  /// The sign-out of an `oidc` build ends as soon as the session on this device is cleared, so the login page shows
  /// while the provider logout goes on, which waits for the browser and the provider. When the provider logout then
  /// fails, [SignedOutWithProviderSessionLeft] follows, unless the wipe failed: [SignedOutWithDataLeft] stays, since
  /// data left on this device matters more. The handler ends with the local sign-out, so the provider logout, which
  /// waits for the browser, does not keep a later sign-out from running.
  Future<void> _onSsoSignOut(SsoSignOutUseCase signOut, Emitter<SignOutState> emit) async {
    final signedOut = await signOut();
    switch (signedOut.cleared) {
      case Success():
        emit(const SignedOut());
      case Failure(:final error):
        emit(const SignedOutWithDataLeft());
        _log.error('END:onSignOutRequested signed out, but the stored session was not fully cleared: {}', [
          error.message,
        ]);
    }
    if (signedOut.cleared is Failure) return;
    unawaited(
      signedOut.providerLogout.then((providerLogout) {
        if (providerLogout is Failure && !isClosed) add(const _ProviderLogoutFailed());
      }),
    );
  }
}
