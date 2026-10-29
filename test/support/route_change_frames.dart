import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// The pixels inside [boundary] right now.
///
/// The same machinery `pressed_frame.dart` uses, for the other thing the suite cannot otherwise see: what a route
/// change draws while it runs. Both calls are real asynchronous work and a widget test runs on a fake clock that
/// never drives it, so both are awaited through [WidgetTester.runAsync]; `toImage` rather than `toImageSync`, because
/// the synchronous form can hand back a retained raster of the previous frame.
Future<Uint8List> surfaceFrame(WidgetTester tester, Key boundary) async {
  final box = tester.renderObject<RenderRepaintBoundary>(find.byKey(boundary));
  final data = await tester.runAsync(() async {
    final image = await box.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    return bytes;
  });
  return data!.buffer.asUint8List();
}

/// How many of the pixels in [a] and [b] differ.
int changedPixels(Uint8List a, Uint8List b) {
  var changed = 0;
  for (var at = 0; at + 4 <= a.length && at + 4 <= b.length; at += 4) {
    for (var channel = 0; channel < 4; channel++) {
      if (a[at + channel] != b[at + channel]) {
        changed++;
        break;
      }
    }
  }
  return changed;
}
