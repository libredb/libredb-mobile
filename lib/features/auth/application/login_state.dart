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

final class LoginLoadedState extends LoginState {
  const LoginLoadedState({this.username, this.roles = const <String>[]});

  final String? username;

  /// Authorities resolved during login. Carried on the state so the
  /// session can be marked authenticated *synchronously* (with roles)
  /// before the success listener navigates — see `AppSessionListeners`.
  /// Reading them from storage in the listener instead opened a redirect
  /// race against the `returnUrl` deep link.
  final List<String> roles;

  @override
  List<Object?> get props => [username, roles];
}

final class LoginErrorState extends LoginState {
  const LoginErrorState({required this.errorCode});

  /// Translated by the UI via `errorCode.resolve(context)`. See
  /// `lib/shared/l10n/app_error_code_l10n.dart`.
  final AppErrorCode errorCode;

  @override
  List<Object?> get props => [errorCode];
}
