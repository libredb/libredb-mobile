import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the one input that lets a release be tagged at all (#134).
///
/// The repository's `refs/tags/v*` ruleset blocks creating a matching tag, so that nothing but an organization admin
/// can reach the upload key by pushing a tag; the environments `release-signing` and `play-internal` therefore need no
/// required reviewer and a release runs end to end without a human. Only the bypass list of that ruleset gets past the
/// creation rule, and GitHub does not accept the GitHub Actions app as a bypass actor, so release-please has to tag as
/// the owner: with `token: ${{ secrets.RELEASE_PLEASE_TOKEN }}` it acts as an organization admin and bypasses, and
/// without it it falls back to `GITHUB_TOKEN` and every release stops with a refused tag.
///
/// Measured on 2026-10-30 against the live ruleset: a tag created with the release-please token succeeded, and the
/// test tag was deleted again.
void main() {
  test('release-please tags with the owner token, which the tag ruleset lets through', () {
    final problems = releasePleaseTokenProblems(_releasePleaseWorkflow());

    expect(problems, isEmpty, reason: problems.join('\n'));
  });

  test('a workflow that lost the token is named', () {
    final without = _releasePleaseWorkflow().replaceFirst(RegExp(r'^\s*token: .*$\n', multiLine: true), '');

    expect(releasePleaseTokenProblems(without), [
      'The release-please step has no token input, so it tags with GITHUB_TOKEN, which the refs/tags/v* '
          'creation rule refuses',
    ]);
  });

  test('a token that is not the release-please secret is named', () {
    final other = _releasePleaseWorkflow().replaceFirst('secrets.RELEASE_PLEASE_TOKEN', 'secrets.OTHER_TOKEN');

    expect(releasePleaseTokenProblems(other), [
      'The release-please step passes secrets.OTHER_TOKEN, not secrets.RELEASE_PLEASE_TOKEN',
    ]);
  });
}

/// Names what is missing from [workflow] for release-please to create a `v*` tag, or nothing when it can.
List<String> releasePleaseTokenProblems(String workflow) {
  final token = RegExp(r'^\s*token: \$\{\{ secrets\.([A-Z_]+) \}\}$', multiLine: true).firstMatch(workflow);
  if (token == null) {
    return [
      'The release-please step has no token input, so it tags with GITHUB_TOKEN, which the refs/tags/v* '
          'creation rule refuses',
    ];
  }
  final name = token.group(1);
  if (name != 'RELEASE_PLEASE_TOKEN') {
    return ['The release-please step passes secrets.$name, not secrets.RELEASE_PLEASE_TOKEN'];
  }
  return const [];
}

String _releasePleaseWorkflow() => File('.github/workflows/release-please.yml').readAsStringSync();
