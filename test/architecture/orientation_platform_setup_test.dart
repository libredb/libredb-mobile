import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards that the platform files agree with the orientations `AppBootstrapConfig` asks for at start (#419).
///
/// The app is held upright, so the bootstrap asks for `portraitUp` alone, and both platform files have to say the same
/// thing, or the lock leaks around it:
///
/// - iOS takes the intersection of `UISupportedInterfaceOrientations` and the run-time list, so the iPhone key lists
///   portrait alone; a launch into landscape is then impossible, before Dart runs as well as after.
/// - The iPad key keeps all four, which iPad multitasking requires; with multitasking on, iOS ignores the run-time
///   list on the iPad, so all four apply there and the tablet layout stays reachable on an iPad.
/// - Android draws its first frame from the manifest, before Dart runs, so `.MainActivity` fixes
///   `android:screenOrientation="portrait"` itself. Android 16 ignores that at a smallest width of 600dp and above,
///   because the app targets SDK 36, so an Android tablet on 16 is free as well.
void main() {
  test('the iPhone orientations of Info.plist are portrait alone', () {
    expect(_plistOrientations('UISupportedInterfaceOrientations'), [
      'UIInterfaceOrientationPortrait',
    ], reason: '$_plistPath must list the one iPhone orientation the bootstrap asks for');
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

  test('the Android launcher activity fixes its screen orientation to portrait', () {
    const manifestPath = 'android/app/src/main/AndroidManifest.xml';
    final manifest = File(manifestPath).readAsStringSync().replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '');
    final activity = RegExp(r'<activity\b(.*?)>', dotAll: true).firstMatch(manifest);
    expect(activity, isNotNull, reason: '$manifestPath declares no activity');

    expect(
      activity![1],
      contains('android:screenOrientation="portrait"'),
      reason:
          '$manifestPath must fix the orientation of .MainActivity, or Android draws the first frame in landscape '
          'before the bootstrap asks for portrait',
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
