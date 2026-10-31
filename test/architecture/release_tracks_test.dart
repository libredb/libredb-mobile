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
///
/// The same upload also has to stage the production release. It used to send `completed`, so every release reached
/// all of production the moment Google's review passed, with no percentage at which a crash spike could stop it. It
/// now sends `inProgress` with a `userFraction`, both read from repository variables with a default, and the action
/// sends one status and one fraction to every track it was given, so the fraction may go out only while the status
/// is `inProgress`: `validateStatus` in the action's `input-validation.ts` refuses a `completed` or `draft` release
/// that carries a fraction, and an `inProgress` one that carries none.
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

  test('the production release is staged behind a user fraction', () {
    final problems = releaseRolloutProblems(_releaseWorkflow());

    expect(problems, isEmpty, reason: problems.join('\n'));
  });

  test('an upload that names no user fraction is named', () {
    final unstaged = _releaseWorkflow().replaceFirst(RegExp(r'^ *userFraction: .*\n', multiLine: true), '');

    expect(releaseRolloutProblems(unstaged), [
      'The Play upload names no userFraction, so the production release reaches every user the moment the review '
          'passes',
    ]);
  });

  test('an upload that finishes the release by default is named', () {
    final completed = _releaseWorkflow().replaceFirst(
      "PLAY_RELEASE_STATUS || 'inProgress'",
      "PLAY_RELEASE_STATUS || 'completed'",
    );

    expect(releaseRolloutProblems(completed), [
      "The release defaults to the Play status 'completed', so a release is not staged unless someone sets a "
          'variable first',
    ]);
  });

  test('a stage that holds nobody back is named', () {
    final whole = _releaseWorkflow().replaceFirst("PLAY_ROLLOUT_FRACTION || '0.2'", "PLAY_ROLLOUT_FRACTION || '1'");

    expect(releaseRolloutProblems(whole), [
      'The release stages at 1, which the action refuses: a fraction is between 0 and 1, exclusive on both ends',
    ]);
  });

  test('a fraction the status does not gate is named', () {
    final loose = _releaseWorkflow().replaceFirst(
      RegExp(r'^ *userFraction: .*\n', multiLine: true),
      r"          userFraction: ${{ vars.PLAY_ROLLOUT_FRACTION || '0.2' }}"
      '\n',
    );

    expect(releaseRolloutProblems(loose), [
      'The Play upload sends a userFraction whatever the status, and the action refuses a completed or draft '
          'release that carries one',
    ]);
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

/// Names what stops [workflow] from staging the production release behind a user fraction, or nothing when it does.
///
/// `r0adkll/upload-google-play` sends one `status` and one `userFraction` to every track of the upload, and it refuses
/// a `completed` or `draft` release that carries a fraction as well as an `inProgress` one that carries none
/// (`validateStatus` in the action's `input-validation.ts`), so the fraction the workflow sends has to be tied to the
/// status it sends.
List<String> releaseRolloutProblems(String workflow) {
  final status = _uploadInput(workflow, 'status');
  if (status == null) return ['The Play upload names no status'];
  final fraction = _uploadInput(workflow, 'userFraction');
  if (fraction == null) {
    return [
      'The Play upload names no userFraction, so the production release reaches every user the moment the review '
          'passes',
    ];
  }

  final statusDefault = RegExp("PLAY_RELEASE_STATUS \\|\\| '([^']*)'").firstMatch(workflow)?.group(1);
  final fractionDefault = RegExp("PLAY_ROLLOUT_FRACTION \\|\\| '([^']*)'").firstMatch(workflow)?.group(1);
  final parsed = double.tryParse(fractionDefault ?? '');
  return [
    if (statusDefault != 'inProgress')
      "The release defaults to the Play status '${statusDefault ?? 'completed'}', so a release is not staged "
          'unless someone sets a variable first',
    if (fractionDefault == null)
      'The release reads no PLAY_ROLLOUT_FRACTION default, so the stage cannot be moved without a commit',
    if (parsed != null && (parsed <= 0 || parsed >= 1))
      'The release stages at $fractionDefault, which the action refuses: a fraction is between 0 and 1, exclusive '
          'on both ends',
    if (!fraction.contains("'inProgress'"))
      'The Play upload sends a userFraction whatever the status, and the action refuses a completed or draft '
          'release that carries one',
  ];
}

/// The value the Play upload gives the input [name], or null when it names none.
String? _uploadInput(String workflow, String name) =>
    RegExp('^ *$name: (.+)\$', multiLine: true).firstMatch(workflow)?.group(1)?.trim();
