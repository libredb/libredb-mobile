import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

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
  // Decoding a PNG to pixels needs a binding, even in a plain `test`.
  TestWidgetsFlutterBinding.ensureInitialized();

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

  test('both platforms draw the mark at the same scale', () async {
    // `generate_app_icons.dart` draws the same `BrandMark` at the same `markShare` into the iOS 1024 icon and the
    // Android launcher bitmap, so the mark has to occupy the same share of each tile. When one set is regenerated
    // and the other is left behind, the marks drift apart in size while staying the same shape — exactly the
    // "different icon on each store" the iOS set shipped with before #390's generator was re-run. Comparing the
    // top margin as a fraction of the tile is resolution-independent, so the 1024 icon and the 192 bitmap compare
    // directly.
    final ios = await _topMarginFraction('ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png');
    final android = await _topMarginFraction('android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png');

    expect(
      ios,
      closeTo(android, 0.015),
      reason:
          'the mark fills a different share of each platform (iOS top margin $ios, Android $android); '
          'one icon set is stale — re-run `fvm flutter test tool/generate_app_icons.dart` and commit what it writes',
    );
  });

  test('the store icons stand on the design system\'s light ground, not the old dark one', () async {
    // The brand icon is the design system's mark on a white field — the icon uploaded to the Play listing. For a
    // while the generated sets stood the same mark on the dark page instead, so the Play store showed a white icon
    // and the App Store a dark one: the same mark, two different icons across the two stores. The ground is the
    // one thing that told them apart at a glance, so the guard pins it to the light field both stores must share.
    for (final path in const [
      'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png',
      'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png',
    ]) {
      final (r, g, b) = await _cornerRgb(path);
      expect(
        (255 - r) + (255 - g) + (255 - b) < 24,
        isTrue,
        reason: 'the ground of $path is ($r,$g,$b), not the design system\'s white; '
            're-run `fvm flutter test tool/generate_app_icons.dart` after the mark\'s ground is set to white',
      );
    }
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

/// The fraction of the tile, from the top, that is the plain ground before the mark begins — a stand-in for the
/// mark's size that does not depend on the tile's resolution. The ground is the design system's dark page; a pixel
/// counts as the mark once it is opaque and far enough from that ground to not be an anti-aliased edge of it.
Future<double> _topMarginFraction(String path) async {
  const ground = (0x0B, 0x0D, 0x18);
  final codec = await ui.instantiateImageCodec(await File(path).readAsBytes());
  final image = (await codec.getNextFrame()).image;
  final data = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
  final (width, height) = (image.width, image.height);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final i = (y * width + x) * 4;
      final r = data.getUint8(i), g = data.getUint8(i + 1), b = data.getUint8(i + 2), a = data.getUint8(i + 3);
      final far = (r - ground.$1).abs() + (g - ground.$2).abs() + (b - ground.$3).abs() > 24;
      if (a > 8 && far) return y / height;
    }
  }
  return 1;
}

/// The top-left pixel's colour — the icon's ground, since the mark is centred and never reaches the corner.
Future<(int, int, int)> _cornerRgb(String path) async {
  final codec = await ui.instantiateImageCodec(await File(path).readAsBytes());
  final image = (await codec.getNextFrame()).image;
  final data = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
  return (data.getUint8(0), data.getUint8(1), data.getUint8(2));
}

/// The pixel count of a PNG, from its IHDR.
int _pixelCount(List<int> bytes) {
  if (bytes.length < 24) return 0;
  int at(int offset) =>
      (bytes[offset] << 24) | (bytes[offset + 1] << 16) | (bytes[offset + 2] << 8) | bytes[offset + 3];
  return at(16) * at(20);
}
