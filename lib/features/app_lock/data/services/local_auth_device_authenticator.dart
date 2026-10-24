import 'package:libredb_mobile/core/logging/app_logger.dart';
import 'package:libredb_mobile/features/app_lock/domain/services/device_authenticator.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';
import 'package:local_auth_darwin/local_auth_darwin.dart';

/// [IDeviceAuthenticator] over `local_auth`: biometrics with the device credential (PIN, pattern or password) as the
/// fallback, on Android through `BiometricPrompt`, which needs `MainActivity` to be a `FlutterFragmentActivity`.
class LocalAuthDeviceAuthenticator implements IDeviceAuthenticator {
  LocalAuthDeviceAuthenticator({LocalAuthentication? auth}) : _auth = auth ?? LocalAuthentication();

  static final _log = AppLogger.getLogger('LocalAuthDeviceAuthenticator');

  final LocalAuthentication _auth;

  /// On Android true when the device has a screen lock or enrolled biometrics, which Android allows only with a screen
  /// lock; on iOS when a passcode is set.
  @override
  Future<bool> canAuthenticate() => _auth.isDeviceSupported();

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
