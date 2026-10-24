/// The texts of the system prompt, in the app language.
final class DeviceAuthPrompt {
  const DeviceAuthPrompt({required this.reason, required this.title, required this.cancel});

  /// Why the app asks, shown in the prompt.
  final String reason;

  /// The prompt's title on Android.
  final String title;

  /// The prompt's cancel button.
  final String cancel;
}

/// How a prompt of [IDeviceAuthenticator.authenticate] ended.
sealed class DeviceAuthResult {
  const DeviceAuthResult();
}

/// The user proved they own the device, with a biometric or the screen lock.
final class DeviceAuthSucceeded extends DeviceAuthResult {
  const DeviceAuthSucceeded();
}

/// The user or the system closed the prompt, such as by the back button or by leaving the app.
final class DeviceAuthCancelled extends DeviceAuthResult {
  const DeviceAuthCancelled();
}

/// The prompt ended without proof: [lockedOut] after too many attempts, which the device ends after a while.
final class DeviceAuthFailed extends DeviceAuthResult {
  const DeviceAuthFailed({this.lockedOut = false});

  final bool lockedOut;
}

/// The device has no screen lock, so it cannot prove who holds it.
final class DeviceAuthNoScreenLock extends DeviceAuthResult {
  const DeviceAuthNoScreenLock();
}

/// The device's own authentication: its biometrics, with its screen lock (PIN, pattern or password) as the fallback.
abstract interface class IDeviceAuthenticator {
  /// Whether the device has a screen lock, so [authenticate] can prove who holds it.
  Future<bool> canAuthenticate();

  /// Opens the system prompt with [prompt]'s texts and answers how it ended. Never retries by itself.
  Future<DeviceAuthResult> authenticate(DeviceAuthPrompt prompt);
}
