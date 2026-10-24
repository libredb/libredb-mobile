import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards that the platform files agree with the orientations `AppBootstrapConfig` asks for at start (#127).
///
/// - iOS takes the intersection of `UISupportedInterfaceOrientations` and the run-time list, so the iPhone key lists
///   exactly portrait and both landscape sides. The iPad key keeps all four, which iPad multitasking requires; with
///   multitasking on, iOS ignores the run-time list on the iPad, so all four apply there.
/// - Android has no `android:screenOrientation` on any activity, so the run-time list alone decides; Flutter turns it
///   into `SCREEN_ORIENTATION_USER`, which follows the user's auto-rotate setting.
void main() {
  test('the iPhone orientations of Info.plist are portrait and both landscape sides', () {
    expect(_plistOrientations('UISupportedInterfaceOrientations'), [
      'UIInterfaceOrientationPortrait',
      'UIInterfaceOrientationLandscapeLeft',
      'UIInterfaceOrientationLandscapeRight',
    ], reason: '$_plistPath must list the iPhone orientations the bootstrap asks for');
  });

  test('the iPad orientations of Info.plist are all four, as iPad multitasking requires', () {
    expect(
      _plistOrientations('UISupportedInterfaceOrientations~ipad'),
      unorderedEquals(const [
        'UIInterfaceOrientationPortrait',
        'UIInterfaceOrientationPortraitUpsideDown',
        'UIInterfaceOrientationLandscapeLeft',
        'UIInterfaceOrientationLandscapeRight',
      ]),
      reason: '$_plistPath must list all four iPad orientations, or the App Store refuses a multitasking build',
    );
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

const _plistPath = 'ios/Runner/Info.plist';

/// The orientations the array under [key] of `Info.plist` lists, in order.
List<String?> _plistOrientations(String key) {
  final plist = File(_plistPath).readAsStringSync().replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '');
  final array = RegExp('<key>${RegExp.escape(key)}</key>\\s*<array>(.*?)</array>', dotAll: true).firstMatch(plist);
  expect(array, isNotNull, reason: '$_plistPath has no $key array');
  return RegExp(r'<string>(.*?)</string>').allMatches(array![1]!).map((match) => match[1]).toList();
}
