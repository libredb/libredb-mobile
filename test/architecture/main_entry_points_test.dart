import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards what each entry point under `lib/main/` is pointed at, read from its source.
///
/// The defaults are what make `main_local.dart` and `main_prod.dart` start without flags, so a change to one of these
/// URLs changes where a hand-built APK connects. They are checked here rather than at runtime because a
/// `String.fromEnvironment` default is fixed at compile time and a test binary carries its own defines.
void main() {
  String sourceOf(String entryPoint) => File('lib/main/$entryPoint').readAsStringSync();

  test('main_prod.dart defaults to the Railway deployment', () {
    final source = sourceOf('main_prod.dart');
    expect(source, contains('https://studio-dev.libredb.org/api'));
    expect(source, contains('https://auth-dev.libredb.org/realms/libredb'));
    expect(source, contains('libredb-mobile'));
  });

  test('main_prod.dart gives PLATFORM_API_URL no default, so the store build stays Studio-only', () {
    // docs/platform.md and docs/release.md — the store build stays Studio-only, without PLATFORM_API_URL, until the
    // owner approves it; the team ledger carries the same ruling. A committed default would cross that line without
    // the owner, because release.yml passes the define only from the owner's variable and nothing else would override
    // it. The doc comment may still name it: it says how to opt in by hand.
    final code = sourceOf('main_prod.dart').split('\n').where((line) => !line.trimLeft().startsWith('///')).join('\n');
    expect(code, isNot(contains('PLATFORM_API_URL')));
    expect(code, isNot(contains('platformApiUrl')));
  });

  test('main_local.dart defaults to the Lima VM, Platform included', () {
    final source = sourceOf('main_local.dart');
    expect(source, contains('https://studio.lab.test/api'));
    expect(source, contains('https://sso.lab.test/realms/libredb'));
    expect(source, contains('https://libredb.lab.test/api'));
  });

  test('main_mock.dart names no backend at all', () {
    final source = sourceOf('main_mock.dart');
    expect(source, isNot(contains('https://')));
    expect(source, isNot(contains('PROD_API_URL')));
  });

  test('every default is overridable, so an outside deployment can point the app elsewhere', () {
    const defines = {
      'main_local.dart': ['PROD_API_URL', 'OIDC_ISSUER', 'OIDC_CLIENT_ID', 'PLATFORM_API_URL'],
      'main_prod.dart': ['PROD_API_URL', 'OIDC_ISSUER', 'OIDC_CLIENT_ID'],
    };
    for (final entryPoint in defines.keys) {
      final source = sourceOf(entryPoint);
      for (final define in defines[entryPoint]!) {
        expect(
          source,
          contains("String.fromEnvironment('$define'"),
          reason: '$entryPoint must read $define, so --dart-define wins over its default',
        );
      }
    }
  });
}
