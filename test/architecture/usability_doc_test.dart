import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Holds `docs/usability-findings.md` to the tree it points at (the second child of #285).
///
/// That page defines the only block an M16 usage run may record a finding in, and its three load-bearing claims all
/// point outside itself: the guards whose classes make a finding a test gap rather than a usability finding, the rows
/// of `docs/design-system.md` a visual finding has to cite, and how many guards `test/architecture/` holds. Each of
/// the three fails quietly. A discard rule that names a guard which no longer exists discards nothing. A citation
/// that has slid two lines down the page sends a reviewer to the wrong sentence while still looking right, which is
/// the failure `design_system_doc_test.dart` was written for, one page further along the same chain. And a count read
/// from the issue rather than the tree is already wrong: #285 says 24 guards, written when there were.
///
/// So the page is read against disk instead of trusted, on the shape `testing_doc_test.dart` and
/// `release_docs_test.dart` already use — a claim about the tree is checked against the tree, and the pull request
/// that moves one updates the page in the same change.
void main() {
  test('every test path the page names exists', () {
    final page = _page();
    expect(
      RegExp(_testPathPattern).allMatches(page),
      isNotEmpty,
      reason: 'the page sends a finding to the guard that already measures its class; one that names none cannot',
    );

    final missing = missingTestPaths(page, (path) => File(path).existsSync());

    expect(missing, isEmpty, reason: 'paths that lead nowhere:\n${missing.join('\n')}');
  });

  test('every design-system citation resolves and still carries the sentence it quotes', () {
    final page = _page();
    expect(
      RegExp(_citationPattern).allMatches(page),
      isNotEmpty,
      reason: 'a visual finding cites $_designSystemPath by file:line; a page that shows no citation shows no shape',
    );

    final broken = brokenCitations(page, _designSystemLines());

    expect(broken, isEmpty, reason: 'citations that no longer say what they are quoted for:\n${broken.join('\n')}');
  });

  test('a citation of the real page moved one line up is named', () {
    final page = _page();
    expect(page, contains('`$_designSystemPath:272`'));

    final broken = brokenCitations(
      page.replaceFirst('`$_designSystemPath:272`', '`$_designSystemPath:271`'),
      _designSystemLines(),
    );

    expect(broken, hasLength(1));
    expect(broken.single, contains('$_designSystemPath:271'));
  });

  test('the page states how many guards test/architecture holds', () {
    final guards = Directory('test/architecture')
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('_test.dart'))
        .length;

    expect(guards, greaterThan(0), reason: 'no guard was found, so this guard reads nothing');
    expect(
      _page(),
      contains('$guards guards'),
      reason:
          'There are $guards files in test/architecture/ whose name ends in _test.dart. $_pagePath must say '
          '"$guards guards", so a run deciding whether its finding is a test gap is told the size of the set it has '
          'to look through.',
    );
  });

  group('missingTestPaths', () {
    bool exists(String path) => path == 'test/architecture/line_length_test.dart';

    test('names a path that is not a file', () {
      const markdown = '''
| class | guard |
|---|---|
| a long line | `test/architecture/line_length_test.dart` |
| a long word | `test/architecture/line_width_test.dart` |
''';

      expect(missingTestPaths(markdown, exists), ['`test/architecture/line_width_test.dart` — no such file']);
    });

    test('names a path once however often the page writes it', () {
      const markdown = '`test/architecture/gone_test.dart` and again `test/architecture/gone_test.dart`';

      expect(missingTestPaths(markdown, exists), hasLength(1));
    });

    test('reads only a path in backticks, and only one under test/', () {
      const markdown = '''
`lib/app/router/app_routes_constants.dart` is not read, nor is test/architecture/bare_test.dart without backticks.
`test/architecture/line_length_test.dart` is.
''';

      expect(missingTestPaths(markdown, exists), isEmpty);
    });
  });

  group('brokenCitations', () {
    const lines = ['# A page', '', 'The first claim, which wraps', 'onto a second line.', '', 'A later claim.'];

    test('accepts a quote the cited paragraph carries, across the wrap', () {
      const markdown = '`$_designSystemPath:3` — "The first claim, which wraps onto a second line."';

      expect(brokenCitations(markdown, lines), isEmpty);
    });

    test('names a citation past the end of the page', () {
      const markdown = '`$_designSystemPath:9` — "A later claim."';

      expect(brokenCitations(markdown, lines), ['`$_designSystemPath:9` — the page has only 6 lines']);
    });

    test('names a quote the cited paragraph does not carry', () {
      const markdown = '`$_designSystemPath:6` — "The first claim"';

      expect(brokenCitations(markdown, lines), [
        '`$_designSystemPath:6` — the paragraph there no longer says "The first claim"',
      ]);
    });

    test('names a quote that starts in an earlier line of the same paragraph', () {
      const markdown = '`$_designSystemPath:4` — "The first claim, which wraps"';

      expect(brokenCitations(markdown, lines), [
        '`$_designSystemPath:4` — the paragraph there no longer says "The first claim, which wraps"',
      ]);
    });
  });
}

const _pagePath = 'docs/usability-findings.md';
const _designSystemPath = 'docs/design-system.md';

/// A path under `test/` to a Dart file, as the page writes one inside backticks.
const _testPathPattern = r'`(test/[\w/]+\.dart)`';

/// A citation of [_designSystemPath], as the page writes one: the line in backticks, an em dash, then the quote.
const _citationPattern =
    '`$_designSystemPath:'
    r'(\d+)` — "([^"]+)"';

String _page() => File(_pagePath).readAsStringSync();

List<String> _designSystemLines() => File(_designSystemPath).readAsLinesSync();

/// The `test/` paths [markdown] names in backticks for which [exists] answers false, each named once.
List<String> missingTestPaths(String markdown, bool Function(String path) exists) {
  final named = {for (final match in RegExp(_testPathPattern).allMatches(markdown)) match.group(1)!};
  return [
    for (final path in named.toList()..sort())
      if (!exists(path)) '`$path` — no such file',
  ];
}

/// The problems of the `docs/design-system.md:NNN` citations in [markdown], read against [lines], that page's lines.
///
/// A citation holds when the paragraph **starting** at the cited line carries the quoted sentence. The paragraph
/// rather than the line, because that page wraps at 120 columns and a sentence of it often spans two; starting at it
/// rather than containing it, because a citation that points into the middle of a paragraph points at the wrong line
/// even while the words it quotes are somewhere nearby.
List<String> brokenCitations(String markdown, List<String> lines) {
  String collapse(String text) => text.replaceAll(RegExp(r'\s+'), ' ').trim();

  final broken = <String>[];
  for (final citation in RegExp(_citationPattern).allMatches(markdown)) {
    final number = int.parse(citation.group(1)!);
    final quote = citation.group(2)!;
    final cited = '`$_designSystemPath:$number`';
    if (number < 1 || number > lines.length) {
      broken.add('$cited — the page has only ${lines.length} lines');
      continue;
    }
    final paragraph = <String>[];
    for (var index = number - 1; index < lines.length && lines[index].trim().isNotEmpty; index++) {
      paragraph.add(lines[index]);
    }
    if (!collapse(paragraph.join(' ')).contains(collapse(quote))) {
      broken.add('$cited — the paragraph there no longer says "$quote"');
    }
  }
  return broken;
}
