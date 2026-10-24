import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the Play store listing texts in `android/fastlane/metadata/android/` (issue #197).
///
/// The texts sit in the fastlane metadata layout, so a later pipeline step can upload them: one directory per locale,
/// each with `title.txt`, `short_description.txt` and `full_description.txt`. Play refuses a listing whose title is
/// longer than 30 characters, whose short description is longer than 80 or whose full description is longer than
/// 4000, so this test fails before the Console would. Play counts characters, not bytes, so a Turkish `ş` counts as
/// one.
///
/// The English and the Turkish listing must hold the same files, so a text added to one locale is not forgotten in the
/// other.
void main() {
  test('each locale has the three listing texts within Play\'s lengths', () {
    final problems = [for (final locale in _locales) ...listingProblems(Directory('$_metadataRoot/$locale'))];

    expect(problems, isEmpty, reason: problems.join('\n'));
  });

  test('the listing has exactly the en-US and tr-TR locales, holding the same files', () {
    final root = Directory(_metadataRoot);
    expect(root.existsSync(), isTrue, reason: '$_metadataRoot does not exist');

    final locales = [for (final entry in root.listSync().whereType<Directory>()) _name(entry.path)]..sort();
    expect(locales, _locales);

    final english = relativeFiles(Directory('$_metadataRoot/en-US'));
    final turkish = relativeFiles(Directory('$_metadataRoot/tr-TR'));
    expect(english, isNotEmpty);
    expect(turkish, english, reason: 'en-US and tr-TR must hold the same files');
  });

  group('listingProblems', () {
    late Directory temp;

    setUp(() => temp = Directory.systemTemp.createTempSync('play_listing_'));
    tearDown(() => temp.deleteSync(recursive: true));

    void write(String name, String text) => File('${temp.path}/$name').writeAsStringSync(text);

    test('accepts texts at the limits, counting characters rather than bytes', () {
      write('title.txt', 'ş' * 30);
      write('short_description.txt', 'ğ' * 80);
      write('full_description.txt', 'ü' * 4000);

      expect(listingProblems(temp), isEmpty);
    });

    test('names a text one character past its limit', () {
      write('title.txt', 'a' * 31);
      write('short_description.txt', 'b' * 81);
      write('full_description.txt', 'c' * 4001);

      expect(listingProblems(temp), [
        '${temp.path}/title.txt has 31 characters, Play allows 30',
        '${temp.path}/short_description.txt has 81 characters, Play allows 80',
        '${temp.path}/full_description.txt has 4001 characters, Play allows 4000',
      ]);
    });

    test('names a missing or empty text', () {
      write('title.txt', ' \n');

      expect(listingProblems(temp), [
        '${temp.path}/title.txt is empty',
        '${temp.path}/short_description.txt is missing',
        '${temp.path}/full_description.txt is missing',
      ]);
    });

    test('does not count the final line break of a file', () {
      write('title.txt', '${'a' * 30}\n');
      write('short_description.txt', '${'b' * 80}\r\n');
      write('full_description.txt', 'c');

      expect(listingProblems(temp), isEmpty);
    });
  });
}

const _metadataRoot = 'android/fastlane/metadata/android';
const _locales = ['en-US', 'tr-TR'];

/// Play's limit for each listing text, in characters.
const listingLimits = {'title.txt': 30, 'short_description.txt': 80, 'full_description.txt': 4000};

/// The problems of the listing texts in [locale]: a text that is missing, empty, or longer than Play allows.
List<String> listingProblems(Directory locale) => [
  for (final MapEntry(key: name, value: limit) in listingLimits.entries)
    ...?_textProblem('${locale.path}/$name', limit),
];

List<String>? _textProblem(String path, int limit) {
  final file = File(path);
  if (!file.existsSync()) return ['$path is missing'];
  final text = file.readAsStringSync().replaceFirst(RegExp(r'\r?\n$'), '');
  if (text.trim().isEmpty) return ['$path is empty'];
  final length = text.runes.length;
  if (length > limit) return ['$path has $length characters, Play allows $limit'];
  return null;
}

/// Every file under [locale], as a sorted list of paths relative to it.
List<String> relativeFiles(Directory locale) {
  if (!locale.existsSync()) return const [];
  final prefix = '${locale.path.replaceAll('\\', '/')}/';
  return [
    for (final file in locale.listSync(recursive: true).whereType<File>())
      file.path.replaceAll('\\', '/').substring(prefix.length),
  ]..sort();
}

String _name(String path) => path.replaceAll('\\', '/').split('/').last;
