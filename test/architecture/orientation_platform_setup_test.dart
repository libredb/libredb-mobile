import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards that the platform files agree with the orientations `AppBootstrapConfig` asks for at start (#127).
///
/// - iOS takes the intersection of `UISupportedInterfaceOrientations` and the run-time list, so the iPhone key lists
///   exactly portrait and both landscape sides. The iPad key keeps all four, which iPad multitasking requires; the
///   run-time list still leaves the upside-down portrait out there.
/// - Android has no `android:screenOrientation` on any activity, so the run-time list alone decides; Flutter turns it
///   into `SCREEN_ORIENTATION_USER`, which follows the user's auto-rotate setting.
void main() {
  test('the iPhone orientations of Info.plist are portrait and both landscape sides', () {
    const plistPath = 'ios/Runner/Info.plist';
    final plist = File(plistPath).readAsStringSync().replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '');
    final array = RegExp(
      r'<key>UISupportedInterfaceOrientations</key>\s*<array>(.*?)</array>',
      dotAll: true,
    ).firstMatch(plist);
    expect(array, isNotNull, reason: '$plistPath has no UISupportedInterfaceOrientations array');

    final orientations = RegExp(r'<string>(.*?)</string>').allMatches(array![1]!).map((match) => match[1]).toList();
    expect(orientations, [
      'UIInterfaceOrientationPortrait',
      'UIInterfaceOrientationLandscapeLeft',
      'UIInterfaceOrientationLandscapeRight',
    ], reason: '$plistPath must list the iPhone orientations the bootstrap asks for');
  });

  test('no Android activity fixes its screen orientation', () {
    const manifestPath = 'android/app/src/main/AndroidManifest.xml';
    final manifest = File(manifestPath).readAsStringSync().replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '');

    expect(
      manifest,
      isNot(contains('android:screenOrientation')),
      reason: '$manifestPath must leave the orientation to the bootstrap, which allows portrait and landscape',
    );
  });
}
