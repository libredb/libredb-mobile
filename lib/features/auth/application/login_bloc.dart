import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/core/logging/app_logger.dart';
import 'package:libredb_mobile/features/auth/application/usecases/sign_in_with_sso_usecase.dart';
import 'package:libredb_mobile/features/auth/domain/entities/sso_sign_in_result.dart';
import 'package:libredb_mobile/shared/utils/event_transformers.dart';

part 'login_event.dart';
part 'login_state.dart';

/// The sign-in through the identity provider.
class LoginBloc extends Bloc<LoginEvent, LoginState> {
  static final _log = AppLogger.getLogger("LoginBloc");

  /// Null in a build whose OpenID Connect settings break a rule, which has no sign-in, so [SsoSignInRequested] is never
  /// sent.
  final SignInWithSsoUseCase? _signInWithSsoUseCase;

  LoginBloc({this._signInWithSsoUseCase}) : super(const LoginInitialState()) {
    on<SsoSignInRequested>(_onSsoSignInRequested, transformer: EventTransformers.dropConcurrent());
    on<LoginReset>(_onReset);
  }

  /// A session ends only while the user is signed in, and the login routes send a signed-in user home, so no sign-in
  /// is running that the reset could overtake.
  void _onReset(LoginReset event, Emitter<LoginState> emit) {
    emit(const LoginInitialState());
  }

  /// The single sign-on stores the session itself, and succeeds only once Studio has accepted the account.
  Future<void> _onSsoSignInRequested(SsoSignInRequested event, Emitter<LoginState> emit) async {
    final signInWithSso = _signInWithSsoUseCase;
    if (signInWithSso == null) throw StateError('single sign-on is not configured in this build');
    _log.debug('BEGIN: onSsoSignInRequested');
    emit(const LoginLoadingState());
    final result = await signInWithSso();
    switch (result) {
      case SsoSignInSucceeded():
        emit(const LoginLoadedState());
        _log.debug('END: onSsoSignInRequested signed in');
      case SsoSignInCancelled():
        emit(const LoginInitialState());
        _log.info('END: onSsoSignInRequested the user left the provider page without signing in');
      case SsoSignInRejected(:final errorCode):
        emit(LoginErrorState(errorCode: errorCode));
        _log.error('END: onSsoSignInRequested error: {}', [errorCode.key]);
    }
  }
}
