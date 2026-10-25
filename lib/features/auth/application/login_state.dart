part of 'login_bloc.dart';

sealed class LoginState extends Equatable {
  const LoginState();
}

final class LoginInitialState extends LoginState {
  const LoginInitialState();

  @override
  List<Object?> get props => [];
}

/// A sign-in for [target] is running.
final class LoginLoadingState extends LoginState {
  const LoginLoadingState({required this.target});

  final SessionTarget target;

  @override
  List<Object?> get props => [target];
}

/// Signed in, and the gate of [target] accepted the account. It carries neither a role nor an identity: the shell of
/// [target] loads the identity when it opens, from Studio's `GET /api/auth/me` or Platform's `GET /api/v1/me`.
final class LoginLoadedState extends LoginState {
  const LoginLoadedState({required this.target});

  final SessionTarget target;

  @override
  List<Object?> get props => [target];
}

final class LoginErrorState extends LoginState {
  const LoginErrorState({required this.errorCode});

  /// Translated by the UI via `errorCode.resolve(context)`. See
  /// `lib/shared/l10n/app_error_code_l10n.dart`.
  final AppErrorCode errorCode;

  @override
  List<Object?> get props => [errorCode];
}
