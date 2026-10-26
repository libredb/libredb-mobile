import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the repository against the scratch files a coding agent writes beside it (issue #351).
///
/// The skills an agent runs keep working files in the checkout — a plan's ledger, a command's output, a page read once
/// and dumped to disk. None of it is the product, and none of it should be committed, but `git add` cannot tell the
/// difference: it stages whatever the working tree holds. `.superpowers/site-tokens.txt`, 371 lines of CSS variables
/// read off libredb.org, went in that way in 19c99d9 among 55 golden images and reached `main`.
///
/// Two halves, and the second is the one that lasts:
///
/// - Nothing inside a scratch directory is tracked. This catches a file already through the gate, which `.gitignore`
///   alone never would: ignore rules do not apply to a path git already follows.
/// - Every scratch directory is ignored, so the next `git add` cannot take one. A directory whose own `.gitignore`
///   excludes its contents counts as covered — that is how `.superpowers/sdd/` survived the commit that lost its
///   sibling.
///
/// Add a directory here when a skill starts writing to a new one. `git check-ignore --no-index` answers for a path
/// whether or not it exists, so an entry may be added before the directory is.
void main() {
  /// The directories the agent tooling in use writes into the checkout, each as a repository-relative path.
  const scratchDirectories = ['.superpowers/', '.team/', 'docs/superpowers/', '.claude/worktrees/'];

  group('an agent\'s scratch directory', () {
    test('holds no tracked file, because scratch work is not the product', () async {
      final tracked = <String>[];
      for (final directory in scratchDirectories) {
        final result = await Process.run('git', ['ls-files', '--', directory]);
        expect(result.exitCode, 0, reason: 'git ls-files failed for $directory: ${result.stderr}');
        tracked.addAll(const LineSplitter().convert(result.stdout as String).where((line) => line.isNotEmpty));
      }

      expect(
        tracked..sort(),
        isEmpty,
        reason:
            'These are an agent\'s working files, not the product. Untrack each with `git rm --cached <path>`, which '
            'leaves it on disk:\n${tracked.join('\n')}',
      );
    });

    test('is git-ignored, so the next `git add` cannot take anything written there', () async {
      final unguarded = <String>[];
      for (final directory in scratchDirectories) {
        final result = await Process.run('git', ['check-ignore', '--no-index', '--quiet', '${directory}a-file']);
        // 0 means ignored, 1 means not; anything else is git failing to answer, which is not a pass.
        expect(result.exitCode, anyOf(0, 1), reason: 'git check-ignore failed for $directory: ${result.stderr}');
        if (result.exitCode == 1) unguarded.add(directory);
      }

      expect(
        unguarded,
        isEmpty,
        reason:
            'A file written in these directories is stageable, so the next broad `git add` commits it. Add each to '
            '.gitignore:\n${unguarded.join('\n')}',
      );
    });
  });

  test('the guard reads a non-empty list, so it cannot pass by looking at nothing', () {
    expect(scratchDirectories, isNotEmpty);
    for (final directory in scratchDirectories) {
      expect(directory, endsWith('/'), reason: '$directory must name a directory, or it guards one file name');
    }
  });
}
