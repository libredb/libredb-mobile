import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

/// The screenshot sink for the on-device twin tests. `flutter drive --driver test_driver/integration_test.dart`
/// routes every `binding.takeScreenshot(name)` call here and writes `build/screenshots/<name>.png`; plain
/// `flutter test integration_test/<file> -d <device>` runs the same tests without a driver and takes no screenshots.
///
/// Never gated in CI — the on-device layer is run by hand, see docs/testing-architecture.md.
Future<void> main() => integrationDriver(
  onScreenshot: (String name, List<int> bytes, [Map<String, Object?>? args]) async {
    final file = await File('build/screenshots/$name.png').create(recursive: true);
    await file.writeAsBytes(bytes);
    return true;
  },
);
