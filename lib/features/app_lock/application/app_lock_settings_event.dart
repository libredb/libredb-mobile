part of 'app_lock_settings_bloc.dart';

sealed class AppLockSettingsEvent extends Equatable {
  const AppLockSettingsEvent();

  @override
  List<Object?> get props => const [];
}

/// The section opened: asks the device whether it has a screen lock.
final class AppLockSettingsOpened extends AppLockSettingsEvent {
  const AppLockSettingsOpened();
}

/// The user changed [current] to [next]. Turning the lock on first asks the prompt with [prompt]'s texts, so only the
/// device's owner can turn it on. Dropped while a change is running.
final class AppLockSettingsChangeRequested extends AppLockSettingsEvent {
  const AppLockSettingsChangeRequested({required this.current, required this.next, required this.prompt});

  final AppLockSettings current;
  final AppLockSettings next;
  final DeviceAuthPrompt prompt;

  @override
  List<Object?> get props => [current, next, prompt.reason];
}
