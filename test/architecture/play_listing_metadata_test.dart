import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the Play store listing texts in `android/fastlane/metadata/android/` (issue #197).
///
/// The texts sit in the fastlane metadata layout, so a later pipeline step can upload them: one directory per locale,
/// each with `title.txt`, `short_description.txt` and `full_description.txt`, and the phone screenshots under
/// `images/phoneScreenshots/` (`docs/release.md`). The file-set checks cover every file; only the text checks read
/// one, because a PNG is not UTF-8. Play refuses a listing whose title is
/// longer than 30 characters, whose short description is longer than 80 or whose full description is longer than
/// 4000, so this test fails before the Console would. Play counts characters, not bytes, so a Turkish `ş` counts as
/// one.
///
/// The English and the Turkish listing must hold the same files, so a text added to one locale is not forgotten in the
/// other.
///
/// The listing for an upcoming feature is drafted under `android/fastlane/drafts/<feature>/`, in the same layout, until
/// the pull request that ships the feature moves it into the live listing (issue #301). Each draft passes the same
/// checks and holds the same texts as the live `en-US`, so it can replace the live directories whole. Its screenshots
/// are its own, because a draft shows the feature's own pages rather than the live ones (issue #309, the Platform mode
/// draft); `test/architecture/play_screenshot_drafts_test.dart` guards those against Play's graphic requirements. No
/// listing text, live or draft, holds an en dash or an em dash.
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

  test('each draft has exactly the en-US and tr-TR locales, within Play\'s lengths and with the live texts', () {
    final root = Directory(_draftsRoot);
    expect(root.existsSync(), isTrue, reason: '$_draftsRoot does not exist');

    final live = _textFiles(Directory('$_metadataRoot/en-US'));
    final drafts = root.listSync().whereType<Directory>().toList();
    expect(drafts, isNotEmpty, reason: '$_draftsRoot holds no draft');

    final problems = <String>[];
    for (final draft in drafts) {
      final locales = [for (final entry in draft.listSync().whereType<Directory>()) _name(entry.path)]..sort();
      if (!_listEquals(locales, _locales)) problems.add('${draft.path} has the locales $locales, expected $_locales');
      for (final locale in _locales) {
        final directory = Directory('${draft.path}/$locale');
        problems.addAll(listingProblems(directory));
        final texts = _textFiles(directory);
        if (!_listEquals(texts, live)) {
          problems.add('${directory.path} holds the texts $texts, the live en-US holds $live');
        }
      }
    }

    expect(problems, isEmpty, reason: problems.join('\n'));
  });

  test('no listing text, live or draft, holds an en dash or an em dash', () {
    // `.txt` only: the listing also holds the phone screenshots, and reading a PNG as UTF-8 throws rather than
    // failing with a reason anyone can act on.
    final offending = [
      for (final root in [_metadataRoot, _draftsRoot])
        for (final file in Directory(root).listSync(recursive: true).whereType<File>())
          if (file.path.endsWith('.txt') && file.readAsStringSync().contains(RegExp('[\u2013\u2014]'))) file.path,
    ];

    expect(offending, isEmpty, reason: 'U+2013 or U+2014 in ${offending.join(', ')}');
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
const _draftsRoot = 'android/fastlane/drafts';
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

/// The listing texts under [locale], as a sorted list of paths relative to it, leaving the `images/` tree out.
///
/// A draft holds the same texts as the live listing, so it can replace a live locale directory whole, but it holds its
/// own screenshots: the Platform mode draft shows the Platform pages, not the live Studio ones.
/// `test/architecture/play_screenshot_drafts_test.dart` guards the screenshots themselves.
List<String> _textFiles(Directory locale) => [
  for (final path in relativeFiles(locale))
    if (!path.startsWith('images/')) path,
];

bool _listEquals(List<String> a, List<String> b) => a.length == b.length && a.indexed.every((e) => e.$2 == b[e.$1]);

String _name(String path) => path.replaceAll('\\', '/').split('/').last;
