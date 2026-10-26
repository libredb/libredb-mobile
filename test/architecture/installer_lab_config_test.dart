import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

/// Guards `tool/installer-lab/libredb.yaml.example`, the Platform installer configuration of the full-system check
/// environment that `docs/studio.md` "Platform installer environment" sets up.
///
/// - The test phone runs a release build, which trusts only the system store, so the edge serves the owner's public
///   chain per endpoint: `tls.mode: provided` with a chain and a key for `platform`, `studio` and `auth`, and the
///   `tls.caBundleFile` that the installer requires in that mode.
/// - `mobile.enabled: true` makes the installer create the `libredb-mobile` client with the app's redirect URIs.
/// - The committed file names no real host, so every host ends in `.invalid`, and it holds no license token and no
///   private key.
void main() {
  const path = 'tool/installer-lab/libredb.yaml.example';

  group('installer lab configuration', () {
    late String text;
    late YamlMap config;

    setUp(() {
      text = File(path).readAsStringSync();
      config = loadYaml(text) as YamlMap;
    });

    test('is a Docker installation of the installer v1 schema', () {
      expect(config['apiVersion'], 'install.libredb.org/v1');
      expect(config['kind'], 'LibreDBInstallation');
      expect(config['mode'], 'docker');
      expect(_at(config, ['docker', 'systemdUnit']), isTrue);
      expect(_at(config, ['platform', 'licenseFile']), '/etc/libredb/platform.license');
    });

    test('serves the provided chain and key for every endpoint, with a CA bundle', () {
      expect(_at(config, ['tls', 'mode']), 'provided');
      expect(
        _at(config, ['tls', 'caBundleFile']),
        isA<String>().having((v) => v, 'path', startsWith('/etc/libredb/tls/')),
      );
      for (final endpoint in ['platform', 'studio', 'auth']) {
        for (final field in ['certificateFile', 'keyFile']) {
          expect(
            _at(config, ['tls', 'provided', endpoint, field]),
            isA<String>().having((v) => v, 'path', startsWith('/etc/libredb/tls/')),
            reason: 'tls.provided.$endpoint.$field must name a file under /etc/libredb/tls/',
          );
        }
      }
    });

    test('creates the mobile client with the app redirect URIs', () {
      expect(_at(config, ['mobile', 'enabled']), isTrue);
      expect(_at(config, ['mobile', 'redirectUri']), 'org.libredb.mobile:/oauth2redirect');
      expect(_at(config, ['mobile', 'postLogoutRedirectUri']), 'org.libredb.mobile:/oauth2redirect');
    });

    test('names only .invalid placeholder hosts', () {
      final hosts = _at(config, ['endpoints', 'hosts']) as YamlMap;
      expect(hosts.keys.toSet(), {'platform', 'studio', 'auth'});
      for (final entry in hosts.entries) {
        expect(entry.value as String, endsWith('.invalid'), reason: 'endpoints.hosts.${entry.key} is a real host');
      }
    });

    test('holds no license token and no private key', () {
      expect(text, isNot(contains('ldl1.')));
      expect(text, isNot(contains('PRIVATE KEY')));
    });
  });
}

Object? _at(YamlMap map, List<String> keys) {
  Object? node = map;
  for (final key in keys) {
    if (node is! YamlMap) return null;
    node = node[key];
  }
  return node;
}
