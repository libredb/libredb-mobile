part of 'sign_out_bloc.dart';

sealed class SignOutState extends Equatable {
  const SignOutState();

  @override
  List<Object?> get props => const [];
}

final class SignOutInitial extends SignOutState {
  const SignOutInitial();
}

final class SignOutInProgress extends SignOutState {
  const SignOutInProgress();
}

/// The user is signed out. The subtypes beyond [SignedOut] tell what the sign-out could not finish.
sealed class SignOutDone extends SignOutState {
  const SignOutDone();
}

/// Signed out, with the stored session cleared.
final class SignedOut extends SignOutDone {
  const SignedOut();
}

/// Signed out, but the logout could not remove all stored data.
final class SignedOutWithDataLeft extends SignOutDone {
  const SignedOutWithDataLeft();
}

/// Signed out of the app in an `oidc` build, but not of the session at the identity provider.
final class SignedOutWithProviderSessionLeft extends SignOutDone {
  const SignedOutWithProviderSessionLeft();
}
