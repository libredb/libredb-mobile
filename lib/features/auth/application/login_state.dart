part of 'login_bloc.dart';

sealed class LoginState extends Equatable {
  const LoginState();
}

final class LoginInitialState extends LoginState {
  const LoginInitialState();

  @override
  List<Object?> get props => [];
}

/// A sign-in is running.
final class LoginLoadingState extends LoginState {
  const LoginLoadingState();

  @override
  List<Object?> get props => [];
}

/// Signed in, and Studio accepted the account. It carries no role: the role comes only from Studio's
/// `GET /api/auth/me`, which the shell reads.
final class LoginLoadedState extends LoginState {
  const LoginLoadedState();

  @override
  List<Object?> get props => [];
}

final class LoginErrorState extends LoginState {
  const LoginErrorState({required this.errorCode});

  /// Translated by the UI via `errorCode.resolve(context)`. See
  /// `lib/shared/l10n/app_error_code_l10n.dart`.
  final AppErrorCode errorCode;

  @override
  List<Object?> get props => [errorCode];
}
