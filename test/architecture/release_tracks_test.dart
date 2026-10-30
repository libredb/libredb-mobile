import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards that a release reaches both Play tracks (#134).
///
/// The owner's ruling on 2026-10-31: a release goes to the internal testing track, so the testers have it at once,
/// and to the production track, where Google's review decides when the public gets it. Dropping either upload is
/// silent — the workflow stays green and only the missing audience notices — so the tracks are named here.
void main() {
  test('the release uploads to both the internal and the production track', () {
    final problems = releaseTrackProblems(_releaseWorkflow());

    expect(problems, isEmpty, reason: problems.join('\n'));
  });

  test('a workflow that lost the production upload is named', () {
    final without = _releaseWorkflow().replaceFirst(RegExp(r'^\s*track: production$\n', multiLine: true), '');

    expect(releaseTrackProblems(without), [
      'The release uploads to no production track, so no release reaches the public',
    ]);
  });

  test('a workflow that lost the internal upload is named', () {
    final without = _releaseWorkflow().replaceFirst(RegExp(r'^\s*track: internal$\n', multiLine: true), '');

    expect(releaseTrackProblems(without), ['The release uploads to no internal track, so the testers get nothing']);
  });
}

/// Names the Play tracks `workflow` fails to upload to, or nothing when it reaches both.
List<String> releaseTrackProblems(String workflow) => [
  if (!RegExp(r'^\s*track: internal$', multiLine: true).hasMatch(workflow))
    'The release uploads to no internal track, so the testers get nothing',
  if (!RegExp(r'^\s*track: production$', multiLine: true).hasMatch(workflow))
    'The release uploads to no production track, so no release reaches the public',
];

String _releaseWorkflow() => File('.github/workflows/release.yml').readAsStringSync();
