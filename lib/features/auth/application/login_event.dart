part of 'login_bloc.dart';

abstract class LoginEvent extends Equatable {
  const LoginEvent();
}

/// Starts a sign-in through the OpenID Connect provider for [target], the entry the user chose.
final class SsoSignInRequested extends LoginEvent {
  const SsoSignInRequested({required this.target});

  final SessionTarget target;

  @override
  List<Object?> get props => [target];
}

/// Returns to a blank sign-in when the session ends: the next user must not inherit what the signed-out user's
/// sign-in left on the page.
final class LoginReset extends LoginEvent {
  const LoginReset();

  @override
  List<Object?> get props => [];
}
