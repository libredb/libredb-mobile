import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The debug-only stand-in for the identity provider, which `main_mock.dart` signs in through.
const _mockSignIn = ['lib/app/di/mock_sign_in_dependencies.dart', 'lib/infrastructure/auth/oidc/mock_oidc_client.dart'];

/// The entry points that sign in through a real Keycloak, so neither may reach the mock sign-in.
const _realBackendEntryPoints = ['lib/main/main_prod.dart', 'lib/main/main_local.dart'];

/// Guards that the mock sign-in reaches only `main_mock.dart`: the compiler leaves out a library that the entry point
/// does not import, directly or through another library.
void main() {
  test('no entry point with a real backend imports the mock sign-in, directly or not', () {
    for (final entryPoint in _realBackendEntryPoints) {
      final reached = _importClosure(entryPoint);

      expect(reached, contains('lib/app/bootstrap/app_bootstrap.dart'), reason: 'the guard reads the imports');
      expect(reached.intersection(_mockSignIn.toSet()), isEmpty, reason: entryPoint);
    }
  });

  test('main_mock.dart signs in through the mock sign-in', () {
    expect(_importClosure('lib/main/main_mock.dart'), containsAll(_mockSignIn));
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
