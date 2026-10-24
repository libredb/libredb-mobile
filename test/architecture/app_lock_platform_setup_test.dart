import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the platform files the app lock (lib/features/app_lock) needs; a build succeeds without any of them, and the
/// lock then fails only on a device.
///
/// - local_auth shows `BiometricPrompt` only from a `FragmentActivity`, so `MainActivity` is a
///   `FlutterFragmentActivity`, and it registers the recent-apps preview channel.
/// - local_auth_android needs a `Theme.AppCompat` parent for the activity's themes, or its prompt crashes on Android 8.
/// - iOS refuses Face ID without `NSFaceIDUsageDescription`, which the app gives in English and Turkish.
void main() {
  test('MainActivity is a FlutterFragmentActivity and registers the recent-apps preview channel', () {
    final activity = File('android/app/src/main/kotlin/org/libredb/mobile/MainActivity.kt').readAsStringSync();

    expect(activity, contains('class MainActivity : FlutterFragmentActivity()'));
    expect(activity, contains('RecentsPreview.register('));
  });

  test('the launch and normal themes inherit from Theme.AppCompat, in the light and the dark styles', () {
    for (final path in [
      'android/app/src/main/res/values/styles.xml',
      'android/app/src/main/res/values-night/styles.xml',
    ]) {
      final styles = File(path).readAsStringSync().replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '');
      for (final name in ['LaunchTheme', 'NormalTheme']) {
        expect(
          RegExp('<style name="$name" parent="Theme\\.AppCompat[.A-Za-z]*">').hasMatch(styles),
          isTrue,
          reason: '$path: $name must inherit from a Theme.AppCompat theme',
        );
      }
    }
  });

  test('Info.plist explains Face ID in English, and InfoPlist.strings in English and Turkish', () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync().replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '');
    expect(plist, matches(RegExp(r'<key>NSFaceIDUsageDescription</key>\s*<string>[^<]+</string>')));

    for (final language in ['en', 'tr']) {
      final strings = File('ios/Runner/$language.lproj/InfoPlist.strings').readAsStringSync();
      expect(strings, matches(RegExp(r'"NSFaceIDUsageDescription" = "[^"]+";')), reason: '$language.lproj');
    }

    final project = File('ios/Runner.xcodeproj/project.pbxproj').readAsStringSync();
    expect(project, contains('en.lproj/InfoPlist.strings'));
    expect(project, contains('tr.lproj/InfoPlist.strings'));
    expect(project, contains('InfoPlist.strings in Resources'));
  });
}
