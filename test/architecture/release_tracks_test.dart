import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards that a release reaches both Play tracks in one upload (#134, #137).
///
/// The owner's ruling on 2026-10-31: a release goes to the internal testing track, so the testers have it at once,
/// and to the production track, where Google's review decides when the public gets it.
///
/// It has to be **one** upload. The first attempt uploaded the same bundle twice, once per track, and v1.1.2 failed
/// with `Version code 7 has already been used.`: the first upload consumes the version code, so the second can never
/// succeed. The action takes a comma-separated `tracks` input that assigns one upload to several tracks, which is
/// what `track` deprecates ("'track' is deprecated and will be removed in a future release. Please migrate to
/// 'tracks'", measured in the v1.1.2 log).
void main() {
  test('the release assigns one upload to both tracks', () {
    final problems = releaseTrackProblems(_releaseWorkflow());

    expect(problems, isEmpty, reason: problems.join('\n'));
  });

  test('a second upload step is named', () {
    final twice = '${_releaseWorkflow()}\n        uses: r0adkll/upload-google-play@v1\n';

    expect(releaseTrackProblems(twice), [
      'The release runs 2 Play uploads; a second upload of the same bundle fails with "Version code has already '
          'been used"',
    ]);
  });

  test('a workflow that lost a track is named', () {
    final one = _releaseWorkflow().replaceFirst('tracks: internal,production', 'tracks: internal');

    expect(releaseTrackProblems(one), ['The release uploads to no production track, so no release reaches the public']);
  });
}

/// Names what stops [workflow] from putting one upload on both Play tracks, or nothing when it does.
List<String> releaseTrackProblems(String workflow) {
  final uploads = RegExp(r'uses: r0adkll/upload-google-play@').allMatches(workflow).length;
  if (uploads != 1) {
    return [
      'The release runs $uploads Play uploads; a second upload of the same bundle fails with "Version code has '
          'already been used"',
    ];
  }
  final tracks = RegExp(r'^\s*tracks: (.+)$', multiLine: true).firstMatch(workflow)?.group(1)?.split(',') ?? const [];
  return [
    if (!tracks.contains('internal')) 'The release uploads to no internal track, so the testers get nothing',
    if (!tracks.contains('production')) 'The release uploads to no production track, so no release reaches the public',
  ];
}

String _releaseWorkflow() => File('.github/workflows/release.yml').readAsStringSync();
