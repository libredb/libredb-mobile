import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

/// Guards the obfuscated release build and its symbol upload to Sentry (docs/release.md, issue #208).
///
/// - No `sentry.properties` and no Sentry auth token is ever tracked: the plugin reads its settings from the release
///   workflow's environment, and the token is a secret of the `release-signing` environment.
/// - The release workflow builds with `--obfuscate --split-debug-info`, uploads the Dart symbols, the obfuscation map
///   and the R8 mapping to Sentry before the bundle is kept, and keeps the first two out of the `release-bundle`
///   artifact.
/// - A tag build without the token fails before the build; a dry run never reaches Sentry and says so.
/// - The R8 mapping's id reaches the native SDK, so Sentry can match the uploaded mapping to an event.
void main() {
  group('tracked Sentry settings', () {
    test('sentry.properties is git-ignored and none is tracked', () async {
      for (final path in ['sentry.properties', 'android/sentry.properties', 'ios/sentry.properties']) {
        final result = await Process.run('git', ['check-ignore', '--no-index', '--quiet', path]);
        expect(result.exitCode, 0, reason: '$path is not git-ignored');
      }

      final tracked = await Process.run('git', ['ls-files', '--', '*sentry.properties']);
      expect(tracked.exitCode, 0, reason: 'git ls-files failed: ${tracked.stderr}');
      expect((tracked.stdout as String).trim(), isEmpty, reason: 'sentry.properties is tracked:\n${tracked.stdout}');
    });

    test('the token pattern finds a user token, an organization token and a written-out auth token', () {
      // Built at run time, so this file holds no value the guard below would find.
      final samples = [
        '${_userTokenPrefix}_${'0a' * 32}',
        '${_orgTokenPrefix}_eyJpYXQiOjE3MDAwMDAwMDAsInVybCI6Imh0dHBzOi8vc2VudHJ5LmlvIn0',
        'auth_token=${'f' * 64}',
        'auth.token: ${'A1' * 16}',
        'SENTRY_AUTH_TOKEN="${'b9' * 20}"',
      ];
      for (final sample in samples) {
        expect(_tokenRegExp.hasMatch(sample), isTrue, reason: 'the pattern misses $sample');
      }
      for (final harmless in [
        r'SENTRY_AUTH_TOKEN: ${{ secrets.SENTRY_AUTH_TOKEN }}',
        r'if [ -z "$SENTRY_AUTH_TOKEN" ]; then',
        'auth_token is read from the environment',
      ]) {
        expect(_tokenRegExp.hasMatch(harmless), isFalse, reason: 'the pattern flags $harmless');
      }
    });

    test('no tracked file holds a Sentry auth token', () async {
      final result = await Process.run('git', ['grep', '-I', '-n', '-E', '-i', _tokenPattern]);
      // git grep exits 1 when nothing matches, and 2 or more on an error.
      expect(result.exitCode, isNot(greaterThan(1)), reason: 'git grep failed: ${result.stderr}');
      expect(
        (result.stdout as String).trim(),
        isEmpty,
        reason: 'a tracked file holds what looks like a Sentry auth token; revoke it and remove it',
      );
    });

    test('pubspec.yaml holds no sentry section, so nothing there can carry a token', () {
      final pubspec = _loadYaml('pubspec.yaml');
      expect(pubspec.containsKey('sentry'), isFalse, reason: 'configure sentry_dart_plugin in $_releasePath');
      final devDependencies = pubspec['dev_dependencies'] as YamlMap;
      expect(
        '${devDependencies['sentry_dart_plugin']}',
        matches(RegExp(r'^\d+\.\d+\.\d+$')),
        reason: 'sentry_dart_plugin must be an exact dev dependency',
      );
    });
  });

  group('release workflow', () {
    late final steps = _steps(_loadYaml(_releasePath)['jobs'] as YamlMap, 'build');
    int indexOf(bool Function(YamlMap step) where, String what) {
      final index = steps.indexWhere(where);
      expect(index, isNonNegative, reason: 'the build job has no step that $what');
      return index;
    }

    late final check = indexOf((step) => '${step['run']}'.contains(_checkScriptPath), 'runs $_checkScriptPath');
    late final build = indexOf((step) => '${step['run']}'.contains('flutter build appbundle'), 'builds the bundle');
    late final upload = indexOf((step) => '${step['run']}'.contains('sentry_dart_plugin'), 'uploads the symbols');
    late final keep = indexOf((step) => '${step['uses']}'.startsWith('actions/upload-artifact@'), 'keeps the bundle');

    test('builds obfuscated, with the Dart symbols and the obfuscation map outside the bundle', () {
      final run = '${steps[build]['run']}';
      expect(run, contains('--obfuscate'));
      expect(run, contains('--split-debug-info=$_debugInfo'));
      expect(run, contains('--extra-gen-snapshot-options=--save-obfuscation-map=$_obfuscationMap'));
      expect(run, contains(r'-PsentryProguardUuid="$SENTRY_PROGUARD_UUID"'));
    });

    test('checks for the token before the build, from the secret of the signing environment', () {
      expect(check, lessThan(build), reason: '$_checkScriptPath must run before the build');
      final env = steps[check]['env'] as YamlMap;
      expect(env['SENTRY_AUTH_TOKEN'], r'${{ secrets.SENTRY_AUTH_TOKEN }}');
      expect('${env['RELEASE_KIND']}', contains("github.event_name == 'workflow_dispatch' && 'dry-run'"));
      expect(steps[check]['id'], 'sentry');
    });

    test('names the R8 mapping before the build', () {
      final name = indexOf((step) => '${step['run']}'.contains('SENTRY_PROGUARD_UUID='), 'names the R8 mapping');
      expect(name, lessThan(build));
      expect('${steps[name]['run']}', contains('GITHUB_ENV'));
    });

    test('uploads the symbols and the R8 mapping after the build and before the bundle is kept, only when asked', () {
      expect(upload, greaterThan(build));
      expect(upload, lessThan(keep), reason: 'a failed upload must stop the release before the bundle is kept');

      final step = steps[upload];
      expect('${step['if']}', "steps.sentry.outputs.upload == 'true'");
      final env = step['env'] as YamlMap;
      expect(env['SENTRY_AUTH_TOKEN'], r'${{ secrets.SENTRY_AUTH_TOKEN }}');
      expect(env['SENTRY_ORG'], 'libredb-org');
      expect(env['SENTRY_PROJECT'], 'libredb-mobile');

      final run = '${step['run']}';
      expect(run, contains('dart run sentry_dart_plugin'));
      expect(run, contains('--sentry-define=symbols_path=$_debugInfo'));
      expect(run, contains('--sentry-define=dart_symbol_map_path=$_obfuscationMap'));
      expect(run, contains('upload-proguard'));
      expect(run, contains(r'--uuid "$SENTRY_PROGUARD_UUID"'));
      expect(run, contains('build/app/outputs/mapping/release/mapping.txt'));
      expect(run, isNot(contains('--auth-token')), reason: 'the token must stay in the environment');
      // The release the app reports: the version name and build number of pubspec.yaml (AppBootstrap, NativeSentry).
      expect(run, contains('SENTRY_RELEASE'));
    });

    test('keeps the Dart symbols and the obfuscation map out of the release-bundle artifact', () {
      final inputs = steps[keep]['with'] as YamlMap;
      expect(inputs['name'], 'release-bundle');
      final paths = '${inputs['path']}'.trim().split('\n').map((line) => line.trim()).toList();
      expect(paths, [
        'build/app/outputs/bundle/release/app-release.aab',
        'build/app/outputs/mapping/release/mapping.txt',
      ]);
    });
  });

  group('check_sentry_upload.sh', () {
    late Directory dir;
    late File output;
    setUp(() {
      dir = Directory.systemTemp.createTempSync('check_sentry_upload');
      output = File('${dir.path}/github_output')..writeAsStringSync('');
    });
    tearDown(() => dir.deleteSync(recursive: true));

    Future<ProcessResult> check(String? kind, {String token = '', bool withOutput = true}) => Process.run(
      'bash',
      [_checkScriptPath],
      environment: {
        'PATH': ?Platform.environment['PATH'],
        'RELEASE_KIND': ?kind,
        'SENTRY_AUTH_TOKEN': token,
        if (withOutput) 'GITHUB_OUTPUT': output.path,
      },
      includeParentEnvironment: false,
    );

    test('a release with the token uploads', () async {
      final result = await check('release', token: 'not-a-real-token');
      expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
      expect(output.readAsStringSync(), 'upload=true\n');
      expect('${result.stdout}${result.stderr}', isNot(contains('not-a-real-token')));
    });

    test('a release without the token fails and names the secret', () async {
      final result = await check('release');
      expect(result.exitCode, 1);
      expect(result.stdout, contains('SENTRY_AUTH_TOKEN'));
      expect(result.stdout, contains('release-signing'));
      expect(output.readAsStringSync(), isEmpty);
    });

    test('a dry run never uploads, with or without the token, and says so', () async {
      for (final token in ['', 'not-a-real-token']) {
        output.writeAsStringSync('');
        final result = await check('dry-run', token: token);
        expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
        expect(output.readAsStringSync(), 'upload=false\n');
        expect(result.stdout, contains('not uploaded to Sentry'));
      }
    });

    test('fails on an unknown or missing kind, and without GITHUB_OUTPUT', () async {
      for (final kind in ['tag', '', null]) {
        final result = await check(kind, token: 'not-a-real-token');
        expect(result.exitCode, 2, reason: 'RELEASE_KIND=$kind was not an error');
      }
      final result = await check('release', token: 'not-a-real-token', withOutput: false);
      expect(result.exitCode, 2);
    });
  });

  group('the R8 mapping id', () {
    late final gradle = File(_gradlePath).readAsStringSync();
    late final nativeSentry = File(_nativeSentryPath).readAsStringSync();

    test('Gradle passes a checked -PsentryProguardUuid to the native SDK of a prod build only', () {
      expect(gradle, contains('findProperty("sentryProguardUuid")'));
      expect(gradle, contains('"SENTRY_PROGUARD_UUID"'));
      expect(gradle, contains('GradleException("-PsentryProguardUuid'), reason: 'a malformed id must fail the build');
      expect(gradle, contains('val nativeProguardUuid = if (isProdTarget) sentryProguardUuid else ""'));
      expect(gradle, contains('"SENTRY_PROGUARD_UUID", buildConfigString(nativeProguardUuid)'));
    });

    test('NativeSentry starts the SDK with it', () {
      expect(nativeSentry, contains('proguardUuid = BuildConfig.SENTRY_PROGUARD_UUID'));
    });
  });

  group('docs/release.md', () {
    late final docs = File(_releaseDocsPath).readAsStringSync();

    test('names the secret, its environment, the Sentry project and the owner steps', () {
      expect(docs, contains('`SENTRY_AUTH_TOKEN`'));
      expect(docs, contains('libredb-org'));
      expect(docs, contains('libredb-mobile'));
      expect(docs, contains('Organization Tokens'));
      expect(docs, contains('sentry.properties'));
      expect(docs, contains('--obfuscate'));
    });
  });
}

const _releasePath = '.github/workflows/release.yml';
const _releaseDocsPath = 'docs/release.md';
const _checkScriptPath = 'tool/release/check_sentry_upload.sh';
const _gradlePath = 'android/app/build.gradle.kts';
const _nativeSentryPath = 'android/app/src/main/kotlin/org/libredb/mobile/NativeSentry.kt';
const _debugInfo = 'build/debug-info';
const _obfuscationMap = 'build/debug-info/obfuscation.map.json';

// Split, so this file does not hold the token prefixes the guard looks for next to a value.
const _userTokenPrefix =
    'sntry'
    'u';
const _orgTokenPrefix =
    'sntry'
    's';

/// A Sentry user or organization auth token, or an auth token setting written out with a value of 16 or more
/// characters (as `sentry.properties`, a pubspec `sentry` section or a shell line would hold it). A value that is a
/// variable or a GitHub expression is not one.
const _tokenPattern =
    'sntry[us]_[A-Za-z0-9+/=_-]{16,}'
    '|(auth[._]token|SENTRY_AUTH_TOKEN) *[:=] *["\']?[A-Za-z0-9+/=_-]{16,}';

final _tokenRegExp = RegExp(_tokenPattern, caseSensitive: false);

YamlMap _loadYaml(String path) => loadYaml(File(path).readAsStringSync()) as YamlMap;

List<YamlMap> _steps(YamlMap jobs, String name) {
  final job = jobs[name] as YamlMap?;
  expect(job, isNotNull, reason: 'the workflow has no job $name');
  return [...?(job!['steps'] as YamlList?)?.cast<YamlMap>()];
}
