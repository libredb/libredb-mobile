import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

/// Guards the Android release signing and the release workflows (docs/release.md, issue #194).
///
/// - The release build reads its upload key only from the environment or the git-ignored `android/key.properties`,
///   never from a value written into `build.gradle.kts`, and `-PrequireReleaseSigning=true` makes a build without one
///   fail instead of falling back to the debug key.
/// - `key.properties` and every keystore stay git-ignored, and none is tracked.
/// - The release workflow builds with `-PrequireReleaseSigning=true`, deletes the decoded keystore also on failure,
///   uploads only from a job bound to the `play-internal` environment, and never on a dry run.
/// - Every action of the release workflows is pinned to a commit SHA.
/// - The release-please manifest and `pubspec.yaml` name the same version.
/// - A `release-as` in the release-please config is a plain version, and docs/release.md names the Actions setting
///   release-please needs and the removal of `release-as` after the first release (#211).
/// - A store build never carries a define meant for checks only (`tool/release/check_only_defines.txt`), such as
///   `SENTRY_DEVICE_CHECK`: `tool/release/check_defines.sh` stops the release before the build, and every define the
///   app reads is either one the release passes or one of those.
void main() {
  group('Android release signing', () {
    late final gradle = _stripLineComments(File(_gradlePath).readAsStringSync());

    test('reads each signing value only from the environment or key.properties', () {
      for (final name in _signingEnvironment) {
        expect(gradle, contains('"$name"'), reason: '$_gradlePath does not read $name from the environment');
      }
      for (final key in ['storeFile', 'storePassword', 'keyAlias', 'keyPassword']) {
        expect(gradle, contains('"$key"'), reason: '$_gradlePath does not read $key from key.properties');
      }
      expect(gradle, contains('key.properties'), reason: '$_gradlePath does not read android/key.properties');

      final literal = RegExp(r'\b(storePassword|keyPassword|keyAlias)\s*=\s*"');
      expect(
        literal.hasMatch(gradle),
        isFalse,
        reason: '$_gradlePath writes a signing value into the build file; read it from the environment instead',
      );
      expect(
        RegExp(r'storeFile\s*=\s*file\(\s*"').hasMatch(gradle),
        isFalse,
        reason: '$_gradlePath names a keystore path in the build file; read it from the environment instead',
      );
    });

    test('a required release signing never falls back to the debug key', () {
      expect(gradle, contains('requireReleaseSigning'), reason: '$_gradlePath has no requireReleaseSigning property');
      expect(gradle, contains('GradleException'), reason: '$_gradlePath does not fail a build that lacks the key');

      final release = _block(_block(gradle, 'buildTypes') ?? '', 'release');
      expect(release, isNotNull, reason: '$_gradlePath has no release build type');
      expect(
        release!.contains('signingConfig = signingConfigs.getByName("debug")'),
        isFalse,
        reason: 'the release build type in $_gradlePath signs with the debug key unconditionally',
      );
    });

    test('a required release signing refuses the check-only defines too', () {
      expect(gradle, contains('tool/release/check_only_defines.txt'), reason: '$_gradlePath never reads the list');
      final guard = RegExp(r'if \(requireReleaseSigning\)\s*\{[^}]*checkOnlyDefines', multiLine: true);
      expect(guard.hasMatch(gradle), isTrue, reason: 'a signed build in $_gradlePath must refuse check-only defines');
    });

    test('key.properties and keystores are git-ignored and none is tracked', () async {
      for (final path in [
        'android/key.properties',
        'android/upload-keystore.jks',
        'android/app/upload-keystore.jks',
        'android/app/upload.keystore',
      ]) {
        final result = await Process.run('git', ['check-ignore', '--no-index', '--quiet', path]);
        expect(result.exitCode, 0, reason: '$path is not git-ignored');
      }

      final tracked = await Process.run('git', ['ls-files', '--', '*key.properties', '*.jks', '*.keystore']);
      expect(tracked.exitCode, 0, reason: 'git ls-files failed: ${tracked.stderr}');
      expect((tracked.stdout as String).trim(), isEmpty, reason: 'a signing file is tracked:\n${tracked.stdout}');
    });
  });

  group('release workflow', () {
    late final workflow = _loadYaml(_releasePath);
    late final jobs = workflow['jobs'] as YamlMap;

    test('runs on version tags and on a manual dry run', () {
      final on = workflow['on'] as YamlMap;
      expect((on['push'] as YamlMap)['tags'], contains('v*.*.*'), reason: '$_releasePath does not run on v*.*.* tags');
      expect(on.containsKey('workflow_dispatch'), isTrue, reason: '$_releasePath has no workflow_dispatch dry run');
      expect(on.containsKey('workflow_call'), isTrue, reason: 'release-please cannot call $_releasePath');
    });

    test('builds the bundle with a required release signing and deletes the keystore also on failure', () {
      final steps = _steps(jobs, 'build');
      final build = steps.where((step) => '${step['run']}'.contains('flutter build appbundle')).toList();
      expect(build, hasLength(1), reason: 'the build job must build one App Bundle');
      expect(build.single['run'], contains('-PrequireReleaseSigning=true'));
      expect(build.single['run'], contains('--target lib/main/main_prod.dart'));

      final cleanup = steps.where((step) => '${step['run']}'.contains('rm -f')).toList();
      expect(cleanup, isNotEmpty, reason: 'the build job never deletes the decoded keystore');
      expect(cleanup.last['if'], 'always()', reason: 'the keystore cleanup must also run after a failed step');
      expect(identical(cleanup.last, steps.last), isTrue, reason: 'the keystore cleanup must be the last step');
    });

    test('uploads only from the play-internal environment and never on a dry run', () {
      final uploads = <String>[
        for (final entry in jobs.entries)
          if (_steps(jobs, entry.key as String).any((step) => '${step['uses']}'.contains('upload-google-play')))
            entry.key as String,
      ];
      expect(uploads, ['upload'], reason: 'only the upload job may upload to Play');

      final upload = jobs['upload'] as YamlMap;
      final environment = upload['environment'];
      expect(environment is YamlMap ? environment['name'] : environment, 'play-internal');
      expect('${upload['if']}', contains("github.event_name != 'workflow_dispatch'"));

      final step = _steps(jobs, 'upload').singleWhere((step) => '${step['uses']}'.contains('upload-google-play'));
      final inputs = step['with'] as YamlMap;
      expect(inputs['packageName'], 'org.libredb.mobile');
      expect(inputs['track'], 'internal');
    });

    test('signs only from the release-signing environment, or the dry run environment on a manual run', () {
      final environment = '${(jobs['build'] as YamlMap)['environment']}';
      expect(environment, contains("github.event_name == 'workflow_dispatch'"));
      expect(environment, contains("'release-dry-run'"));
      expect(environment, contains("'release-signing'"));
    });

    test('releases only a commit on main, and builds the commit that verify checked', () {
      final verify = jobs['verify'] as YamlMap;
      expect('${(verify['outputs'] as YamlMap?)?['sha']}', contains('steps.'), reason: 'verify must output its sha');
      final ancestor = _steps(jobs, 'verify').where((step) => '${step['run']}'.contains('merge-base --is-ancestor'));
      expect(ancestor, hasLength(1), reason: 'verify must check that the tag is on main');

      final checkout = _steps(jobs, 'build').firstWhere((step) => '${step['uses']}'.startsWith('actions/checkout@'));
      expect((checkout['with'] as YamlMap)['ref'], r'${{ needs.verify.outputs.sha }}');
    });

    test('one concurrency group for a hand-pushed tag and a release-please release of it', () {
      expect((workflow['concurrency'] as YamlMap)['group'], r'release-${{ inputs.tag || github.ref_name }}');
    });

    test('checkouts keep no credentials, nothing is cached, and every job has a timeout', () {
      for (final path in [_releasePath, _releasePleasePath]) {
        final all = _loadYaml(path)['jobs'] as YamlMap;
        for (final entry in all.entries) {
          final job = entry.value as YamlMap;
          if (job['uses'] != null) continue;
          expect(job['timeout-minutes'], isA<int>(), reason: 'job ${entry.key} in $path has no timeout-minutes');
          for (final step in _steps(all, entry.key as String)) {
            final inputs = step['with'] as YamlMap?;
            if ('${step['uses']}'.startsWith('actions/checkout@')) {
              expect(inputs?['persist-credentials'], isFalse, reason: 'a checkout in ${entry.key} keeps credentials');
            }
            expect(inputs?['cache'], isNot(isTrue), reason: 'a step in ${entry.key} of $path restores a cache');
          }
        }
      }
    });

    test('keeps the bundle briefly and logs no certificate owner', () {
      final steps = _steps(jobs, 'build');
      final artifact = steps.singleWhere((step) => '${step['uses']}'.startsWith('actions/upload-artifact@'));
      final days = (artifact['with'] as YamlMap)['retention-days'];
      expect(days, isA<int>());
      expect(days as int, lessThanOrEqualTo(7));

      final signature = steps.singleWhere((step) => '${step['run']}'.contains('keytool -printcert'));
      expect('${signature['run']}', isNot(contains('Owner')), reason: 'the certificate owner must not reach the log');
      expect('${signature['env']}', contains('vars.ANDROID_UPLOAD_CERT_SHA256'));
    });

    test('no run script expands a secret', () {
      for (final entry in jobs.entries) {
        for (final step in _steps(jobs, entry.key as String)) {
          expect(
            '${step['run'] ?? ''}',
            isNot(contains('secrets.')),
            reason: 'a run script in job ${entry.key} expands a secret; pass it through env instead',
          );
        }
      }
    });
  });

  group('check-only defines', () {
    late final checkOnly = _checkOnlyDefines();
    late final releaseDefines = _releaseDefines();

    test('the list names the Sentry device check, and the release passes none of them', () {
      expect(checkOnly, contains('SENTRY_DEVICE_CHECK'));
      expect(releaseDefines, isNotEmpty, reason: 'no define list found in $_releasePath');
      expect(releaseDefines.intersection(checkOnly), isEmpty, reason: 'the release passes a define meant for checks');
    });

    test('every define the app reads is one the release passes or one meant for checks', () {
      final read = <String, String>{};
      final pattern = RegExp(r"""(?:String|bool|int)\.fromEnvironment\(\s*'(\w+)'|dartDefines\["(\w+)"\]""");
      for (final file in [
        ...Directory('lib').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart')),
        File(_gradlePath),
      ]) {
        for (final match in pattern.allMatches(file.readAsStringSync())) {
          read[match[1] ?? match[2]!] = file.path;
        }
      }
      expect(read, contains('PROD_API_URL'), reason: 'the guard found no define; it looks in vain');

      final unsorted = [
        for (final entry in read.entries)
          if (!releaseDefines.contains(entry.key) &&
              !checkOnly.contains(entry.key) &&
              !_definesNeverSetByTheRelease.contains(entry.key))
            '${entry.key} (${entry.value})',
      ];
      expect(
        unsorted,
        isEmpty,
        reason:
            'Add each define to the list in $_releasePath, or to $_checkOnlyPath when only a check sets it:\n'
            '${unsorted.join('\n')}',
      );
    });

    test('the build job runs the check before the build and passes defines only from the checked file', () {
      final steps = _steps(_loadYaml(_releasePath)['jobs'] as YamlMap, 'build');
      final check = steps.indexWhere((step) => '${step['run']}'.contains(_checkScriptPath));
      final build = steps.indexWhere((step) => '${step['run']}'.contains('flutter build appbundle'));
      expect(check, isNonNegative, reason: 'the build job never runs $_checkScriptPath');
      expect(check, lessThan(build), reason: '$_checkScriptPath must run before the build');
      expect('${(steps[check]['env'] as YamlMap?)?['RELEASE_VARS']}', contains('toJSON(vars)'));
      expect('${steps[build]['run']}', isNot(contains('--dart-define=')), reason: 'pass defines only from the file');
    });

    group('check_defines.sh', () {
      late Directory dir;
      setUp(() => dir = Directory.systemTemp.createTempSync('check_defines'));
      tearDown(() => dir.deleteSync(recursive: true));

      Future<ProcessResult> check(Map<String, String> defines, {String vars = '{}'}) {
        final file = File('${dir.path}/dart-defines.json')..writeAsStringSync(jsonEncode(defines));
        return Process.run('bash', [_checkScriptPath, file.path], environment: {'RELEASE_VARS': vars});
      }

      test('passes the defines of a store build', () async {
        final result = await check({'PROD_API_URL': 'https://studio.example/api', 'OIDC_CLIENT_ID': 'app'});
        expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
      });

      test('fails on SENTRY_DEVICE_CHECK in the defines, whatever its value', () async {
        for (final value in ['true', 'false']) {
          final result = await check({'PROD_API_URL': 'https://studio.example/api', 'SENTRY_DEVICE_CHECK': value});
          expect(result.exitCode, isNot(0), reason: 'SENTRY_DEVICE_CHECK=$value passed');
          expect(result.stdout, contains('SENTRY_DEVICE_CHECK'));
        }
      });

      test('fails when a variable sets a check-only define', () async {
        final result = await check({
          'PROD_API_URL': 'https://studio.example/api',
        }, vars: '{"SENTRY_DEVICE_CHECK":"true"}');
        expect(result.exitCode, isNot(0));
        expect(result.stdout, contains('SENTRY_DEVICE_CHECK'));
      });

      test('fails when the variables are not a JSON object', () async {
        for (final vars in ['not json', '["SENTRY_DEVICE_CHECK"]']) {
          final result = await check({'PROD_API_URL': 'https://studio.example/api'}, vars: vars);
          expect(result.exitCode, isNot(anyOf(0, 1)), reason: 'RELEASE_VARS=$vars was not an error');
        }
      });

      test('fails on a defines file that is not a JSON object, or is missing', () async {
        final file = File('${dir.path}/dart-defines.json')..writeAsStringSync('PROD_API_URL=https://studio.example');
        for (final path in [file.path, '${dir.path}/missing.json']) {
          final result = await Process.run('bash', [_checkScriptPath, path], environment: {'RELEASE_VARS': '{}'});
          expect(result.exitCode, isNot(anyOf(0, 1)), reason: '$path was not an error');
        }
      });

      test('fails without the variables, so a broken step cannot pass in silence', () async {
        final file = File('${dir.path}/dart-defines.json')..writeAsStringSync('{}');
        final result = await Process.run('bash', [_checkScriptPath, file.path], environment: {'RELEASE_VARS': ''});
        expect(result.exitCode, isNot(0));
      });
    });
  });

  test('every action of the release workflows is pinned to a commit SHA', () {
    final offenders = <String>[];
    var actions = 0;
    for (final path in [_releasePath, _releasePleasePath]) {
      final jobs = _loadYaml(path)['jobs'] as YamlMap;
      for (final job in jobs.entries) {
        final body = job.value as YamlMap;
        final uses = <String>[
          if (body['uses'] != null) '${body['uses']}',
          for (final step in _steps(jobs, job.key as String))
            if (step['uses'] != null) '${step['uses']}',
        ];
        for (final action in uses) {
          if (action.startsWith('./')) continue;
          actions++;
          if (!RegExp(r'^[\w.-]+/[\w./-]+@[0-9a-f]{40}$').hasMatch(action)) offenders.add('$path: $action');
        }
      }
    }

    expect(actions, greaterThan(0), reason: 'the guard found no action; it looks in vain');
    expect(offenders, isEmpty, reason: 'pin each action to a full commit SHA:\n${offenders.join('\n')}');
  });

  test('release-please bumps pubspec.yaml from the version it names', () {
    final config = _loadYaml('release-please-config.json');
    final package = (config['packages'] as YamlMap)['.'] as YamlMap;
    expect(package['release-type'], 'dart');

    final manifest = _loadYaml('.release-please-manifest.json');
    final pubspec = _loadYaml('pubspec.yaml');
    final versionName = '${pubspec['version']}'.split('+').first;
    expect(manifest['.'], versionName, reason: '.release-please-manifest.json and pubspec.yaml name other versions');
    expect('${pubspec['version']}', matches(RegExp(r'^\d+\.\d+\.\d+\+\d+$')), reason: 'Play needs a build number');
  });

  group('release-please first release', () {
    late final package = (_loadJson('release-please-config.json')['packages'] as Map<String, Object?>)['.'];
    late final releaseDocs = File(_releaseDocsPath).readAsStringSync();

    test('release-as, when set, is a plain version', () {
      expect(package, isA<Map<String, Object?>>(), reason: 'release-please-config.json has no package "."');
      final releaseAs = (package! as Map<String, Object?>)['release-as'];
      if (releaseAs == null) return;
      expect(
        releaseAs,
        matches(RegExp(r'^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$')),
        reason: 'release-as: $releaseAs',
      );
    });

    test('the docs name the Actions setting release-please needs to open its pull request', () {
      expect(releaseDocs, contains('Allow GitHub Actions to create and approve pull requests'));
      expect(releaseDocs, contains('Workflow permissions'));
    });

    test('the docs say to remove release-as after the first release', () {
      expect(releaseDocs, contains('`release-as`'));
      expect(releaseDocs, matches(RegExp(r'remove `release-as`', caseSensitive: false)));
    });
  });
}

const _gradlePath = 'android/app/build.gradle.kts';
const _releaseDocsPath = 'docs/release.md';
const _releasePath = '.github/workflows/release.yml';
const _releasePleasePath = '.github/workflows/release-please.yml';
const _checkOnlyPath = 'tool/release/check_only_defines.txt';
const _checkScriptPath = 'tool/release/check_defines.sh';

/// Defines the app reads that the release never sets, so a store build keeps their defaults:
/// - `OIDC_REDIRECT_SCHEME`: an Android build receives its redirect only on the scheme of the manifest placeholder.
/// - `SCREEN_CAPTURE_PROTECTION`: the store build keeps screen capture protection on, its prod default (#192).
const _definesNeverSetByTheRelease = {'OIDC_REDIRECT_SCHEME', 'SCREEN_CAPTURE_PROTECTION'};

/// The names in [_checkOnlyPath], one per line, without `#` comments.
Set<String> _checkOnlyDefines() => {
  for (final line in File(_checkOnlyPath).readAsLinesSync())
    if (line.split('#').first.trim() case final name when name.isNotEmpty) name,
};

/// The defines the release workflow writes into the build's defines file: the quoted names of its `IN(...)` list.
Set<String> _releaseDefines() {
  final list = RegExp(r'IN\(([^)]*)\)').firstMatch(File(_releasePath).readAsStringSync());
  expect(list, isNotNull, reason: '$_releasePath has no IN(...) list of defines');
  return {for (final match in RegExp(r'"(\w+)"').allMatches(list![1]!)) match[1]!};
}

/// The environment variables the release build reads its upload key from.
const _signingEnvironment = [
  'ANDROID_UPLOAD_STORE_FILE',
  'ANDROID_UPLOAD_STORE_PASSWORD',
  'ANDROID_UPLOAD_KEY_ALIAS',
  'ANDROID_UPLOAD_KEY_PASSWORD',
];

Map<String, Object?> _loadJson(String path) => jsonDecode(File(path).readAsStringSync()) as Map<String, Object?>;

YamlMap _loadYaml(String path) => loadYaml(File(path).readAsStringSync()) as YamlMap;

/// The steps of the job [name] in [jobs], empty for a job that calls a reusable workflow.
List<YamlMap> _steps(YamlMap jobs, String name) {
  final job = jobs[name] as YamlMap?;
  expect(job, isNotNull, reason: 'the workflow has no job $name');
  return [...?(job!['steps'] as YamlList?)?.cast<YamlMap>()];
}

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
