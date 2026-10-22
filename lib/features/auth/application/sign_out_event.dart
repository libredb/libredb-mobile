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
