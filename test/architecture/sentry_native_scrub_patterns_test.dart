import 'dart:io';

import 'package:libredb_mobile/core/security/sensitive_data_scrubber.dart';
import 'package:libredb_mobile/infrastructure/analytics/native_sentry_start.dart';
import 'package:libredb_mobile/infrastructure/analytics/sentry_scrub.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guards the Kotlin copy of the scrub policy that the Android host masks native Sentry events and breadcrumbs with.
///
/// `NativeScrubPatterns.kt` holds each pattern in a raw string, which Kotlin reads without escape processing, so its
/// text must equal the Dart pattern byte for byte; the sets and the masks must equal the Dart ones too. A Kotlin raw
/// string still reads `$` as a template, so no pattern may contain one.
///
/// The patterns must also mean the same thing on the device. Android's `java.util.regex` is backed by ICU, which reads
/// `\w`, `\d` and `\b` as Unicode classes and lets `.` skip U+0085, while Dart and the OpenJDK of the JVM unit tests
/// read them as ASCII, so the patterns spell out explicit classes instead. `\s` is spelled out too: Dart reads it with
/// U+FEFF and without U+0085, ICU the other way round, and OpenJDK as ASCII only. No pattern takes a case-insensitive
/// flag, which Kotlin turns into Unicode case folding.
///
/// The Swift copy under `ios/Runner` is guarded the same way: a Swift raw string (`#"..."#`) also reads no escape,
/// and NSRegularExpression is ICU too, so the same patterns must hold there byte for byte and without a flag.
///
/// The logic is held equal by `test/fixtures/native_scrub_cases.json`, which the Dart scrubber test,
/// `NativeSentryScrubberTest.kt` and `NativeSentryScrubberTests.swift` all run.
void main() {
  const patternsPath = 'android/app/src/main/kotlin/org/libredb/mobile/NativeScrubPatterns.kt';
  const scrubberPath = 'android/app/src/main/kotlin/org/libredb/mobile/NativeSentryScrubber.kt';
  const swiftPatternsPath = 'ios/Runner/NativeScrubPatterns.swift';
  const swiftScrubberPath = 'ios/Runner/NativeSentryScrubber.swift';
  const iosGatePath = 'ios/native_sentry_defines.sh';

  final dartPatterns = {
    'JWT_PATTERN': jwtPattern,
    'EMAIL_PATTERN': emailPattern,
    'JSON_MEMBER_PATTERN': jsonMemberPattern,
    'NAMED_VALUE_PATTERN': namedValuePattern,
    'BEARER_PATTERN': bearerPattern,
  };
  final dartSets = {
    'SENSITIVE_HEADER_NAMES': sensitiveHeaderNames,
    'SENSITIVE_HEADER_NAME_SUBSTRINGS': sensitiveHeaderNameSubstrings,
    'SENSITIVE_BODY_KEY_SUBSTRINGS': sensitiveBodyKeySubstrings,
    'SENSITIVE_EXACT_KEYS': sensitiveExactKeys,
    'NAVIGATION_TYPES': sentryNavigationTypes,
  };
  const dartMasks = {'SECRET_MASK': secretMask, 'JWT_MASK': jwtMask, 'EMAIL_MASK': emailMask};

  // The same policy under the names the Swift copy gives it.
  final swiftPatterns = {
    'jwtPattern': jwtPattern,
    'emailPattern': emailPattern,
    'jsonMemberPattern': jsonMemberPattern,
    'namedValuePattern': namedValuePattern,
    'bearerPattern': bearerPattern,
  };
  final swiftSets = {
    'sensitiveHeaderNames': sensitiveHeaderNames,
    'sensitiveHeaderNameSubstrings': sensitiveHeaderNameSubstrings,
    'sensitiveBodyKeySubstrings': sensitiveBodyKeySubstrings,
    'sensitiveExactKeys': sensitiveExactKeys,
    'navigationTypes': sentryNavigationTypes,
  };
  const swiftMasks = {'secretMask': secretMask, 'jwtMask': jwtMask, 'emailMask': emailMask};

  /// Every difference between the constants of [swiftSource] and the Dart policy.
  List<String> swiftMismatches(String swiftSource) {
    final raw = {
      for (final match in RegExp(r'^\s*static let ([A-Za-z]+) = #"(.*)"#\s*$', multiLine: true).allMatches(swiftSource))
        match[1]!: match[2]!,
    };
    final plain = {
      for (final match in RegExp(
        r'^\s*static let ([A-Za-z]+) = "([^"]*)"\s*$',
        multiLine: true,
      ).allMatches(swiftSource))
        match[1]!: match[2]!,
    };
    final problems = <String>[];
    final expectedNames = {...swiftPatterns.keys, ...swiftSets.keys, ...swiftMasks.keys};
    final extra = {...raw.keys, ...plain.keys}.difference(expectedNames);
    if (extra.isNotEmpty) problems.add('constants without a Dart counterpart: $extra');
    for (final MapEntry(key: name, value: pattern) in swiftPatterns.entries) {
      final swift = raw[name];
      if (swift == null) {
        problems.add('$name is missing or not a raw string');
      } else if (swift != pattern.pattern) {
        problems.add('$name differs:\n  Swift: $swift\n  Dart:  ${pattern.pattern}');
      }
      if (swift != null && swift.contains(r'\#(')) {
        problems.add('$name contains a \\#(, which Swift reads as an interpolation');
      }
    }
    for (final MapEntry(key: name, value: values) in swiftSets.entries) {
      final swift = plain[name];
      if (swift == null) {
        problems.add('$name is missing');
      } else if (!_sameSet(swift.split(','), values)) {
        problems.add('$name differs: Swift {$swift}, Dart $values');
      }
    }
    for (final MapEntry(key: name, value: mask) in swiftMasks.entries) {
      if (plain[name] != mask) problems.add('$name differs: Swift ${plain[name]}, Dart $mask');
    }
    return problems;
  }

  /// Every difference between the constants of [kotlinSource] and the Dart policy.
  List<String> mismatches(String kotlinSource) {
    final raw = {
      for (final match in RegExp(r'^\s*const val ([A-Z_]+) = """(.*)"""\s*$', multiLine: true).allMatches(kotlinSource))
        match[1]!: match[2]!,
    };
    final plain = {
      for (final match in RegExp(r'^\s*const val ([A-Z_]+) = "([^"]*)"\s*$', multiLine: true).allMatches(kotlinSource))
        match[1]!: match[2]!,
    };
    final problems = <String>[];
    final expectedNames = {...dartPatterns.keys, ...dartSets.keys, ...dartMasks.keys};
    final extra = {...raw.keys, ...plain.keys}.difference(expectedNames);
    if (extra.isNotEmpty) problems.add('constants without a Dart counterpart: $extra');
    for (final MapEntry(key: name, value: pattern) in dartPatterns.entries) {
      final kotlin = raw[name];
      if (kotlin == null) {
        problems.add('$name is missing or not a raw string');
      } else if (kotlin != pattern.pattern) {
        problems.add('$name differs:\n  Kotlin: $kotlin\n  Dart:   ${pattern.pattern}');
      }
      if (kotlin != null && kotlin.contains(r'$')) {
        problems.add('$name contains a \$, which Kotlin reads as a template');
      }
    }
    for (final MapEntry(key: name, value: values) in dartSets.entries) {
      final kotlin = plain[name];
      if (kotlin == null) {
        problems.add('$name is missing');
      } else if (!_sameSet(kotlin.split(','), values)) {
        problems.add('$name differs: Kotlin {$kotlin}, Dart $values');
      }
    }
    for (final MapEntry(key: name, value: mask) in dartMasks.entries) {
      if (plain[name] != mask) problems.add('$name differs: Kotlin ${plain[name]}, Dart $mask');
    }
    return problems;
  }

  test('the Kotlin patterns, sets and masks equal the Dart ones', () {
    final source = File(patternsPath).readAsStringSync();

    final problems = mismatches(source);

    expect(problems, isEmpty, reason: '$patternsPath no longer matches the Dart policy:\n${problems.join('\n')}');
  });

  // Proves on every run that the comparison above would catch a changed native pattern string.
  test('a changed Kotlin pattern string is reported', () {
    final source = File(patternsPath).readAsStringSync();
    final changed = source.replaceFirst('[A-Za-z0-9_-]{4,}', '[A-Za-z0-9_-]{5,}');

    expect(changed, isNot(source));
    expect(mismatches(changed), [contains('JWT_PATTERN differs')]);
  });

  test('the Kotlin scrubber compiles the patterns with the flags of the Dart ones', () {
    final scrubber = File(scrubberPath).readAsStringSync();

    // Kotlin's IGNORE_CASE adds UNICODE_CASE, under which `[A-Za-z]` also matches U+017F and the Kelvin sign, while
    // Dart's caseSensitive: false does not: a pattern spells out both cases instead.
    for (final MapEntry(key: name, value: pattern) in dartPatterns.entries) {
      expect(
        pattern.isMultiLine || pattern.isUnicode || pattern.isDotAll || !pattern.isCaseSensitive,
        isFalse,
        reason: '$name has a flag',
      );
      final compiled = 'Regex(NativeScrubPatterns.$name)';
      expect(scrubber, contains(compiled), reason: '$scrubberPath must compile $name as $compiled');
    }
    expect(scrubber, isNot(contains('RegexOption')), reason: '$scrubberPath must compile the patterns without options');
  });

  test('the Swift patterns, sets and masks equal the Dart ones', () {
    final source = File(swiftPatternsPath).readAsStringSync();

    final problems = swiftMismatches(source);

    expect(problems, isEmpty, reason: '$swiftPatternsPath no longer matches the Dart policy:\n${problems.join('\n')}');
  });

  // Proves on every run that the comparison above would catch a changed Swift pattern string.
  test('a changed Swift pattern string is reported', () {
    final source = File(swiftPatternsPath).readAsStringSync();
    final changed = source.replaceFirst('[A-Za-z0-9_-]{4,}', '[A-Za-z0-9_-]{5,}');

    expect(changed, isNot(source));
    expect(swiftMismatches(changed), [contains('jwtPattern differs')]);
  });

  test('the Swift scrubber compiles the patterns with the flags of the Dart ones', () {
    final scrubber = File(swiftScrubberPath).readAsStringSync();

    for (final name in swiftPatterns.keys) {
      expect(
        scrubber,
        contains('$name: String = NativeScrubPatterns.$name'),
        reason: '$swiftScrubberPath must take $name from NativeScrubPatterns',
      );
      expect(
        scrubber,
        contains('NSRegularExpression(pattern: $name)'),
        reason: '$swiftScrubberPath must compile $name as NSRegularExpression(pattern: $name)',
      );
    }
    // NSRegularExpression.Options.caseInsensitive folds Unicode as Kotlin's IGNORE_CASE does: a pattern spells out
    // both cases instead, and none of them is compiled with an option.
    expect(
      scrubber,
      isNot(contains('options:')),
      reason: '$swiftScrubberPath must compile the patterns without options',
    );
  });

  // The iOS host starts sentry-cocoa only when the Flutter target is this file, and on iOS every Dart event leaves
  // through the native SDK, so the gate must name the entry point that selects the prod environment, as the Gradle
  // gate does. nativeSdkReady fails loudly at start when the two still disagree.
  test('the gate of the iOS native SDK names the only entry point that selects the prod environment', () {
    final gate = RegExp(r'\*/(\w+\.dart)').allMatches(File(iosGatePath).readAsStringSync()).map((m) => m[1]).toSet();

    expect(gate, [_prodEntryPoints().single]);
  });

  test('the iOS native SDK gets the DSN only through its gate', () {
    final script = File(iosGatePath).readAsStringSync();

    final problems = _iosGateProblems(script);

    expect(problems, isEmpty, reason: problems.join('\n'));
  });

  test('an ungated DSN in the iOS script is reported', () {
    final script = File(iosGatePath).readAsStringSync();
    final ungated = script.replaceFirst(RegExp(r'^.*\*/\w+\.dart.*\n', multiLine: true), '');

    expect(ungated, isNot(script));
    expect(_iosGateProblems(ungated), isNotEmpty);
  });

  test('AppDelegate answers on the channel that nativeSdkReady asks', () {
    final appDelegate = File('ios/Runner/AppDelegate.swift').readAsStringSync();
    final nativeSentry = File('ios/Runner/NativeSentry.swift').readAsStringSync();

    expect(nativeSentry, contains('static let channelName = "$nativeSentryChannelName"'));
    expect(appDelegate, contains('name: NativeSentry.channelName'));
    expect(appDelegate, contains('result(SentrySDK.isEnabled)'));
  });

  test('the shared patterns use no class that ICU reads differently from Dart', () {
    final offenders = [
      for (final MapEntry(key: name, value: pattern) in dartPatterns.entries)
        if (_nonPortable(pattern.pattern) case final construct?) '$name uses $construct',
    ];

    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  // The host starts sentry-android only when the Flutter target is this file, and on Android every Dart event leaves
  // through the native SDK, so the Gradle gate must name the entry point that selects the prod environment, in which
  // AppConfig.sentryDsn starts the Dart SDK. nativeSdkReady fails loudly at start when the two still disagree.
  test('the Gradle gate of the native SDK names the only entry point that selects the prod environment', () {
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();
    final gate = RegExp(r'\.name == "([^"]+)"').allMatches(gradle).map((match) => match[1]).toList();
    final prodEntryPoints = Directory('lib/main')
        .listSync()
        .whereType<File>()
        .where((file) => file.readAsStringSync().contains('Environment.prod'))
        .map((file) => file.uri.pathSegments.last)
        .toList();

    expect(gate, hasLength(1), reason: 'android/app/build.gradle.kts must compare the target file name once');
    expect(prodEntryPoints, [gate.single]);
  });

  // Without this a Gradle file that feeds SENTRY_DSN straight from the define passes the test above, and a
  // main_mock.dart or main_local.dart build with a DSN starts sentry-android while the Dart side never starts Sentry.
  test('the native SDK gets the DSN only through the Gradle gate', () {
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();

    final problems = _dsnGateProblems(gradle);

    expect(problems, isEmpty, reason: problems.join('\n'));
  });

  test('an ungated DSN in the Gradle file is reported', () {
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();
    final ungated = gradle.replaceFirst(
      'if (isProdTarget) dartDefines["SENTRY_DSN"].orEmpty() else ""',
      'dartDefines["SENTRY_DSN"].orEmpty()',
    );

    expect(ungated, isNot(gradle));
    expect(_dsnGateProblems(ungated), isNotEmpty);
  });

  test('MainActivity answers on the channel that nativeSdkReady asks', () {
    final activity = File('android/app/src/main/kotlin/org/libredb/mobile/MainActivity.kt').readAsStringSync();

    expect(activity, contains('"$nativeSentryChannelName"'));
    expect(activity, contains('"isEnabled" -> result.success(Sentry.isEnabled())'));
  });

  // Sentry Logs come only from an explicit Sentry.logger call, and the app makes none. The Sentry Android Gradle plugin
  // would rewrite android.util.Log calls into Sentry logs, and sentry_logging would forward log records; neither may
  // come in without a scrubber for the logs they bring.
  test('nothing turns a log line into a Sentry log', () {
    final gradleFiles = [
      'android/settings.gradle.kts',
      'android/build.gradle.kts',
      'android/app/build.gradle.kts',
    ].map((path) => File(path).readAsStringSync());
    final dartFiles = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'));

    for (final gradle in gradleFiles) {
      expect(gradle, isNot(contains('io.sentry')));
    }
    expect(File('pubspec.yaml').readAsStringSync(), isNot(contains('sentry_logging')));
    for (final file in dartFiles) {
      expect(file.readAsStringSync(), isNot(matches(RegExp(r'Sentry\.logger|sentry_logging'))), reason: file.path);
    }
  });

  // The device check of docs/crash-reporting.md crashes the app only in a build that also starts the native SDK.
  test('the native crash of the device check is gated like the DSN', () {
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();

    expect(gradle, contains('val sentryDeviceCheck = isProdTarget && dartDefines["SENTRY_DEVICE_CHECK"] == "true"'));
    expect(gradle, contains('buildConfigField("boolean", "SENTRY_DEVICE_CHECK", sentryDeviceCheck.toString())'));
    expect(RegExp('SENTRY_DEVICE_CHECK').allMatches(gradle), hasLength(2));
  });
}

/// What is wrong with how [gradle] passes SENTRY_DSN to the native SDK: the BuildConfig field must take a value that is
/// the define only when `isProdTarget`, `isProdTarget` must be the file name check, and the define must be read nowhere
/// else.
List<String> _dsnGateProblems(String gradle) {
  final problems = <String>[];
  final field = RegExp(r'buildConfigField\("String", "SENTRY_DSN", buildConfigString\(([A-Za-z_][A-Za-z0-9_]*)\)\)')
      .allMatches(gradle)
      .toList();
  if (field.length != 1) return ['SENTRY_DSN must be one buildConfigField fed by a val, found ${field.length}'];
  final name = field.single[1]!;
  final gated = 'val $name = if (isProdTarget) dartDefines["SENTRY_DSN"].orEmpty() else ""';
  if (!gradle.contains(gated)) problems.add('$name must be set as: $gated');
  if (!RegExp(r'val isProdTarget = File\([^\n]*\)\.name == "[^"]+"').hasMatch(gradle)) {
    problems.add('isProdTarget must compare the file name of the target');
  }
  final reads = 'dartDefines["SENTRY_DSN"]'.allMatches(gradle).length;
  if (reads != 1) problems.add('the SENTRY_DSN define must be read once, in the gate, found $reads reads');
  return problems;
}

/// The entry points under `lib/main` that select the prod environment, in which `AppConfig.sentryDsn` starts the
/// Dart SDK; both native gates must name the one there is.
List<String> _prodEntryPoints() =>
    Directory('lib/main')
        .listSync()
        .whereType<File>()
        .where((file) => file.readAsStringSync().contains('Environment.prod'))
        .map((file) => file.uri.pathSegments.last)
        .toList();

/// What is wrong with how [script] passes SENTRY_DSN to the iOS native SDK: every write of a Sentry key into the
/// built Info.plist must stand after the gate that leaves a build of another entry point, and the define must be
/// read nowhere else.
List<String> _iosGateProblems(String script) {
  final problems = <String>[];
  final gate = script.indexOf(RegExp(r'\*/\w+\.dart'));
  if (gate < 0) return ['the script must gate on the file name of FLUTTER_TARGET'];
  for (final match in RegExp(r'PlistBuddy -c "Add :').allMatches(script)) {
    if (match.start < gate) problems.add('a Sentry key is written before the gate, at ${match.start}');
  }
  final reads = RegExp(r'DART_DEFINES').allMatches(script).length;
  if (reads != 1) problems.add('the DART_DEFINES of the build must be read once, after the gate, found $reads reads');
  return problems;
}

bool _sameSet(List<String> kotlin, Set<String> dart) =>
    kotlin.length == dart.length && kotlin.toSet().containsAll(dart);

/// The first construct in [pattern] that ICU or OpenJDK reads differently from Dart: `\w`, `\d`, `\b`, `\s`, or a `.`
/// that is neither escaped nor inside a character class.
String? _nonPortable(String pattern) {
  var inClass = false;
  for (var i = 0; i < pattern.length; i++) {
    final char = pattern[i];
    if (char == r'\') {
      if (i + 1 < pattern.length && 'wWdDbBsS'.contains(pattern[i + 1])) return '\\${pattern[i + 1]}';
      i++;
    } else if (char == '[') {
      inClass = true;
    } else if (char == ']') {
      inClass = false;
    } else if (char == '.' && !inClass) {
      return 'a bare .';
    }
  }
  return null;
}
