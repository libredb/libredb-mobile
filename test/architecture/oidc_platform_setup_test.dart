import 'dart:io';

import 'package:flutter_bloc_advance/infrastructure/config/auth_config.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guards the platform setup the `oidc` package needs.
///
/// - The `oidc_android` plugin merges an `OidcRedirectActivity` whose intent filter uses the `oidcRedirectScheme`
///   manifest placeholder. The placeholder has no default, so the manifest merge fails without it, and it must match
///   the scheme the Dart side sends as its redirect URI.
/// - The app is a public PKCE client, so nothing in `lib/` names a client secret and every client authentication is
///   `OidcClientAuthentication.none`.
/// - No app manifest declares an intent filter for the redirect scheme: a second one would let Android offer
///   `MainActivity` for the callback, and the package's redirect activity would no longer receive it.
void main() {
  group('OIDC platform setup', () {
    test('the Android manifest placeholder carries the default redirect scheme', () {
      const gradlePath = 'android/app/build.gradle.kts';
      final defaultConfig = _block(_stripLineComments(File(gradlePath).readAsStringSync()), 'defaultConfig');
      expect(defaultConfig, isNotNull, reason: '$gradlePath has no defaultConfig block');

      expect(
        defaultConfig,
        contains('manifestPlaceholders["oidcRedirectScheme"] = "${OidcSettings.defaultRedirectScheme}"'),
        reason:
            'defaultConfig in $gradlePath must set the oidcRedirectScheme manifest placeholder to '
            '${OidcSettings.defaultRedirectScheme}, or the oidc_android manifest merge fails and the redirect '
            'never reaches the app',
      );
    });

    test('the client secret pattern flags the spellings of the oidc package', () {
      for (final spelling in [
        'clientSecretPost(',
        'clientSecretBasic(',
        'clientSecret:',
        'client_secret',
        'OIDC_CLIENT_SECRET',
      ]) {
        expect(_clientSecret.hasMatch(spelling), isTrue, reason: 'the pattern misses $spelling');
      }
    });

    test('no client secret is named anywhere in lib', () {
      final offenders = <String>[];
      for (final file in _dartFiles('lib')) {
        final lines = file.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          if (!_clientSecret.hasMatch(lines[i])) continue;
          // The scrubber's doc comment names `clientSecret` as a key it masks; it reads no secret.
          if (file.path == _scrubberPath && lines[i].trimLeft().startsWith('///')) continue;
          offenders.add('${file.path}:${i + 1}: ${lines[i].trim()}');
        }
      }

      expect(
        offenders,
        isEmpty,
        reason: 'The app is a public PKCE client and must not name a client secret:\n${offenders.join('\n')}',
      );
    });

    test('every client authentication in lib is OidcClientAuthentication.none', () {
      final constructions = <String>[];
      final offenders = <String>[];
      for (final file in _dartFiles('lib')) {
        for (final match in RegExp(r'OidcClientAuthentication\s*\.\s*(\w+)').allMatches(file.readAsStringSync())) {
          constructions.add(file.path);
          if (match[1] != 'none') offenders.add('${file.path}: OidcClientAuthentication.${match[1]}');
        }
      }

      expect(constructions, isNotEmpty, reason: 'lib/ builds no OidcClientAuthentication; the guard looks in vain');
      expect(
        offenders,
        isEmpty,
        reason: 'The app is a public PKCE client, so its client authentication is .none:\n${offenders.join('\n')}',
      );
    });

    test('no app manifest declares an intent filter for the redirect scheme', () {
      final manifests = Directory('android/app/src')
          .listSync()
          .whereType<Directory>()
          .map((dir) => File('${dir.path}/AndroidManifest.xml'))
          .where((file) => file.existsSync())
          .toList();
      expect(
        manifests.map((file) => file.path),
        contains('android/app/src/main/AndroidManifest.xml'),
        reason: 'the guard found no main manifest under android/app/src',
      );

      final offenders = <String>[
        for (final manifest in manifests)
          for (final needle in [OidcSettings.defaultRedirectScheme, 'oidcRedirectScheme'])
            if (manifest.readAsStringSync().contains(needle)) '${manifest.path} mentions $needle',
      ];

      expect(
        offenders,
        isEmpty,
        reason:
            'No app manifest may mention ${OidcSettings.defaultRedirectScheme} or the oidcRedirectScheme placeholder: '
            'the OidcRedirectActivity of oidc_android owns that scheme:\n${offenders.join('\n')}',
      );
    });
  });
}

/// Matches every spelling of a client secret: `client_secret`, `OIDC_CLIENT_SECRET`, and the package's camelCase
/// `clientSecret`, `clientSecretBasic` and `clientSecretPost`.
final _clientSecret = RegExp('client_?secret', caseSensitive: false);

/// The one file in `lib/` whose doc comment may name a client secret.
const _scrubberPath = 'lib/core/security/sensitive_data_scrubber.dart';

/// Every Dart file under [root].
Iterable<File> _dartFiles(String root) =>
    Directory(root).listSync(recursive: true).whereType<File>().where((file) => file.path.endsWith('.dart'));

/// Removes `//` comments that start a line or follow whitespace, so a `://` inside a string survives.
String _stripLineComments(String source) =>
    source.replaceAllMapped(RegExp(r'(^|\s)//[^\n]*', multiLine: true), (match) => match[1]!);

/// The body of the first `name { ... }` block in [source], matched by brace depth, or null when there is none.
String? _block(String source, String name) {
  final open = RegExp('\\b${RegExp.escape(name)}\\s*\\{').firstMatch(source);
  if (open == null) return null;

  var depth = 1;
  for (var i = open.end; i < source.length; i++) {
    if (source[i] == '{') depth++;
    if (source[i] == '}' && --depth == 0) return source.substring(open.end, i);
  }
  fail('the $name block has no closing brace');
}
