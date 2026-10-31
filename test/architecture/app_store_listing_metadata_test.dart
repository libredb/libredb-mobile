import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the App Store listing texts in `ios/fastlane/metadata/` (issue #199).
///
/// The texts sit in the fastlane deliver layout, so a later pipeline step can upload them: one directory per locale,
/// each with `name.txt`, `subtitle.txt`, `description.txt`, `keywords.txt` and `promotional_text.txt`
/// (`docs/release.md`). App Store Connect refuses a listing whose name or subtitle is longer than 30 characters,
/// whose description is longer than 4000, whose keywords are longer than 100 or whose promotional text is longer
/// than 170, so this test fails before the Console would. Connect counts characters, not bytes, so a Turkish `ş`
/// counts as one.
///
/// The locales are App Store Connect's own, not Play's: Turkish is `tr` there and `tr-TR` on Play, so the two stores
/// cannot share a directory. The English and the Turkish listing must hold the same files, so a text added to one
/// locale is not forgotten in the other.
///
/// No listing text holds an en dash or an em dash, the same rule the Play listing follows
/// (`test/architecture/play_listing_metadata_test.dart`).
void main() {
  test('each locale has the five listing texts within App Store Connect\'s lengths', () {
    final problems = [for (final locale in _locales) ...appStoreListingProblems(Directory('$_metadataRoot/$locale'))];

    expect(problems, isEmpty, reason: problems.join('\n'));
  });

  test('the listing has exactly the en-US and tr locales, holding the same files', () {
    final root = Directory(_metadataRoot);
    expect(root.existsSync(), isTrue, reason: '$_metadataRoot does not exist');

    final locales = [for (final entry in root.listSync().whereType<Directory>()) _name(entry.path)]..sort();
    expect(locales, _locales);

    final english = _relativeFiles(Directory('$_metadataRoot/en-US'));
    final turkish = _relativeFiles(Directory('$_metadataRoot/tr'));
    expect(english, isNotEmpty);
    expect(turkish, english, reason: 'en-US and tr must hold the same files');
  });

  test('the app lock is described as a setting, because it ships off', () {
    // `AppLockSettings.defaults` is `enabled: false`, and the release workflow never passes `APP_LOCK_REQUIRED`
    // (`test/architecture/android_release_setup_test.dart` pins that), so a reader who installs the store build and
    // comes back to it is not asked for Face ID until they turn the lock on. A description that states the lock
    // flatly, beside the properties that do hold on their own, promises behaviour the build does not have.
    final problems = <String>[];
    for (final MapEntry(key: locale, value: marker) in _optInMarkers.entries) {
      final text = File('$_metadataRoot/$locale/description.txt').readAsStringSync();
      for (final line in text.split('\n')) {
        if (!_biometricWords.any(line.contains)) continue;
        if (!marker.any(line.contains)) {
          problems.add(
            '$_metadataRoot/$locale/description.txt names a biometric lock without saying it is a '
            'setting: "${line.trim()}"',
          );
        }
      }
    }

    expect(problems, isEmpty, reason: problems.join('\n'));
  });

  test('no listing text holds an en dash or an em dash', () {
    final offending = [
      for (final file in Directory(_metadataRoot).listSync(recursive: true).whereType<File>())
        if (file.path.endsWith('.txt') && file.readAsStringSync().contains(RegExp('[–—]'))) file.path,
    ];

    expect(offending, isEmpty, reason: 'U+2013 or U+2014 in ${offending.join(', ')}');
  });

  group('appStoreListingProblems', () {
    late Directory temp;

    setUp(() => temp = Directory.systemTemp.createTempSync('app_store_listing_'));
    tearDown(() => temp.deleteSync(recursive: true));

    void write(String name, String text) => File('${temp.path}/$name').writeAsStringSync(text);

    test('accepts texts at the limits, counting characters rather than bytes', () {
      write('name.txt', 'ş' * 30);
      write('subtitle.txt', 'ğ' * 30);
      write('description.txt', 'ü' * 4000);
      write('keywords.txt', 'ı' * 100);
      write('promotional_text.txt', 'ö' * 170);

      expect(appStoreListingProblems(temp), isEmpty);
    });

    test('names a text one character past its limit', () {
      write('name.txt', 'a' * 31);
      write('subtitle.txt', 'b' * 31);
      write('description.txt', 'c' * 4001);
      write('keywords.txt', 'd' * 101);
      write('promotional_text.txt', 'e' * 171);

      expect(appStoreListingProblems(temp), [
        '${temp.path}/name.txt has 31 characters, App Store Connect allows 30',
        '${temp.path}/subtitle.txt has 31 characters, App Store Connect allows 30',
        '${temp.path}/description.txt has 4001 characters, App Store Connect allows 4000',
        '${temp.path}/keywords.txt has 101 characters, App Store Connect allows 100',
        '${temp.path}/promotional_text.txt has 171 characters, App Store Connect allows 170',
      ]);
    });

    test('names a missing or empty text', () {
      write('name.txt', ' \n');

      expect(appStoreListingProblems(temp), [
        '${temp.path}/name.txt is empty',
        '${temp.path}/subtitle.txt is missing',
        '${temp.path}/description.txt is missing',
        '${temp.path}/keywords.txt is missing',
        '${temp.path}/promotional_text.txt is missing',
      ]);
    });

    test('does not count the final line break of a file', () {
      write('name.txt', '${'a' * 30}\n');
      write('subtitle.txt', '${'b' * 30}\r\n');
      write('description.txt', 'c');
      write('keywords.txt', 'd');
      write('promotional_text.txt', 'e');

      expect(appStoreListingProblems(temp), isEmpty);
    });
  });
}

const _metadataRoot = 'ios/fastlane/metadata';
const _locales = ['en-US', 'tr'];

/// The words that name the biometric lock, in either locale.
const _biometricWords = ['Face ID', 'Touch ID'];

/// What a line naming the lock must also say, per locale, so the reader learns it is theirs to turn on.
const _optInMarkers = {
  'en-US': ['Settings', 'optional'],
  'tr': ['Ayarlar', 'isteğe bağlı'],
};

/// App Store Connect's limit for each listing text, in characters.
const appStoreListingLimits = {
  'name.txt': 30,
  'subtitle.txt': 30,
  'description.txt': 4000,
  'keywords.txt': 100,
  'promotional_text.txt': 170,
};

/// The problems of the listing texts in [locale]: a text that is missing, empty, or longer than Connect allows.
List<String> appStoreListingProblems(Directory locale) => [
  for (final MapEntry(key: name, value: limit) in appStoreListingLimits.entries)
    ...?_textProblem('${locale.path}/$name', limit),
];

List<String>? _textProblem(String path, int limit) {
  final file = File(path);
  if (!file.existsSync()) return ['$path is missing'];
  final text = file.readAsStringSync().replaceFirst(RegExp(r'\r?\n$'), '');
  if (text.trim().isEmpty) return ['$path is empty'];
  final length = text.runes.length;
  if (length > limit) return ['$path has $length characters, App Store Connect allows $limit'];
  return null;
}

/// Every file under [locale], as a sorted list of paths relative to it.
List<String> _relativeFiles(Directory locale) {
  if (!locale.existsSync()) return const [];
  final prefix = '${locale.path.replaceAll('\\', '/')}/';
  return [
    for (final file in locale.listSync(recursive: true).whereType<File>())
      file.path.replaceAll('\\', '/').substring(prefix.length),
  ]..sort();
}

String _name(String path) => path.replaceAll('\\', '/').split('/').last;
