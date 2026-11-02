import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The debug-only session seed for the on-device local twin.
const _debugSessionSeed = 'lib/app/bootstrap/debug_session_seed.dart';

/// Guards that the debug session seed reaches only `main_local.dart`. It writes a signed-in session straight into
/// secure storage, so it must never be reachable from a build that ships: `main_prod.dart` signs in through a real
/// Keycloak, and `main_mock.dart` uses the mock sign-in. The compiler leaves out a library an entry point does not
/// import, directly or through another library, so an absent import is proof the code is not compiled in.
void main() {
  test('only main_local reaches the debug session seed', () {
    expect(
      _importClosure('lib/main/main_local.dart'),
      contains(_debugSessionSeed),
      reason: 'main_local seeds the local twin session',
    );

    for (final entryPoint in const ['lib/main/main_prod.dart', 'lib/main/main_mock.dart']) {
      expect(
        _importClosure(entryPoint),
        isNot(contains(_debugSessionSeed)),
        reason: '$entryPoint must not compile in the debug session seed',
      );
    }
  });
}

final _import = RegExp(r'''^\s*(?:import|export)\s+['"]([^'"]+)['"]''', multiLine: true);

/// The files under `lib/` that [entry] imports or exports, directly or not, [entry] included.
Set<String> _importClosure(String entry) {
  final reached = <String>{};
  final pending = [entry];
  while (pending.isNotEmpty) {
    final path = pending.removeLast();
    if (!reached.add(path)) continue;
    final source = File(path).readAsStringSync();
    for (final match in _import.allMatches(source)) {
      final target = _resolve(path, match[1]!);
      if (target != null && File(target).existsSync()) pending.add(target);
    }
  }
  return reached;
}

/// The path under `lib/` that [uri], imported by [from], names, or null for a library outside the package.
String? _resolve(String from, String uri) {
  const package = 'package:libredb_mobile/';
  if (uri.startsWith(package)) return 'lib/${uri.substring(package.length)}';
  if (uri.contains(':')) return null;
  return File(from).parent.uri.resolve(uri).toFilePath();
}
