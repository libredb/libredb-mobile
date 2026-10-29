import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../support/dart_code.dart';

/// Fails when a file in `lib/` names `BouncingScrollPhysics`.
///
/// `AppScrollBehavior` on `MaterialApp.scrollBehavior` answers clamping physics for every scrollable in the app, so
/// the app says, app-wide, that a pull past an end does not stretch. A scrollable handed bouncing physics of its own
/// overrides that for its own screen and nothing else — the claim stops being true on one screen, which is the kind
/// of thing no golden and no release build reports, because only a finger on a device sees it.
///
/// A source guard rather than a widget test because the offending screen does not exist yet: there is nothing to pump.
void main() {
  test('no scrollable in lib/ gives itself bouncing physics', () {
    final offenders = <String>[];

    for (final file in Directory('lib').listSync(recursive: true).whereType<File>()) {
      final path = file.path.replaceAll(r'\', '/');
      if (!path.endsWith('.dart')) continue;
      final code = codeOnly(file.readAsStringSync());
      for (final match in RegExp(r'\bBouncingScrollPhysics\b').allMatches(code)) {
        offenders.add('$path:${'\n'.allMatches(code.substring(0, match.start)).length + 1}');
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'each of these reinstates the elastic overscroll on its own screen while the app claims not to have it:\n'
          '${offenders.join('\n')}',
    );
  });
}
