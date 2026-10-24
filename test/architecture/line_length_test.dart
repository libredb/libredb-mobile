import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the 120-column line width of the Dart files in `lib/` and `test/`.
///
/// `analysis_options.yaml` sets the formatter's page width to 120, and `dart format` keeps code within it, but it
/// never rewraps a comment and cannot split a long string literal, so such lines grew past the limit unnoticed. No
/// analyzer lint takes a width: `lines_longer_than_80_chars` is fixed at 80.
///
/// This meta-test reads every Dart file in `lib/` and `test/`, outside the generated `lib/generated/`, and fails on a
/// line longer than 120 characters, naming its file and line. Rewrap the comment, or split the string literal into
/// adjacent literals.
void main() {
  test('no Dart line in lib or test is longer than 120 columns', () {
    final files = [
      for (final root in ['lib', 'test'])
        for (final file in Directory(root).listSync(recursive: true).whereType<File>())
          if (file.path.endsWith('.dart') && !file.path.replaceAll('\\', '/').startsWith('lib/generated/')) file,
    ];
    final offenders = [for (final file in files) ...longLines(file.path.replaceAll('\\', '/'), file.readAsStringSync())]
      ..sort();

    expect(files, isNotEmpty, reason: 'no Dart file was found in lib or test, so the guard no longer reads any');
    expect(
      offenders,
      isEmpty,
      reason: 'These lines are longer than $maxColumns columns. Rewrap them:\n${offenders.join('\n')}',
    );
  });

  test('a line counts its characters, not its bytes, and only a line past the limit is named', () {
    final source = [
      'a' * maxColumns,
      'ü' * maxColumns,
      'b' * (maxColumns + 1),
      '// ${'→' * (maxColumns - 3)}',
    ].join('\n');

    expect(longLines('lib/example.dart', source), ['lib/example.dart:3 (121 columns)']);
  });
}

/// The width that `analysis_options.yaml` gives the formatter.
const maxColumns = 120;

/// Each line of [source], the text of the file at [path], longer than [maxColumns] characters, as `path:line`.
List<String> longLines(String path, String source) {
  final lines = source.split('\n');
  return [
    for (var i = 0; i < lines.length; i++)
      if (lines[i].replaceAll('\r', '').runes.length > maxColumns)
        '$path:${i + 1} (${lines[i].replaceAll('\r', '').runes.length} columns)',
  ];
}
