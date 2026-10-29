import 'package:flutter/services.dart';

/// The biometric kinds an Android device declares, from the package manager's feature flags through a method channel
/// that `MainActivity` answers (`BiometricHardware.kt`).
///
/// `local_auth` on Android reports only the strong and weak classes, never the kind. A feature flag says what the
/// device has, not what is enrolled, so this is only a hint: it names a kind to the lock screen when exactly one is
/// declared and `local_auth` says something is enrolled.
abstract final class AndroidBiometricHardware {
  static const channel = MethodChannel('org.libredb.mobile/biometric_hardware');

  /// Kind ids such as `fingerprint`, `face` and `iris`; throws a `PlatformException` or `MissingPluginException` when
  /// the platform cannot answer.
  static Future<Set<String>?> kinds() async {
    final kinds = await channel.invokeListMethod<String>('kinds');
    return kinds?.toSet();
  }
}
