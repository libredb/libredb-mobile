part of 'app_lock_bloc.dart';

/// Why a lock cannot be opened on this device.
enum AppLockUnavailableReason {
  /// The device has no screen lock, so it cannot prove who holds it; only signing out is left.
  noScreenLock,
}

/// Why the last prompt left the app locked; a cancelled prompt sets none.
enum AppLockFailure {
  /// The prompt ended without proof.
  failed,

  /// Too many attempts: the device refuses more for a while.
  lockedOut,

  /// The device could not tell whether it has a screen lock, so the lock stays; Unlock asks the prompt, which says
  /// what is wrong.
  checkFailed,
}

/// The app lock: whether the lock screen covers the app.
sealed class AppLockState extends Equatable {
  const AppLockState();

  /// Whether the lock screen covers the app now.
  bool get coversApp => switch (this) {
    AppLockLocked() || AppLockAuthenticating() || AppLockUnavailable() => true,
    AppLockStarting() || AppLockOff() || AppLockUnlocked() || AppLockChecking() || AppLockIdleSigningOut() => false,
  };

  /// Whether the signed-in pages must stay hidden now: under the lock screen, while a required lock checks the device,
  /// or while the idle sign-out ends the session.
  bool get hidesApp => coversApp || this is AppLockChecking || this is AppLockIdleSigningOut;

  @override
  List<Object?> get props => const [];
}

/// The stored settings are still being read; the app shows no signed-in page until they are.
final class AppLockStarting extends AppLockState {
  const AppLockStarting();
}

/// A state that knows the settings it follows.
sealed class AppLockSettled extends AppLockState {
  const AppLockSettled({required this.settings});

  final AppLockSettings settings;

  @override
  List<Object?> get props => [settings];
}

/// The lock is off: the user has not turned it on and the build does not require it.
final class AppLockOff extends AppLockSettled {
  const AppLockOff({required super.settings});
}

/// The lock is on and open, or nobody is signed in, which it never locks.
final class AppLockUnlocked extends AppLockSettled {
  const AppLockUnlocked({required super.settings});
}

/// The lock screen covers the app and offers Unlock and Sign out; [failure] says why the last prompt did not open it.
final class AppLockLocked extends AppLockSettled {
  const AppLockLocked({required super.settings, this.failure});

  final AppLockFailure? failure;

  @override
  List<Object?> get props => [settings, failure];
}

/// A required lock checks whether the device can lock after a sign-in; the pages stay hidden, without the lock
/// screen, until it answers.
final class AppLockChecking extends AppLockSettled {
  const AppLockChecking({required super.settings});
}

/// A resume past the idle period: the idle sign-out ends the session, so the pages stay hidden, without the lock
/// screen, until the login page shows.
final class AppLockIdleSigningOut extends AppLockSettled {
  const AppLockIdleSigningOut({required super.settings});
}

/// The system prompt is open over the lock screen.
final class AppLockAuthenticating extends AppLockSettled {
  const AppLockAuthenticating({required super.settings});
}

/// The lock screen covers the app but cannot be opened on this device, for [reason]; it offers only Sign out.
final class AppLockUnavailable extends AppLockSettled {
  const AppLockUnavailable({required super.settings, required this.reason});

  final AppLockUnavailableReason reason;

  @override
  List<Object?> get props => [settings, reason];
}
