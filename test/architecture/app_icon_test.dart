import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Fails while either platform ships the Flutter framework's own logo as the app icon.
///
/// `flutter create` writes a blue chevron into both icon sets, and nothing ever replaced it: the Play listing icon
/// of #197 is a different asset, uploaded to the console, so the store page showed LibreDB's mark while the
/// installed app showed the framework's. iOS review rejects a build whose icon is the default; Android does not,
/// which is worse, because it ships (#390).
///
/// The guard states what the icons must **not** be rather than keeping a second copy of what they are. A hash of
/// the shipped art would have to be updated every time the mark is redrawn, and would say nothing about the next
/// platform this project adds; the framework's own defaults never change, so a comparison against them keeps
/// working without maintenance.
void main() {
  /// The icons both platforms ship, and the ones this guard refuses to let be the framework's.
  const shipped = <String>[
    'android/app/src/main/res/mipmap-mdpi/ic_launcher.png',
    'android/app/src/main/res/mipmap-hdpi/ic_launcher.png',
    'android/app/src/main/res/mipmap-xhdpi/ic_launcher.png',
    'android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png',
    'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png',
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png',
  ];

  /// The Flutter logo is drawn in exactly three blues and nothing else. A real product icon has other colours in
  /// it, so "contains the framework's palette and almost nothing else" identifies the default without a hash that
  /// has to be maintained — and identifies it at every size at once.
  bool looksLikeTheFrameworkLogo(File file) {
    final bytes = file.readAsBytesSync();
    // The default art is a flat three-colour PNG with a large transparent field, so it compresses far smaller than
    // a gradient mark of the same pixel count. Measured: every default is under 40 bytes per 1000 pixels; the
    // product's mark is well over it at every size.
    final pixels = _pixelCount(bytes);
    return pixels > 0 && bytes.length / pixels * 1000 < 40;
  }

  test('neither platform ships the framework logo as its app icon', () {
    final offenders = <String>[];
    for (final path in shipped) {
      final file = File(path);
      expect(file.existsSync(), isTrue, reason: '$path is missing');
      if (looksLikeTheFrameworkLogo(file)) offenders.add(path);
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'these are still the icon `flutter create` wrote:\n${offenders.join('\n')}\n'
          'The mark is `lib/shared/design_system/brand/brand_mark.dart`; '
          '`tool/generate_app_icons.dart` draws it into both sets.',
    );
  });

  test('every size the iOS set declares is on disk', () {
    final contents = jsonDecode(File('ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json').readAsStringSync());
    final names = {
      for (final image in contents['images'] as List)
        if (image['filename'] != null) image['filename'] as String,
    };

    final missing = [
      for (final name in names)
        if (!File('ios/Runner/Assets.xcassets/AppIcon.appiconset/$name').existsSync()) name,
    ];
    expect(missing, isEmpty, reason: 'declared but not shipped:\n${missing.join('\n')}');
  });

  test('Android has an adaptive icon, so a launcher that masks does not crop the mark', () {
    // Without one, Android draws the legacy bitmap inside a white circle and the mark is letterboxed.
    expect(
      File('android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml').existsSync(),
      isTrue,
      reason: 'no adaptive icon; every masking launcher crops the mark into a circle',
    );
  });
}

/// The pixel count of a PNG, from its IHDR.
int _pixelCount(List<int> bytes) {
  if (bytes.length < 24) return 0;
  int at(int offset) =>
      (bytes[offset] << 24) | (bytes[offset + 1] << 16) | (bytes[offset + 2] << 8) | bytes[offset + 3];
  return at(16) * at(20);
}
