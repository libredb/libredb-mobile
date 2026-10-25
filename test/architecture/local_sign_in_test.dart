import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The debug-only stand-in for the identity provider, which the mock entry point signs in through.
const _localSignIn = [
  'lib/app/di/mock_sign_in_dependencies.dart',
  'lib/infrastructure/auth/oidc/mock_oidc_client.dart',
];

/// Guards that the local sign-in of `main_local.dart` is never compiled into `main_prod.dart`: the compiler leaves out
/// a library that the entry point does not import, directly or through another library.
void main() {
  test('main_prod.dart does not import the local sign-in, directly or not', () {
    final reached = _importClosure('lib/main/main_prod.dart');

    expect(reached, contains('lib/app/bootstrap/app_bootstrap.dart'), reason: 'the guard reads the imports');
    expect(reached.intersection(_localSignIn.toSet()), isEmpty);
  });

  test('main_local.dart signs in through the local sign-in', () {
    expect(_importClosure('lib/main/main_local.dart'), containsAll(_localSignIn));
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
