part of 'app_lock_settings_bloc.dart';

/// The app lock part of the settings page.
sealed class AppLockSettingsState extends Equatable {
  const AppLockSettingsState();

  @override
  List<Object?> get props => const [];
}

/// Asking the device whether it has a screen lock.
final class AppLockSettingsChecking extends AppLockSettingsState {
  const AppLockSettingsChecking();
}

/// A state that knows whether the device has a screen lock, without which the switch cannot be turned on.
sealed class AppLockSettingsChecked extends AppLockSettingsState {
  const AppLockSettingsChecked({required this.canAuthenticate});

  final bool canAuthenticate;

  @override
  List<Object?> get props => [canAuthenticate];
}

/// Nothing is being changed.
final class AppLockSettingsReady extends AppLockSettingsChecked {
  const AppLockSettingsReady({required super.canAuthenticate});
}

/// A change is being confirmed by the prompt or stored.
final class AppLockSettingsSaving extends AppLockSettingsChecked {
  const AppLockSettingsSaving({required super.canAuthenticate});
}

/// [settings] are stored; the page hands them to the app lock.
final class AppLockSettingsSaved extends AppLockSettingsChecked {
  const AppLockSettingsSaved({required super.canAuthenticate, required this.settings});

  final AppLockSettings settings;

  @override
  List<Object?> get props => [canAuthenticate, settings];
}

/// The device refused to store the change, which is not in force.
final class AppLockSettingsFailure extends AppLockSettingsChecked {
  const AppLockSettingsFailure({required super.canAuthenticate, required this.errorCode});

  /// Shown through `errorCode.resolve(context)`.
  final AppErrorCode errorCode;

  @override
  List<Object?> get props => [canAuthenticate, errorCode];
}
