import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the button and screen labels that the Play App access instructions in `docs/release.md` quote (issue #300).
///
/// Also guards two things a reviewer meets before any label: Play limits the entry's "Any other information required to
/// access your app" field to 500 characters, measured in the console on 2026-10-29 against a block this page then held
/// at 724, and a build that carries the six-screen introduction (#66) opens on it rather than on the login page, so a
/// block that does not say how to leave the introduction sends the reviewer at a button they cannot reach.
/// A reviewer follows those instructions word by word, so every double-quoted string inside a `text` code block of the
/// "App access" section must be a value of `lib/l10n/intl_en.arb`. A pull request that renames a quoted label, such as
/// the login page copy of M15, then fails here until it updates `docs/release.md` in the same change.
void main() {
  test('every App access text block fits the 500 characters Play gives the field', () {
    final long = appAccessBlocksOverLimit(_releaseDoc());

    expect(long, isEmpty, reason: long.join('\n'));
  });

  test('a block one character over the limit is named', () {
    final problems = appAccessBlocksOverLimit('### App access\n\n```text\n${'a' * 501}\n```\n');

    expect(problems, ['Text block 1 of the App access instructions is 501 characters, over the 500 Play allows']);
  });

  test('every App access text block says how to leave the introduction', () {
    final problems = appAccessIntroductionProblems(_releaseDoc());

    expect(problems, isEmpty, reason: problems.join('\n'));
  });

  test('every label quoted in the App access instructions is a value of intl_en.arb', () {
    final problems = appAccessLabelProblems(_releaseDoc(), _englishArb());

    expect(problems, isEmpty, reason: problems.join('\n'));
  });

  test('a quoted label in the real App access instructions changed by one character is named', () {
    final doc = _releaseDoc();
    expect(doc, contains('"Sign in with SSO"'));

    final problems = appAccessLabelProblems(
      doc.replaceFirst('"Sign in with SSO"', '"Sign in with SS0"'),
      _englishArb(),
    );

    expect(problems, ['"Sign in with SS0" in the App access instructions is not a value of $_arbPath']);
  });

  group('appAccessLabelProblems', () {
    const arb = {
      'login_sso_button': 'Sign in with SSO',
      '@login_sso_button': <String, Object?>{},
      'browse_view_rows': 'View rows',
    };

    test('names a made-up label', () {
      const markdown = '''
### App access

```text
1. Open the app and tap "Sign in with Magic".
2. Tap "View rows".
```
''';

      expect(appAccessLabelProblems(markdown, arb), [
        '"Sign in with Magic" in the App access instructions is not a value of $_arbPath',
      ]);
    });

    test('accepts instructions whose quoted strings are all ARB values', () {
      const markdown = '''
### App access

Quoted text outside a code block, such as "All or some functionality is restricted", is not checked.

```text
1. Tap "Sign in with SSO".
2. Open a table and tap "View rows".
```

```text
1. Tap "Sign in with SSO".
```
''';

      expect(appAccessLabelProblems(markdown, arb), isEmpty);
    });

    test('checks only the App access section', () {
      const markdown = '''
### Content rating

```text
"Not a label"
```

### App access

```text
Tap "Sign in with Magic".
```

## Actions

```text
"Also not a label"
```
''';

      expect(appAccessLabelProblems(markdown, arb), [
        '"Sign in with Magic" in the App access instructions is not a value of $_arbPath',
      ]);
    });

    test('names a missing App access section or one without a text block', () {
      expect(appAccessLabelProblems('### Data safety\n', arb), ['The App access section is missing']);
      expect(appAccessLabelProblems('### App access\n\nNo block.\n', arb), [
        'The App access section has no text code block',
      ]);
    });
  });
}

const _releasePath = 'docs/release.md';
const _arbPath = 'lib/l10n/intl_en.arb';

String _releaseDoc() => File(_releasePath).readAsStringSync();

Map<String, Object?> _englishArb() => (jsonDecode(File(_arbPath).readAsStringSync()) as Map).cast<String, Object?>();

/// The problems of the App access instructions in [markdown]: every double-quoted string inside a `text` code block of
/// its "App access" section that is not a value of [arb], and a missing section or text block.
List<String> appAccessLabelProblems(String markdown, Map<String, Object?> arb) {
  final section = _appAccessSection(markdown);
  if (section == null) return ['The App access section is missing'];

  final blocks = RegExp(r'^```text\n(.*?)^```', multiLine: true, dotAll: true).allMatches(section).toList();
  if (blocks.isEmpty) return ['The App access section has no text code block'];

  final values = {
    for (final MapEntry(:key, :value) in arb.entries)
      if (!key.startsWith('@') && value is String) value,
  };
  return [
    for (final block in blocks)
      for (final quoted in RegExp('"([^"\n]*)"').allMatches(block.group(1)!))
        if (!values.contains(quoted.group(1)))
          '"${quoted.group(1)}" in the App access instructions is not a value of $_arbPath',
  ];
}

/// The text of the "App access" section, up to the next heading of level two or three, or null when it is missing.
String? _appAccessSection(String markdown) {
  final start = RegExp(r'^### App access\s*$', multiLine: true).firstMatch(markdown);
  if (start == null) return null;
  final rest = markdown.substring(start.end);
  final end = RegExp(r'^#{2,3} ', multiLine: true).firstMatch(rest);
  return end == null ? rest : rest.substring(0, end.start);
}

/// The App access text blocks of [markdown] that are longer than the 500 characters Play allows in the entry's
/// "Any other information required to access your app" field.
List<String> appAccessBlocksOverLimit(String markdown) {
  const limit = 500;
  return [
    for (final (index, block) in _appAccessBlocks(markdown).indexed)
      if (block.length > limit)
        'Text block ${index + 1} of the App access instructions is ${block.length} characters, over the $limit Play '
            'allows',
  ];
}

/// The App access text blocks of [markdown] that do not say how to leave the six-screen introduction (#66), which a
/// build carrying it opens on before the login page.
List<String> appAccessIntroductionProblems(String markdown) {
  return [
    for (final (index, block) in _appAccessBlocks(markdown).indexed)
      if (!block.contains('Skip'))
        'Text block ${index + 1} of the App access instructions does not say how to leave the introduction',
  ];
}

/// The contents of every `text` code block of the "App access" section of [markdown], trailing newline removed.
List<String> _appAccessBlocks(String markdown) {
  final section = _appAccessSection(markdown);
  if (section == null) return const [];
  return [
    for (final block in RegExp(r'^```text\n(.*?)^```', multiLine: true, dotAll: true).allMatches(section))
      block.group(1)!.trimRight(),
  ];
}
