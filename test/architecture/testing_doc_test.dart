import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the counts `docs/testing-architecture.md` states against the tree it describes (issue #359).
///
/// That document is what a new contributor reads and what an evaluating agent is briefed from, and two of its claims
/// had drifted far enough to mislead: it said 60 goldens where there are 34, and it listed 16 of the 28 guards in
/// `test/architecture/`. Neither was wrong when it was written. Nothing told anyone when it stopped being right.
///
/// So the numbers are read from disk rather than trusted, on the shape `release_docs_test.dart` already uses for
/// `docs/release.md`: a claim about the tree is checked against the tree, and the pull request that changes one
/// updates the other in the same change.
void main() {
  final doc = File(_docPath).readAsStringSync();

  test('the document states how many golden images there are', () {
    final images = Directory('test')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.replaceAll(r'\', '/').contains('/goldens/ci/') && f.path.endsWith('.png'))
        .length;

    expect(images, greaterThan(0), reason: 'no golden image was found, so this guard reads nothing');
    expect(
      doc,
      contains('$images golden images'),
      reason:
          'There are $images golden images under test/**/goldens/ci/. $_docPath must say "$images golden images", '
          'so a reader judging how much visual coverage exists is not told a number that drifted.',
    );
  });

  test('the document states how many golden scenarios there are', () {
    final scenarios = Directory('test')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('_golden_test.dart'))
        .map((f) => 'GoldenTestScenario'.allMatches(f.readAsStringSync()).length)
        .fold(0, (a, b) => a + b);

    expect(scenarios, greaterThan(0), reason: 'no golden scenario was found, so this guard reads nothing');
    expect(doc, contains('$scenarios scenarios'), reason: 'There are $scenarios GoldenTestScenario uses.');
  });

  test('the document names every guard in test/architecture', () {
    final guards =
        Directory('test/architecture')
            .listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('_test.dart'))
            .map((f) => f.path.split(Platform.pathSeparator).last.replaceAll('.dart', ''))
            .toList()
          ..sort();
    final unnamed = [
      for (final guard in guards)
        if (!doc.contains(guard)) guard,
    ];

    expect(guards, isNotEmpty, reason: 'no guard was found, so this guard reads nothing');
    expect(
      unnamed,
      isEmpty,
      reason:
          'These guards are not named in $_docPath, so a contributor reading it does not know they will run:\n'
          '${unnamed.join('\n')}',
    );
  });

  test('the document does not claim the golden rasterisation is identical across hosts', () {
    // It is not. Measured on this repository: the component goldens deviate by 0.09-0.15% between a maintainer's
    // macOS machine and the Linux CI runner, symmetric and independent of the fonts. Believing the old sentence is
    // what sent #349 through two red CI rounds.
    expect(
      doc,
      isNot(contains('identical on')),
      reason:
          'The Ahem variant removes font flake; it does not make the rasterisation identical across hosts. Say that '
          'a baseline is produced on the runner that verifies it.',
    );
  });
}

const _docPath = 'docs/testing-architecture.md';
