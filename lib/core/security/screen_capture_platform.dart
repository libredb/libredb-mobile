import 'package:screen_protector/screen_protector.dart';

/// The platform calls behind [ScreenCaptureProtection], narrow so a test counts them without a platform channel.
abstract interface class IScreenCapturePlatform {
  /// Keeps the app's window out of screenshots, screen recordings and the recent-apps preview where the platform can.
  Future<void> protectOn();

  /// Lets the window be captured again.
  Future<void> protectOff();
}

/// [IScreenCapturePlatform] over `screen_protector`.
///
/// Android: `FLAG_SECURE`, so a screenshot or a recording is black and the recent-apps preview is black.
/// iOS: no public API blocks a screenshot; a blurred view covers the task-switcher snapshot.
final class ScreenProtectorPlatform implements IScreenCapturePlatform {
  const ScreenProtectorPlatform();

  @override
  Future<void> protectOn() async {
    await ScreenProtector.protectDataLeakageOn();
    await ScreenProtector.protectDataLeakageWithBlur();
  }

  @override
  Future<void> protectOff() async {
    await ScreenProtector.protectDataLeakageOff();
    await ScreenProtector.protectDataLeakageWithBlurOff();
  }
}
