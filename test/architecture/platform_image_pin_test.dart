import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the LibreDB Platform release that the `platform` profile of `tool/studio-dev` runs, the stack every
/// recorded answer under `test/fixtures/platform/` comes from.
///
/// A recorded answer only means something when the reader can tell which Platform served it, so the release is named
/// in four places: the two `PLATFORM_IMAGE` defaults of `tool/studio-dev/docker-compose.yml`, the comment above them
/// that introduces the profile, and the `## Platform` section of `docs/studio.md`. Moving the stack to a new release
/// means changing all four together; a bump that misses one leaves the doc describing a Platform that no longer
/// serves the fixtures, and leaves the two services running different images in the same stack.
///
/// The guard deliberately stops at `tool/studio-dev`. The image tables of `## Platform installer environment` and of
/// `docs/platform.md` record what a dated full-system check ran, not what the recording stack pins today, so they
/// are free to name an older release and are not read here.
void main() {
  const composePath = 'tool/studio-dev/docker-compose.yml';
  const studioDocPath = 'docs/studio.md';

  /// `${PLATFORM_IMAGE:-ghcr.io/libredb/libredb-platform:<version>@sha256:<digest>}`
  final pinPattern = RegExp(
    r'\$\{PLATFORM_IMAGE:-ghcr\.io/libredb/libredb-platform:([^@\s}]+)@sha256:([0-9a-f]{64})\}',
  );

  group('studio-dev Platform image pin', () {
    late String compose;
    late String studioDoc;
    late List<RegExpMatch> pins;

    setUp(() {
      compose = File(composePath).readAsStringSync();
      studioDoc = File(studioDocPath).readAsStringSync();
      pins = pinPattern.allMatches(compose).toList();
    });

    test('both Platform services pin one release by tag and digest', () {
      expect(
        pins.length,
        2,
        reason:
            '$composePath must default PLATFORM_IMAGE for platform-migrate and libredb-platform, each as '
            'ghcr.io/libredb/libredb-platform:<version>@sha256:<64 hex digits>',
      );
      expect(
        pins.map((m) => m.group(0)).toSet(),
        hasLength(1),
        reason:
            'platform-migrate and libredb-platform must run the same image: migrations applied by one release '
            'and served by another is not a stack any answer can be recorded from',
      );
    });

    test('the profile comment names the pinned version', () {
      final version = pins.first.group(1)!;
      final comment = _composeProfileComment(compose);

      expect(
        comment,
        contains('LibreDB Platform $version'),
        reason: 'the comment introducing the platform profile in $composePath must name the pinned version $version',
      );
      expect(
        comment,
        contains('libredb-platform v$version'),
        reason:
            'the comment must name the release tag v$version that '
            'tool/studio-dev/platform/postgres/ was copied from',
      );
    });

    test('the Platform section of docs/studio.md names the pinned release', () {
      final version = pins.first.group(1)!;
      final section = _docSection(studioDoc, '## Platform');

      expect(
        section,
        contains('LibreDB Platform $version'),
        reason: '$studioDocPath "## Platform" must name the pinned version $version',
      );
      expect(
        section,
        contains('`ghcr.io/libredb/libredb-platform:$version`'),
        reason: '$studioDocPath "## Platform" must name the pinned image ghcr.io/libredb/libredb-platform:$version',
      );
      expect(
        section,
        contains('libredb-platform `v$version`'),
        reason: '$studioDocPath "## Platform" must name the release tag v$version the bootstrap copies come from',
      );
    });

    test('the Platform section of docs/studio.md names no other release', () {
      final version = pins.first.group(1)!;
      final section = _docSection(studioDoc, '## Platform');
      final tagged = RegExp(r'ghcr\.io/libredb/libredb-platform:([^\s`@]+)')
          .allMatches(section)
          .map((m) => m.group(1)!)
          .toSet();

      expect(
        tagged,
        {version},
        reason:
            '$studioDocPath "## Platform" still names a Platform image other than the pinned $version; a bump '
            'has to carry every mention of the old release with it',
      );
    });
  });
}

/// The comment block that introduces the `platform` profile: from the line opening it down to the first service key.
String _composeProfileComment(String compose) {
  final lines = const LineSplitter().convert(compose);
  final start = lines.indexWhere((line) => line.contains('The platform profile (--profile platform)'));
  expect(start, isNot(-1), reason: 'the platform profile comment of tool/studio-dev/docker-compose.yml is gone');

  final end = lines.indexWhere((line) => !line.trimLeft().startsWith('#'), start);
  return lines.sublist(start, end == -1 ? lines.length : end).join('\n');
}

/// The body of one `##` section of a Markdown document, matched on the whole heading line so that `## Platform`
/// never swallows `## Platform installer environment`.
String _docSection(String document, String heading) {
  final lines = const LineSplitter().convert(document);
  final start = lines.indexOf(heading);
  expect(start, isNot(-1), reason: 'the section "$heading" is gone');

  final end = lines.indexWhere((line) => line.startsWith('## '), start + 1);
  return lines.sublist(start + 1, end == -1 ? lines.length : end).join('\n');
}
