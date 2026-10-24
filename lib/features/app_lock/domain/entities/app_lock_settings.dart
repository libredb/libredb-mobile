import 'package:equatable/equatable.dart';

/// How long the app may stay in the background before the app lock asks again.
enum AppLockTimeout {
  immediately(Duration.zero),
  oneMinute(Duration(minutes: 1)),
  fiveMinutes(Duration(minutes: 5)),
  fifteenMinutes(Duration(minutes: 15));

  const AppLockTimeout(this.duration);

  /// The time in the background after which a resume locks the app.
  final Duration duration;
}

/// The user's app lock choice on this device: whether the app asks for the device's biometrics or screen lock, and
/// after how long in the background.
final class AppLockSettings extends Equatable {
  const AppLockSettings({required this.enabled, required this.timeout});

  /// Off, with the default timeout of five minutes, as on a device that stored no choice.
  static const defaults = AppLockSettings(enabled: false, timeout: AppLockTimeout.fiveMinutes);

  final bool enabled;
  final AppLockTimeout timeout;

  AppLockSettings copyWith({bool? enabled, AppLockTimeout? timeout}) =>
      AppLockSettings(enabled: enabled ?? this.enabled, timeout: timeout ?? this.timeout);

  @override
  List<Object?> get props => [enabled, timeout];
}
