import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/infrastructure/config/environment.dart';
import 'package:yaml/yaml.dart';

/// Guards the Android release signing and the release workflows (docs/release.md, issue #194).
///
/// - The release build reads its upload key only from the environment or the git-ignored `android/key.properties`,
///   never from a value written into `build.gradle.kts`, and `-PrequireReleaseSigning=true` makes a build without one
///   fail instead of falling back to the debug key.
/// - `key.properties` and every keystore stay git-ignored, and none is tracked.
/// - The release workflow builds with `-PrequireReleaseSigning=true`, deletes the decoded keystore also on failure,
///   uploads only from a job bound to the `play-internal` environment, and never on a dry run.
/// - Every action of every workflow is pinned to a full commit SHA and names its version in a comment (#209).
/// - The release-please manifest and `pubspec.yaml` name the same version.
/// - A `release-as` in the release-please config is a plain version, and docs/release.md names the Actions setting
///   release-please needs and the removal of `release-as` after the first release (#211).
/// - A store build never carries a define meant for checks only (`tool/release/check_only_defines.txt`), such as
///   `SENTRY_DEVICE_CHECK`: `tool/release/check_defines.sh` stops the release before the build, and every define the
///   app reads is either one the release passes or one of those.
/// - Every URL the release passes is one a prod start refuses unless it is https (#218).
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

      final steps = _steps(jobs, 'upload').where((step) => '${step['uses']}'.contains('upload-google-play')).toList();
      final tracks = [for (final step in steps) (step['with'] as YamlMap)['track']];
      // The owner's ruling on 2026-10-31: every release goes to both tracks, the testers' and the public's.
      expect(tracks, ['internal', 'production']);
      for (final step in steps) {
        expect((step['with'] as YamlMap)['packageName'], 'org.libredb.mobile');
      }
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

    // Platform mode reaches a store build only from the owner's variables (#299): unset, they leave the defines file
    // as it was, so the build stays Studio-only.
    test('passes the Platform defines only from optional variables, and prints no value', () {
      final step = _steps(jobs, 'build').singleWhere((step) => step['name'] == "Write the deployment's dart-defines");
      final run = '${step['run']}';
      final env = step['env'] as YamlMap;
      final required = RegExp(r'for name in ([^;]*); do').firstMatch(run);
      expect(required, isNotNull, reason: 'the step has no loop over the required variables');
      for (final name in _platformDefines) {
        expect(_releaseDefines(), contains(name), reason: '$name is not in the IN(...) list');
        expect(required![1]!.split(RegExp(r'\s+')), isNot(contains(name)), reason: '$name must stay optional');
        expect('${env[name]}', contains('vars.$name'), reason: '$name must come from the variables');
        expect('${env[name]}', isNot(contains('secrets.')), reason: '$name must never come from a secret');
        expect(run, isNot(matches(RegExp('echo[^\\n]*\\\$\\{?$name'))), reason: 'the step prints $name');
      }
      expect(run, contains('select(.value != ""'), reason: 'an unset variable must be left out of the defines file');
      expect(run, contains(r"jq -r 'keys | join"), reason: 'the step must log only the names it sets');
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

    test('no define is both one the release passes and one it never sets', () {
      expect(releaseDefines.intersection(_definesNeverSetByTheRelease), isEmpty);
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

    // The store build declares encryption in transit (#218): AppConfig.fromEnvironment stops a prod start when one of
    // these is not https, which test/infrastructure/config/environment_test.dart covers for each.
    test('every URL the release passes is checked for https at a prod start, with one pattern everywhere', () {
      final urls = {
        for (final name in releaseDefines)
          if (name.endsWith('_URL') || name.endsWith('_ISSUER') || name.endsWith('_DSN')) name,
      };
      expect(urls, containsAll(['PROD_API_URL', 'OIDC_ISSUER', 'SENTRY_DSN']), reason: 'the guard finds no URL');
      expect(
        urls.difference(AppConfig.httpsOnlyDefines),
        isEmpty,
        reason: 'add each URL define to AppConfig.httpsOnlyDefines and check it in AppConfig.fromEnvironment',
      );
      for (final path in [_checkScriptPath, _nativeSentryPath]) {
        expect(
          File(path).readAsStringSync(),
          contains(AppConfig.httpsUrlPattern),
          reason: '$path must check with the pattern of AppConfig.isHttpsUrl, verbatim',
        );
      }
      final build = _steps(
        _loadYaml(_releasePath)['jobs'] as YamlMap,
        'build',
      ).firstWhere((step) => '${step['run']}'.contains('flutter build appbundle'));
      expect('${build['run']}', contains('--target lib/main/main_prod.dart'), reason: 'the store build must be prod');
    });

    group('check_defines.sh', () {
      late Directory dir;
      setUp(() => dir = Directory.systemTemp.createTempSync('check_defines'));
      tearDown(() => dir.deleteSync(recursive: true));

      var files = 0;

      // Each call writes its own file, so the pin tests can run their cases at the same time.
      Future<ProcessResult> check(Map<String, Object?> defines, {String vars = '{}'}) {
        final file = File('${dir.path}/dart-defines-${files++}.json')..writeAsStringSync(jsonEncode(defines));
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

      // The same rule as a prod start (AppConfig.fromEnvironment, #218), so an http value stops the release before
      // anything is signed or uploaded.
      test('fails on each https-only define that is not https, naming it and not its value', () async {
        const store = {
          'PROD_API_URL': 'https://studio.example/api',
          'OIDC_ISSUER': 'https://keycloak.example/realms/libredb',
          'SENTRY_DSN': 'https://publickey@o1.ingest.sentry.example/1',
          'PLATFORM_API_URL': 'https://platform.example/api',
        };
        expect(store.keys.toSet(), AppConfig.httpsOnlyDefines);
        for (final name in AppConfig.httpsOnlyDefines) {
          for (final value in [
            'http://secretvalue.example/x',
            'secretvalue.example/x',
            'https:///secretvalue',
            'ftp://secretvalue.example/x',
          ]) {
            final result = await check({...store, name: value});
            expect(result.exitCode, 1, reason: '$name=$value passed: ${result.stdout}${result.stderr}');
            expect(result.stdout, contains('$name must be an https URL'), reason: '$name=$value');
            expect('${result.stdout}${result.stderr}', isNot(contains('secretvalue')), reason: '$name=$value');
          }
        }
      });

      test('passes https values in any case, and an unset SENTRY_DSN', () async {
        final result = await check({
          'PROD_API_URL': 'HTTPS://studio.example/api',
          'OIDC_ISSUER': 'https://localhost:8443/realms/libredb',
        });
        expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
      });

      test('applies the rule of a prod start: underscores, ports and IPv6 hosts pass, the issuer is trimmed', () async {
        final result = await check({
          'PROD_API_URL': 'https://my_studio.example:9443/api',
          'OIDC_ISSUER': '  https://[::1]:8443/realms/libredb\n',
          'SENTRY_DSN': 'https://publickey@my_sentry.example/1',
        });
        expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
      });

      test('fails on surrounding whitespace in PROD_API_URL, SENTRY_DSN or PLATFORM_API_URL, saying so', () async {
        for (final name in ['PROD_API_URL', 'SENTRY_DSN', 'PLATFORM_API_URL']) {
          final result = await check({
            'PROD_API_URL': 'https://studio.example/api',
            name: ' https://secretvalue.example/x',
          });
          expect(result.exitCode, 1, reason: name);
          expect(result.stdout, contains('$name has leading or trailing whitespace'), reason: name);
          expect('${result.stdout}${result.stderr}', isNot(contains('secretvalue')), reason: name);
        }
      });

      test('fails on an https-only define that is not a string, without printing it', () async {
        final file = File('${dir.path}/dart-defines.json')..writeAsStringSync('{"PROD_API_URL":["secretvalue"]}');
        final result = await Process.run('bash', [_checkScriptPath, file.path], environment: {'RELEASE_VARS': '{}'});
        expect(result.exitCode, isNot(0));
        expect('${result.stdout}${result.stderr}', isNot(contains('secretvalue')));
      });

      test('fails without the variables, so a broken step cannot pass in silence', () async {
        final file = File('${dir.path}/dart-defines.json')..writeAsStringSync('{}');
        final result = await Process.run('bash', [_checkScriptPath, file.path], environment: {'RELEASE_VARS': ''});
        expect(result.exitCode, isNot(0));
      });

      test('passes a store build with PLATFORM_API_URL and without it', () async {
        for (final platform in [<String, String>{}, _platformUrl]) {
          final result = await check({..._studio, ...platform});
          expect(result.exitCode, 0, reason: '$platform: ${result.stdout}${result.stderr}');
        }
      });

      test('fails on PLATFORM_CERT_PINS without PLATFORM_API_URL, naming both', () async {
        for (final platform in [
          <String, String>{},
          const {'PLATFORM_API_URL': ''},
        ]) {
          final result = await check({..._studio, ...platform, 'PLATFORM_CERT_PINS': '$_pinA,$_pinB'});
          expect(result.exitCode, 1, reason: '$platform: ${result.stdout}${result.stderr}');
          expect(result.stdout, allOf(contains('PLATFORM_CERT_PINS'), contains('PLATFORM_API_URL')));
          expect('${result.stdout}${result.stderr}', isNot(anyOf(contains(_pinA), contains(_pinB))));
        }
      });

      test('passes a pin define that is only whitespace, as a prod start does', () async {
        for (final defines in [
          {..._studio, 'PLATFORM_CERT_PINS': '  '},
          {..._studio, 'STUDIO_CERT_PINS': ' \t'},
        ]) {
          final result = await check(defines);
          expect(result.exitCode, 0, reason: '$defines: ${result.stdout}${result.stderr}');
        }
      });

      test('fails on each pin define that breaks a rule of a prod start, naming it and never an entry', () async {
        final cases = [
          for (final name in _pinDefines)
            for (final MapEntry(key: label, value: value) in {
              ..._refusedPins,
              'not a string': [_pinA, _pinB],
            }.entries)
              (name: name, label: label, run: check({..._studio, ..._platformUrl, name: value})),
        ];
        for (final (:name, :label, :run) in cases) {
          final result = await run;
          final output = '${result.stdout}${result.stderr}';
          expect(result.exitCode, 1, reason: '$name, $label: $output');
          expect(result.stdout, contains(name), reason: '$name, $label');
          expect(output, isNot(anyOf(contains('secretvalue'), contains(_pinA), contains(_pinB))), reason: label);
          expect(output, isNot(contains(_pinA.substring(0, 20))), reason: '$name, $label');
        }
      });

      test('passes two distinct valid pins with spaces around the comma, for each pin define', () async {
        for (final name in _pinDefines) {
          final result = await check({..._studio, ..._platformUrl, name: ' $_pinA , $_pinB '});
          expect(result.exitCode, 0, reason: '$name: ${result.stdout}${result.stderr}');
        }
      });

      // The script and a prod start must agree on every pin value, or a release passes the check and then the app
      // throws at its first start.
      test('refuses exactly the pin values a prod start refuses', () async {
        bool startRefuses(String name, String value, {required bool platformUrl}) {
          try {
            AppConfig.fromEnvironment(
              Environment.prod,
              prodApiUrlDefine: _studio['PROD_API_URL']!,
              oidcIssuerDefine: '',
              sentryDsnDefine: '',
              screenCaptureProtectionDefine: '',
              appLockRequiredDefine: '',
              platformApiUrlDefine: platformUrl ? _platformUrl['PLATFORM_API_URL']! : '',
              studioCertPinsDefine: name == 'STUDIO_CERT_PINS' ? value : '',
              oidcCertPinsDefine: name == 'OIDC_CERT_PINS' ? value : '',
              platformCertPinsDefine: name == 'PLATFORM_CERT_PINS' ? value : '',
            );
            return false;
          } on CertificatePinsConfigError {
            return true;
          }
        }

        final cases = [
          for (final name in _pinDefines)
            for (final platformUrl in [true, if (name == 'PLATFORM_CERT_PINS') false])
              for (final MapEntry(key: label, value: value) in {..._refusedPins, ..._acceptedPins}.entries)
                (
                  where: '$name, $label, PLATFORM_API_URL ${platformUrl ? 'set' : 'unset'}',
                  refused: startRefuses(name, value, platformUrl: platformUrl),
                  run: check({..._studio, if (platformUrl) ..._platformUrl, name: value}),
                ),
        ];
        for (final (:where, :refused, :run) in cases) {
          final result = await run;
          expect(result.exitCode, refused ? 1 : 0, reason: '$where: ${result.stdout}${result.stderr}');
        }
      });
    });
  });

  group('workflow actions', () {
    late final workflows = _workflowPaths();

    test('every action of every workflow is pinned to a commit SHA', () {
      final offenders = <String>[];
      var actions = 0;
      for (final path in workflows) {
        for (final action in _workflowActions(path)) {
          if (action.startsWith('./')) continue;
          actions++;
          if (!_pinnedAction.hasMatch(action)) offenders.add('$path: $action');
        }
      }

      expect(workflows, containsAll([_releasePath, _releasePleasePath, _buildAndTestPath, _sonarPath]));
      expect(actions, greaterThan(0), reason: 'the guard found no action; it looks in vain');
      expect(offenders, isEmpty, reason: 'pin each action to a full commit SHA:\n${offenders.join('\n')}');
    });

    test('every pinned action names its version in a comment on the same line', () {
      final offenders = <String>[];
      var lines = 0;
      for (final path in workflows) {
        final parsed = _workflowActions(path).where((action) => !action.startsWith('./')).length;
        final found = <String>[];
        for (final line in File(path).readAsLinesSync()) {
          final match = _usesLine.firstMatch(line);
          if (match == null || match.group(1)!.startsWith('./')) continue;
          found.add(line);
          if (!RegExp(r'@[0-9a-f]{40} # v\d+(\.\d+){0,2}$').hasMatch(line.trimRight())) {
            offenders.add('$path: ${line.trim()}');
          }
        }
        expect(found, hasLength(parsed), reason: '$path has a uses: line the guard cannot read; write one per line');
        lines += found.length;
      }

      expect(lines, greaterThan(0), reason: 'the guard found no uses: line; it looks in vain');
      expect(offenders, isEmpty, reason: 'end each uses: line with "# vX.Y.Z":\n${offenders.join('\n')}');
    });

    test('the pin check refuses a tag or a branch', () {
      for (final action in [
        'actions/checkout@v6',
        'actions/checkout@main',
        'actions/checkout@d23441a',
        'actions/checkout@v6.1.0',
        'actions/checkout@d23441a48e516b6c34aea4fa41551a30e30af803a',
      ]) {
        expect(_pinnedAction.hasMatch(action), isFalse, reason: '$action passed the pin check');
      }
      expect(_pinnedAction.hasMatch('actions/checkout@d23441a48e516b6c34aea4fa41551a30e30af803'), isTrue);
    });
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

    test('release-as is gone once its version has a released section in the changelog', () {
      final releaseAs = (package! as Map<String, Object?>)['release-as'];
      if (releaseAs == null) return;
      final changelog = File(_changelogPath).readAsStringSync();
      expect(
        changelog,
        isNot(contains('## [$releaseAs]')),
        reason:
            'release-please already released $releaseAs, so release-as pins every later release pull request to it '
            '(docs/release.md, step 11)',
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
const _changelogPath = 'CHANGELOG.md';
const _releaseDocsPath = 'docs/release.md';
const _releasePath = '.github/workflows/release.yml';
const _releasePleasePath = '.github/workflows/release-please.yml';
const _buildAndTestPath = '.github/workflows/build_and_test.yml';
const _sonarPath = '.github/workflows/sonar_scanner.yml';
const _checkOnlyPath = 'tool/release/check_only_defines.txt';
const _checkScriptPath = 'tool/release/check_defines.sh';
const _nativeSentryPath = 'android/app/src/main/kotlin/org/libredb/mobile/NativeSentry.kt';

/// Defines the app reads that the release never sets, so a store build keeps their defaults:
/// - `OIDC_REDIRECT_SCHEME`: an Android build receives its redirect only on the scheme of the manifest placeholder.
/// - `SCREEN_CAPTURE_PROTECTION`: the store build keeps screen capture protection on, its prod default (#192).
/// - `APP_LOCK_REQUIRED`: the store build leaves the app lock to the user, its default (#195).
const _definesNeverSetByTheRelease = {'OIDC_REDIRECT_SCHEME', 'SCREEN_CAPTURE_PROTECTION', 'APP_LOCK_REQUIRED'};

/// The defines that turn on Platform mode, which the release passes only from the owner's variables (#299).
const _platformDefines = ['PLATFORM_API_URL', 'PLATFORM_CERT_PINS'];

/// The pin defines a prod start checks with `AppConfig._pins`, and `tool/release/check_defines.sh` with the same rule.
const _pinDefines = ['STUDIO_CERT_PINS', 'OIDC_CERT_PINS', 'PLATFORM_CERT_PINS'];

const _studio = {'PROD_API_URL': 'https://studio.example/api'};
const _platformUrl = {'PLATFORM_API_URL': 'https://platform.example/api'};

/// Two distinct pins in the canonical form; [_pinB] holds a `+` and a `/`, so its URL-safe form differs from it.
final _pinA = base64.encode(List.filled(32, 0x01));
final _pinB = base64.encode(List.filled(32, 0xFB));

/// Pin values a prod start refuses, by what is wrong with them.
final _refusedPins = {
  'one pin': _pinA,
  'two equal pins': '$_pinA,$_pinA',
  'two equal pins with other spaces': ' $_pinA,$_pinA  ',
  'a 43-character entry': '${_pinA.substring(0, 43)},$_pinB',
  'a non-canonical last character': '${_pinA.substring(0, 42)}F=,$_pinB',
  'a URL-safe entry': '${_pinB.replaceAll('+', '-').replaceAll('/', '_')},$_pinA',
  'a 44-character entry of 33 bytes': '${base64.encode(List.filled(33, 0x01))},$_pinB',
  'a 48-character entry of 34 bytes': '${base64.encode(List.filled(34, 0x01))},$_pinB',
  'a trailing comma': '$_pinA,$_pinB,',
  'an empty entry': '$_pinA,,$_pinB',
  'an entry that is no pin': 'secretvalue,$_pinA,$_pinB',
};

/// Pin values a prod start accepts when the define's host is set.
final _acceptedPins = {
  'empty': '',
  'only whitespace': ' \t ',
  'two distinct pins': '$_pinA,$_pinB',
  'two distinct pins with spaces': ' $_pinA , $_pinB ',
  'three entries, two distinct': '$_pinA,$_pinB,$_pinA',
};

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

final _pinnedAction = RegExp(r'^[\w.-]+/[\w./-]+@[0-9a-f]{40}$');
final _usesLine = RegExp(r'^\s*(?:-\s+)?uses:\s*(\S+)');

/// Every workflow file, sorted, so a new workflow is guarded without a change here.
List<String> _workflowPaths() =>
    Directory('.github/workflows')
        .listSync()
        .whereType<File>()
        .map((file) => file.path.replaceAll(r'\', '/'))
        .where((path) => path.endsWith('.yml') || path.endsWith('.yaml'))
        .toList()
      ..sort();

/// The `uses:` value of each job and each step of the workflow at [path].
List<String> _workflowActions(String path) {
  final jobs = _loadYaml(path)['jobs'] as YamlMap;
  return [
    for (final job in jobs.entries) ...[
      if ((job.value as YamlMap)['uses'] != null) '${(job.value as YamlMap)['uses']}',
      for (final step in _steps(jobs, job.key as String))
        if (step['uses'] != null) '${step['uses']}',
    ],
  ];
}

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
