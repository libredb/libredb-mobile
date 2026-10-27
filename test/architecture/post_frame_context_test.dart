import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../support/dart_code.dart';

/// Guards that a callback which outlives its frame checks it still has a widget before it reads one.
///
/// `addPostFrameCallback` runs at the end of a frame, which the widget that registered it may no longer be part of,
/// and reading a provider or an inherited widget from a `State` that is gone throws.
///
/// Eight of this repository's nine call sites were already right: five check `mounted`, and three touch no
/// `BuildContext` at all — two cleanups inside `dispose`, where `mounted` is false by definition, and a
/// `NavigatorObserver`, which has no `mounted` to check. The ninth was the login page's automatic redirect. It
/// carried `if (!mounted) return;` until #379 moved its four conditions out into `autoRedirectTarget` and left the
/// guard behind with the code it used to protect.
///
/// Every one of the 420 tests of `test/features/auth/` stayed green, and no widget test could have caught it:
/// `setState` defers an unmount to the next frame, so a test cannot take a page out of the tree inside the frame its
/// own callback runs in. Reading the source is what catches this class of loss, which is why it is a guard and not a
/// behaviour test.
///
/// The check follows one level of indirection, because that is the shape the login page used — `(_) => _method()`,
/// with the guard at the top of `_method`. A callback that reaches a `BuildContext` through two hops is not caught,
/// and a callback that mentions `mounted` anywhere counts as guarded; both are the usual limits of a source guard.
void main() {
  /// Where a `BuildContext` is read after a frame. The whole of `lib/` — a post-frame callback is not a UI-only
  /// shape, and a guard that skipped a directory would be a guard with a hole in it.
  const root = 'lib/';

  /// Every Dart file under [root] as code, with its comments and strings replaced by spaces: `mounted` named in a
  /// comment is not a check, and `'context'` in a log message is not a read.
  Map<String, String> sources() {
    final files = <String, String>{};
    for (final file in Directory(root).listSync(recursive: true).whereType<File>()) {
      final path = file.path.replaceAll(r'\', '/');
      if (path.endsWith('.dart')) files[path] = codeOnly(file.readAsStringSync());
    }
    return files;
  }

  /// The body of the method [name] declares in [code], or the empty string when it declares none.
  String bodyOf(String code, String name) {
    final declaration = RegExp('[A-Za-z_>?\\]]\\s+$name\\s*\\([^;{]*\\)\\s*(?:async\\s*\\*?\\s*)?\\{').firstMatch(code);
    if (declaration == null) return '';
    return code.substring(declaration.end, closingBracket(code, declaration.end));
  }

  /// What the callback registered at [start] in [code] effectively runs: the callback itself, plus the body of a
  /// method it is a bare call to. `(_) => _redirectAutomatically()` reads no context of its own; the method it names
  /// reads four.
  String effectiveBody(String code, int start) {
    final callback = code.substring(start, closingBracket(code, start));
    final forwarded = RegExp(r'^\s*\(\s*_?\s*\)\s*(?:async\s*)?=>\s*([A-Za-z_][A-Za-z0-9_]*)\s*\(')
        .firstMatch(callback);
    return forwarded == null ? callback : '$callback\n${bodyOf(code, forwarded.group(1)!)}';
  }

  test('a post-frame callback checks mounted before it reads a BuildContext', () {
    final unguarded = <String>[];
    sources().forEach((path, code) {
      for (final call in RegExp(r'\baddPostFrameCallback\s*\(').allMatches(code)) {
        final body = effectiveBody(code, call.end);
        if (!RegExp(r'\bcontext\b').hasMatch(body)) continue;
        if (RegExp(r'\bmounted\b').hasMatch(body)) continue;
        final line = code.substring(0, call.start).split('\n').length;
        unguarded.add('$path:$line');
      }
    });

    expect(
      unguarded,
      isEmpty,
      reason:
          'a callback that runs after the frame may have no widget left to read from; check mounted first\n'
          '${unguarded.join('\n')}',
    );
  });

  test('the guard is looking at the call sites that exist', () {
    final sites = sources().values.fold(
      0,
      (total, code) => total + RegExp(r'\baddPostFrameCallback\s*\(').allMatches(code).length,
    );

    expect(
      sites,
      greaterThanOrEqualTo(9),
      reason:
          'the first test passes trivially if it finds nothing; 9 call sites existed when it was written, and a '
          'count below that means the scan stopped seeing them rather than that the code stopped having them',
    );
  });
}
