part of 'login_bloc.dart';

abstract class LoginEvent extends Equatable {
  const LoginEvent();
}

/// Starts a sign-in through the OpenID Connect provider.
final class SsoSignInRequested extends LoginEvent {
  const SsoSignInRequested();

  @override
  List<Object?> get props => [];
}

/// Returns to a blank sign-in when the session ends: the next user must not inherit what the signed-out user's
/// sign-in left on the page.
final class LoginReset extends LoginEvent {
  const LoginReset();

  @override
  List<Object?> get props => [];
}
