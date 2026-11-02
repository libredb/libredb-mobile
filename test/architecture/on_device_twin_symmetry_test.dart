import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the on-device twin files under `integration_test/`. Each flow is a pair: a mock twin
/// `app_<flow>_test.dart` (fast, no backend) and, for the flows that need the real backend, a local twin
/// `app_local_<flow>_test.dart`. A local twin without its mock twin would verify a flow only against studio-dev and
/// never the fast way, so this fails if one is added alone. See docs/testing-architecture.md, "On-device twin tests".
void main() {
  final twinFiles = _integrationTestFiles();

  test('the connection-list twins exist', () {
    expect(twinFiles, contains('app_connections_test.dart'));
    expect(twinFiles, contains('app_local_connections_test.dart'));
  });

  test('every local twin has a matching mock twin', () {
    const localPrefix = 'app_local_';
    final orphans = [
      for (final file in twinFiles)
        if (file.startsWith(localPrefix) && !twinFiles.contains('app_${file.substring(localPrefix.length)}')) file,
    ];

    expect(
      orphans,
      isEmpty,
      reason:
          'these local twins have no mock twin (app_<flow>_test.dart), so their flow is never verified the fast '
          'way: $orphans',
    );
  });
}

/// The `*_test.dart` file names directly under `integration_test/`.
Set<String> _integrationTestFiles() {
  final dir = Directory('integration_test');
  if (!dir.existsSync()) return const {};
  return dir
      .listSync()
      .whereType<File>()
      .map((file) => file.uri.pathSegments.last)
      .where((name) => name.endsWith('_test.dart'))
      .toSet();
}
