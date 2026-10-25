import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/core/logging/app_logger.dart';
import 'package:libredb_mobile/features/auth/application/usecases/sign_in_usecase.dart';
import 'package:libredb_mobile/features/auth/domain/entities/sso_sign_in_result.dart';
import 'package:libredb_mobile/shared/models/session_target.dart';
import 'package:libredb_mobile/shared/utils/event_transformers.dart';

part 'login_event.dart';
part 'login_state.dart';

/// The sign-in through the identity provider.
class LoginBloc extends Bloc<LoginEvent, LoginState> {
  static final _log = AppLogger.getLogger("LoginBloc");

  /// Null in a build whose OpenID Connect settings break a rule, which has no sign-in, so [SsoSignInRequested] is never
  /// sent.
  final SignInUseCase? _signInUseCase;

  /// Drops a request for either target while a sign-in runs.
  LoginBloc({this._signInUseCase}) : super(const LoginInitialState()) {
    on<SsoSignInRequested>(_onSsoSignInRequested, transformer: EventTransformers.dropConcurrent());
    on<LoginReset>(_onReset);
  }

  /// A session ends only while the user is signed in, and the login routes send a signed-in user home, so no sign-in
  /// is running that the reset could overtake.
  void _onReset(LoginReset event, Emitter<LoginState> emit) {
    emit(const LoginInitialState());
  }

  /// The single sign-on stores the session itself, and succeeds only once the gate of the event's target has accepted
  /// the account. The signed-in target is the one of the answer.
  Future<void> _onSsoSignInRequested(SsoSignInRequested event, Emitter<LoginState> emit) async {
    final signIn = _signInUseCase;
    if (signIn == null) throw StateError('single sign-on is not configured in this build');
    _log.debug('BEGIN: onSsoSignInRequested target: {}', [event.target.name]);
    emit(LoginLoadingState(target: event.target));
    final result = await signIn(event.target);
    switch (result) {
      case StudioSignInSucceeded():
        emit(const LoginLoadedState(target: SessionTarget.studio));
        _log.debug('END: onSsoSignInRequested signed in to Studio');
      case PlatformSignInSucceeded():
        emit(const LoginLoadedState(target: SessionTarget.platform));
        _log.debug('END: onSsoSignInRequested signed in to Platform');
      case SsoSignInCancelled():
        emit(const LoginInitialState());
        _log.info('END: onSsoSignInRequested the user left the provider page without signing in');
      case SsoSignInRejected(:final errorCode):
        emit(LoginErrorState(errorCode: errorCode));
        _log.error('END: onSsoSignInRequested error: {}', [errorCode.key]);
    }
  }
}
