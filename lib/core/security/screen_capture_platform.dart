import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:screen_protector/screen_protector.dart';

/// The platform calls behind [ScreenCaptureProtection], narrow so a test counts them without a platform channel.
abstract interface class IScreenCapturePlatform {
  /// Keeps the app's window out of screenshots, screen recordings and the recent-apps preview where the platform can.
  Future<void> protectOn();

  /// Lets the window be captured again.
  Future<void> protectOff();
}

/// The app's [IScreenCapturePlatform].
///
/// Android: `FLAG_SECURE` through the [channel] that `MainActivity` answers (`SecureWindow.kt`), so a screenshot or a
/// recording is black and the recent-apps preview is black. `MainActivity` answers whether the flag is set on the
/// window after the call; when that is not what was asked, the call throws a [ScreenCaptureFlagException], and a
/// refusal (no window, a window that threw) throws its `PlatformException`, so protection is never assumed.
/// iOS: no public API blocks a screenshot; `screen_protector` covers the task-switcher snapshot with a blur.
final class ScreenCapturePlatform implements IScreenCapturePlatform {
  const ScreenCapturePlatform();

  static const channel = MethodChannel('org.libredb.mobile/screen_capture');

  @override
  Future<void> protectOn() => switch (defaultTargetPlatform) {
    TargetPlatform.android => _setSecure(true),
    TargetPlatform.iOS => ScreenProtector.protectDataLeakageWithBlur(),
    final platform => Future.error(UnsupportedError('no screen capture protection on ${platform.name}')),
  };

  @override
  Future<void> protectOff() => switch (defaultTargetPlatform) {
    TargetPlatform.android => _setSecure(false),
    TargetPlatform.iOS => ScreenProtector.protectDataLeakageWithBlurOff(),
    final platform => Future.error(UnsupportedError('no screen capture protection on ${platform.name}')),
  };

  static Future<void> _setSecure(bool secure) async {
    final isSet = await channel.invokeMethod<bool>('setSecure', {'secure': secure});
    if (isSet != secure) throw ScreenCaptureFlagException(requested: secure, isSet: isSet);
  }
}

/// The window's `FLAG_SECURE` is not what the app asked for after setting or clearing it.
final class ScreenCaptureFlagException implements Exception {
  const ScreenCaptureFlagException({required this.requested, required this.isSet});

  /// Whether the app asked for the flag set.
  final bool requested;

  /// Whether `MainActivity` reports the flag set afterwards; null when its answer carried no state.
  final bool? isSet;

  @override
  String toString() =>
      'ScreenCaptureFlagException: asked to ${requested ? 'set' : 'clear'} FLAG_SECURE, but the window reports it '
      '${switch (isSet) {
        true => 'set',
        false => 'clear',
        null => 'unknown',
      }}';
}
