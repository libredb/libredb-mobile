import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/shared/design_system/brand/brand_mark.dart';

/// Draws the product's mark into both platforms' app icon sets.
///
///     fvm flutter test tool/generate_app_icons.dart
///
/// Run it when the mark changes, and commit what it writes. It is shaped as a test because that is the only way to
/// drive Flutter's rasteriser from the command line without a second toolchain: `flutter test` gives a binding, a
/// `RepaintBoundary` gives a picture, and `toImage` gives the pixels. Nothing here runs in the app, and
/// `app_icon_test.dart` is what holds the result — this file produces, that one refuses.
///
/// It replaced a dependency on a rasteriser the project did not have. `flutter create`'s own blue chevron had been
/// shipping on both platforms since the project began, because nothing in the repository could draw anything else
/// (#390).
void main() {
  /// The ground the mark sits on: the design system's dark page. An icon has to be opaque on iOS — the review
  /// rejects alpha — and a mark floating on white would be the mark, not the product.
  const ground = Color(0xFF0B0D18);

  /// How much of the icon the mark takes. The rest is the margin every platform's mask eats into.
  const markShare = 0.62;

  /// The share for the adaptive foreground, which is drawn on a 108dp canvas of which only the middle 72dp is
  /// guaranteed to be visible: the mark has to live inside that circle whatever the launcher's mask is.
  const adaptiveShare = 0.42;

  Future<void> write(
    WidgetTester tester,
    String path,
    int pixels, {
    required bool transparent,
    required double share,
  }) async {
    final key = GlobalKey();
    await tester.pumpWidget(
      // The boundary wraps the box and not the other way round: as the root it would take the test view's size,
      // and every icon would come out at the size of the screen instead of its own.
      Center(
        child: RepaintBoundary(
          key: key,
          child: SizedBox(
            width: pixels.toDouble(),
            height: pixels.toDouble(),
            child: ColoredBox(
              color: transparent ? const Color(0x00000000) : ground,
              child: Center(
                child: BrandMark(size: pixels * share * BrandMark.viewBox.width / BrandMark.viewBox.height),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    // `toImage` and `toByteData` are real asynchronous work on the engine. A widget test runs inside `FakeAsync`,
    // where their futures never complete, so they have to be awaited outside it.
    await tester.runAsync(() async {
      final image = await boundary.toImage();
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File(path);
      file.parent.createSync(recursive: true);
      file.writeAsBytesSync(png!.buffer.asUint8List());
      image.dispose();
    });
  }

  testWidgets('writes every Android density', (tester) async {
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // The launcher bitmap, for the launchers that do not mask, and the adaptive foreground for the ones that do.
    const launcher = <String, int>{'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144, 'xxxhdpi': 192};
    const foreground = <String, int>{'mdpi': 108, 'hdpi': 162, 'xhdpi': 216, 'xxhdpi': 324, 'xxxhdpi': 432};

    for (final entry in launcher.entries) {
      await write(
        tester,
        'android/app/src/main/res/mipmap-${entry.key}/ic_launcher.png',
        entry.value,
        transparent: false,
        share: markShare,
      );
    }
    for (final entry in foreground.entries) {
      await write(
        tester,
        'android/app/src/main/res/mipmap-${entry.key}/ic_launcher_foreground.png',
        entry.value,
        transparent: true,
        share: adaptiveShare,
      );
    }
  });

  testWidgets('writes every iOS size its Contents.json declares', (tester) async {
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // Name to pixels, as the asset catalogue names them: size times scale.
    const sizes = <String, int>{
      'Icon-App-20x20@1x.png': 20,
      'Icon-App-20x20@2x.png': 40,
      'Icon-App-20x20@3x.png': 60,
      'Icon-App-29x29@1x.png': 29,
      'Icon-App-29x29@2x.png': 58,
      'Icon-App-29x29@3x.png': 87,
      'Icon-App-40x40@1x.png': 40,
      'Icon-App-40x40@2x.png': 80,
      'Icon-App-40x40@3x.png': 120,
      'Icon-App-60x60@2x.png': 120,
      'Icon-App-60x60@3x.png': 180,
      'Icon-App-76x76@1x.png': 76,
      'Icon-App-76x76@2x.png': 152,
      'Icon-App-83.5x83.5@2x.png': 167,
      'Icon-App-1024x1024@1x.png': 1024,
    };

    for (final entry in sizes.entries) {
      await write(
        tester,
        'ios/Runner/Assets.xcassets/AppIcon.appiconset/${entry.key}',
        entry.value,
        // Every iOS icon is opaque, the 1024 one because review refuses alpha and the rest for the same reason it
        // does: a transparent app icon is a hole on the home screen.
        transparent: false,
        share: markShare,
      );
    }
  });
}
