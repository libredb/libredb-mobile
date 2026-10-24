import 'package:libredb_mobile/core/logging/app_logger.dart';
import 'package:libredb_mobile/core/security/screen_capture_platform.dart';

/// Screen capture protection for the screens that show data, counted in leases.
///
/// Protection is on while any caller holds a lease ([acquire]) and turns off when the last one is released
/// ([release]), so closing an inner protected area never uncovers an outer one that is still on screen.
/// `ScreenCaptureGuard` holds a lease for a widget; `AppScope` provides the app's one instance.
///
/// [isEnabled] is the build's switch (`AppConfig.screenCaptureProtection`): switched off, [acquire] takes no lease and
/// the platform is never called, so every screen can be captured.
class ScreenCaptureProtection {
  ScreenCaptureProtection({required this._platform, required bool enabled}) : isEnabled = enabled;

  static final _log = AppLogger.getLogger('ScreenCaptureProtection');

  final IScreenCapturePlatform _platform;

  /// Whether the build protects its data screens at all.
  final bool isEnabled;

  int _leases = 0;

  /// The leases held now.
  int get leases => _leases;

  /// Whether protection is on: at least one lease is held.
  bool get isEngaged => _leases > 0;

  /// Takes a lease; the first one turns protection on. A no-op while switched off.
  Future<void> acquire() async {
    if (!isEnabled) return;
    // Counted before the call, so two callers in a row turn it on once.
    _leases++;
    if (_leases > 1) return;
    try {
      await _platform.protectOn();
    } catch (e, st) {
      _log.warn('Turning screen capture protection on failed: {}\n{}', [e, st]);
    }
  }

  /// Releases a lease; the last one turns protection off. A no-op while switched off.
  ///
  /// Throws a [StateError] when no lease is held, since that means a holder released twice and the count no longer
  /// says what is on screen.
  Future<void> release() async {
    if (!isEnabled) return;
    if (_leases == 0) throw StateError('Released a screen capture lease that was never taken');
    _leases--;
    if (_leases > 0) return;
    try {
      await _platform.protectOff();
    } catch (e, st) {
      _log.warn('Turning screen capture protection off failed: {}\n{}', [e, st]);
    }
  }
}
