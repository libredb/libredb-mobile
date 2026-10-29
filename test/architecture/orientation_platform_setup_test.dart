import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards that the platform files agree with the orientations `AppBootstrapConfig` asks for at start (#419).
///
/// The app is held upright on every form factor, so the bootstrap asks for `portraitUp` alone and both platform files
/// have to say the same thing, or the lock leaks around it:
///
/// - iOS takes the intersection of `UISupportedInterfaceOrientations` and the run-time list, so the iPhone key lists
///   portrait alone; a launch into landscape is then impossible, before Dart runs as well as after.
/// - The iPad key lists portrait alone as well, and is not exempted. The exemption was dropped because it protected
///   nothing: the only layout a rotation reaches is the one `AppBreakpoints.isCompactHeight` gates, a screen height
///   below 480, and no iPad reports that in landscape — the shortest is 744 logical pixels high.
/// - Android draws its first frame from the manifest, before Dart runs, so `.MainActivity` fixes
///   `android:screenOrientation="portrait"` itself, and no other activity may declare an orientation of its own.
///   Android 16 ignores that attribute at a smallest width of 600dp and above, because the app targets SDK 36, so an
///   Android tablet on 16 rotates whatever this says; that is a leak the app cannot close, not a leak it grants.
void main() {
  test('the iPhone orientations of Info.plist are portrait alone', () {
    expect(_plistOrientations('UISupportedInterfaceOrientations'), [
      'UIInterfaceOrientationPortrait',
    ], reason: '$_plistPath must list the one iPhone orientation the bootstrap asks for');
  });

  test('the iPad orientations of Info.plist are portrait alone, as on the iPhone', () {
    expect(_plistOrientations('UISupportedInterfaceOrientations~ipad'), [
      'UIInterfaceOrientationPortrait',
    ], reason: '$_plistPath must list the one iPad orientation the bootstrap asks for');
  });

  test('.MainActivity fixes its screen orientation to portrait, and no other activity declares one', () {
    final activities = _manifestActivities();
    final main = activities.where((attributes) => attributes.contains('android:name=".MainActivity"')).toList();

    expect(main, hasLength(1), reason: '$_manifestPath must declare .MainActivity exactly once');
    expect(
      main.single,
      contains('android:screenOrientation="portrait"'),
      reason:
          '$_manifestPath must fix the orientation of .MainActivity, or Android draws the first frame in landscape '
          'before the bootstrap asks for portrait',
    );
    for (final other in activities.where((attributes) => attributes != main.single)) {
      expect(
        other,
        isNot(contains('android:screenOrientation')),
        reason:
            '$_manifestPath must leave every activity other than .MainActivity without an orientation of its own, '
            'or one of them can still be shown sideways: $other',
      );
    }
  });
}

const _manifestPath = 'android/app/src/main/AndroidManifest.xml';

/// The attributes of each `<activity>` of the Android manifest, comments stripped, in the order they are declared.
List<String> _manifestActivities() {
  final manifest = File(_manifestPath).readAsStringSync().replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '');
  final activities = RegExp(r'<activity\b([^>]*)>')
      .allMatches(manifest)
      .map((match) => match[1]!.replaceAll(RegExp(r'\s+'), ' ').trim())
      .toList();
  expect(activities, isNotEmpty, reason: '$_manifestPath declares no activity');
  return activities;
}

const _plistPath = 'ios/Runner/Info.plist';

/// The orientations the array under [key] of `Info.plist` lists, in order.
List<String?> _plistOrientations(String key) {
  final plist = File(_plistPath).readAsStringSync().replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '');
  final array = RegExp('<key>${RegExp.escape(key)}</key>\\s*<array>(.*?)</array>', dotAll: true).firstMatch(plist);
  expect(array, isNotNull, reason: '$_plistPath has no $key array');
  return RegExp(r'<string>(.*?)</string>').allMatches(array![1]!).map((match) => match[1]).toList();
}
