part of 'app_lock_bloc.dart';

sealed class AppLockEvent extends Equatable {
  const AppLockEvent();

  @override
  List<Object?> get props => const [];
}

/// The events that change the lock's state from outside the prompt; they run one at a time, in order.
sealed class _AppLockControlEvent extends AppLockEvent {
  const _AppLockControlEvent();
}

/// Reads the stored settings; added once, when the bloc is created.
final class AppLockStarted extends _AppLockControlEvent {
  const AppLockStarted();
}

/// The app started with a stored session, which a cold start locks.
final class AppLockSessionRestored extends _AppLockControlEvent {
  const AppLockSessionRestored();
}

/// The user signed in at the identity provider, which proved who they are, so the app opens unlocked.
final class AppLockSignedIn extends _AppLockControlEvent {
  const AppLockSignedIn();
}

/// The session ended; the lock never covers the login page.
final class AppLockSignedOut extends _AppLockControlEvent {
  const AppLockSignedOut();
}

/// The settings section stored new [settings].
final class AppLockSettingsChanged extends _AppLockControlEvent {
  const AppLockSettingsChanged(this.settings);

  final AppLockSettings settings;

  @override
  List<Object?> get props => [settings];
}

final class _AppLockLifecycleChanged extends _AppLockControlEvent {
  const _AppLockLifecycleChanged(this.state);

  final AppLifecycleState state;

  @override
  List<Object?> get props => [state];
}

/// The user tapped Unlock: opens the system prompt with [prompt]'s texts. Dropped while a prompt is open, so two taps
/// never open two prompts.
final class AppLockUnlockRequested extends AppLockEvent {
  const AppLockUnlockRequested(this.prompt);

  final DeviceAuthPrompt prompt;

  @override
  List<Object?> get props => [prompt.reason];
}
