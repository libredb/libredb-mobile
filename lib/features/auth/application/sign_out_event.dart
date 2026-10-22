part of 'sign_out_bloc.dart';

sealed class SignOutEvent extends Equatable {
  const SignOutEvent();

  @override
  List<Object?> get props => const [];
}

/// The user asked to sign out.
final class SignOutRequested extends SignOutEvent {
  const SignOutRequested();
}

/// The provider logout of an `oidc` sign-out failed after the session on this device was cleared.
final class _ProviderLogoutFailed extends SignOutEvent {
  const _ProviderLogoutFailed();
}
