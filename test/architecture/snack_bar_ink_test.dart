import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Fails when a `SnackBar` in `lib/` gives itself a background without also giving itself the ink to go on it.
///
/// A snack bar's text colour comes from `snackBarTheme.contentTextStyle`, which `app_theme.dart` sets to
/// `onInverseSurface` — the ink for `inverseSurface`, the background the theme also supplies. Take the background
/// over and the ink stays behind, still coloured for a surface that is no longer there.
///
/// That went unnoticed for as long as it did because it used to be true by accident. `login_page.dart` paints its
/// sign-in confirmation with `colorScheme.primary`, and while `primary` was a near-black in the light scope and a
/// near-white in the dark one it was always the opposite of the page — which is exactly what `onInverseSurface`
/// is the ink for, so the pair read correctly in both. #283 made `primary` the product's indigo in both scopes,
/// the coincidence ended, and the dark scope's `#0B0D18` ink landed on indigo at **3.08:1**.
///
/// A source guard rather than a widget test because the rule is about what a call site must supply, and there is
/// no screen to pump for the next one — the next one does not exist yet.
void main() {
  test('a SnackBar that brings its own background brings its own ink', () {
    final offenders = <String>[];

    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final source = entity.readAsStringSync();

      for (final match in RegExp(r'\bSnackBar\(').allMatches(source)) {
        // The argument list of this SnackBar, up to the bracket that closes it.
        var depth = 0;
        var end = match.end - 1;
        for (var i = match.end - 1; i < source.length; i++) {
          if (source[i] == '(') depth++;
          if (source[i] == ')') {
            depth--;
            if (depth == 0) {
              end = i;
              break;
            }
          }
        }
        final arguments = source.substring(match.end, end);
        if (!arguments.contains('backgroundColor:')) continue;
        // `SnackBar` has no `contentTextStyle` of its own — that lives on the theme — so the ink is given to the
        // content widget, whose style merges with the theme's and moves only the colour.
        if (RegExp(r'style:\s*TextStyle\(\s*color:').hasMatch(arguments)) continue;

        final line = '\n'.allMatches(source.substring(0, match.start)).length + 1;
        offenders.add('${entity.path}:$line');
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'each of these takes the snack bar background from the theme but leaves the ink behind, so the text is '
          'still coloured for `inverseSurface`:\n${offenders.join('\n')}',
    );
  });
}
