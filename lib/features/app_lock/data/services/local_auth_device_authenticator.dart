import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:libredb_mobile/core/logging/app_logger.dart';
import 'package:libredb_mobile/features/app_lock/data/services/android_biometric_hardware.dart';
import 'package:libredb_mobile/features/app_lock/domain/services/device_authenticator.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';
import 'package:local_auth_darwin/local_auth_darwin.dart';

/// [IDeviceAuthenticator] over `local_auth`: biometrics with the device credential (PIN, pattern or password) as the
/// fallback, on Android through `BiometricPrompt`, which needs `MainActivity` to be a `FlutterFragmentActivity`.
class LocalAuthDeviceAuthenticator implements IDeviceAuthenticator {
  /// [hardwareKinds] answers the biometric kinds the device declares (`fingerprint`, `face`, `iris`), or null when it
  /// cannot say; it defaults to the Android channel and to null elsewhere, as iOS names its kind itself.
  LocalAuthDeviceAuthenticator({LocalAuthentication? auth, Future<Set<String>?> Function()? hardwareKinds})
    : _auth = auth ?? LocalAuthentication(),
      _hardwareKinds = hardwareKinds ?? _defaultHardwareKinds;

  static final _log = AppLogger.getLogger('LocalAuthDeviceAuthenticator');

  final LocalAuthentication _auth;
  final Future<Set<String>?> Function() _hardwareKinds;

  static Future<Set<String>?> _defaultHardwareKinds() async =>
      defaultTargetPlatform == TargetPlatform.android ? AndroidBiometricHardware.kinds() : null;

  /// On Android true when the device has a screen lock or enrolled biometrics, which Android allows only with a screen
  /// lock; on iOS when a passcode is set.
  @override
  Future<bool> canAuthenticate() => _auth.isDeviceSupported();

  @override
  Future<DeviceBiometric> availableBiometric() async {
    final types = await _auth.getAvailableBiometrics();
    // Kinds the platform names. Strong and weak are classes, not kinds (Android repeats them beside the kind), so they
    // count only when no kind is named.
    final kinds = {
      for (final type in types)
        ?switch (type) {
          BiometricType.face => DeviceBiometric.face,
          BiometricType.fingerprint => DeviceBiometric.fingerprint,
          BiometricType.iris => DeviceBiometric.iris,
          BiometricType.strong || BiometricType.weak => null,
        },
    };
    if (kinds.length == 1) return kinds.single;
    if (kinds.length > 1) return DeviceBiometric.several;
    if (types.isEmpty) return DeviceBiometric.none;
    // Only strong or weak: Android. Something is enrolled; the hardware flags name the kind only when the device has
    // exactly one, as with several it cannot be told which is enrolled.
    return await _singleHardwareKind() ?? DeviceBiometric.several;
  }

  Future<DeviceBiometric?> _singleHardwareKind() async {
    try {
      final declared = await _hardwareKinds();
      if (declared == null || declared.length != 1) return null;
      return switch (declared.single) {
        'face' => DeviceBiometric.face,
        'fingerprint' => DeviceBiometric.fingerprint,
        'iris' => DeviceBiometric.iris,
        _ => null,
      };
    } on PlatformException catch (e) {
      _log.warn('the biometric hardware check failed: {}', [e.code]);
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  @override
  Future<DeviceAuthResult> authenticate(DeviceAuthPrompt prompt) async {
    try {
      final authenticated = await _auth.authenticate(
        localizedReason: prompt.reason,
        authMessages: [
          AndroidAuthMessages(signInTitle: prompt.title, cancelButton: prompt.cancel),
          IOSAuthMessages(cancelButton: prompt.cancel),
        ],
        // The screen lock is the fallback, so a device without enrolled biometrics still unlocks.
        biometricOnly: false,
        // A prompt that the app's leaving closes stays closed; the user taps Unlock again.
        persistAcrossBackgrounding: false,
      );
      if (authenticated) return const DeviceAuthSucceeded();
      _log.warn('the device prompt ended without authentication');
      return const DeviceAuthFailed();
    } on LocalAuthException catch (e) {
      return switch (e.code) {
        LocalAuthExceptionCode.userCanceled ||
        LocalAuthExceptionCode.systemCanceled ||
        LocalAuthExceptionCode.timeout ||
        LocalAuthExceptionCode.userRequestedFallback => const DeviceAuthCancelled(),
        LocalAuthExceptionCode.noCredentialsSet => const DeviceAuthNoScreenLock(),
        LocalAuthExceptionCode.temporaryLockout ||
        LocalAuthExceptionCode.biometricLockout => const DeviceAuthFailed(lockedOut: true),
        _ => _failed(e),
      };
    }
  }

  static DeviceAuthResult _failed(LocalAuthException e) {
    _log.error('the device prompt failed: {} {}', [e.code.name, e.description]);
    return const DeviceAuthFailed();
  }
}
