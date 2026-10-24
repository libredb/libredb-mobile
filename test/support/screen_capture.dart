import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:libredb_mobile/core/security/screen_capture_platform.dart';
import 'package:libredb_mobile/core/security/screen_capture_protection.dart';

/// A platform double that records what the app asks of the screen capture plugin, so a widget test counts leases
/// without a platform channel.
final class RecordingScreenCapturePlatform implements IScreenCapturePlatform {
  final calls = <String>[];

  @override
  Future<void> protectOn() async => calls.add('on');

  @override
  Future<void> protectOff() async => calls.add('off');
}

/// A switched-on [ScreenCaptureProtection] over a [RecordingScreenCapturePlatform], for a test to count its leases.
ScreenCaptureProtection recordingScreenCaptureProtection() =>
    ScreenCaptureProtection(platform: RecordingScreenCapturePlatform(), enabled: true);

/// [child] under [protection], or a new [recordingScreenCaptureProtection], as `AppScope` provides it to every guarded
/// value area. Put it above the `MaterialApp`, so a sheet the app shows over its routes finds it too.
Widget withScreenCaptureProtection(Widget child, {ScreenCaptureProtection? protection}) =>
    RepositoryProvider<ScreenCaptureProtection>.value(
      value: protection ?? recordingScreenCaptureProtection(),
      child: child,
    );
