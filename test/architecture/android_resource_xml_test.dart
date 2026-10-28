import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Fails when a comment in an Android resource file holds a double hyphen.
///
/// AAPT parses `android/app/src/main/res/**.xml` with a strict parser, and **a double hyphen is not permitted
/// inside an XML comment**. Writing `--background` in one — the name of a design token, which this repository
/// writes that way everywhere else — took the Android build down with a stack trace about `ErrorHandlerWrapper`
/// and a message about "the string" that names no token and suggests no fix (#390).
///
/// The Android build is the only other thing that catches this, and it is the slowest check in CI: it fails after
/// seven minutes, in a job a Dart author has no reason to be reading. This reads the files in milliseconds and
/// names the rule as well as the line, because whoever hits it is writing about a design token and not thinking
/// about XML at all.
void main() {
  test('no comment in an Android resource file holds a double hyphen', () {
    final resources = Directory('android/app/src/main/res');
    expect(resources.existsSync(), isTrue, reason: 'no res directory to check');

    final offenders = <String>[];
    for (final file in resources.listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.xml')) continue;
      final source = file.readAsStringSync();
      for (final comment in RegExp(r'<!--(.*?)-->', dotAll: true).allMatches(source)) {
        if (!comment.group(1)!.contains('--')) continue;
        final line = '\n'.allMatches(source.substring(0, comment.start)).length + 1;
        offenders.add('${file.path}:$line');
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'AAPT refuses the whole file over this. Write the token name out instead of quoting it as a CSS custom '
          'property:\n${offenders.join('\n')}',
    );
  });
}
