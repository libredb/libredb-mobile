import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../support/dart_code.dart';

/// Guards that a control answers a finger.
///
/// Every other guard in this directory reads the code or one resting frame. None has ever pressed a widget and looked
/// at what changed, which is how this app shipped a card used on eight screens whose entire interaction state — the
/// lift of `elevated`, the border of `outlined`, the fill of `filled` — came from `MouseRegion.onEnter`, a callback
/// that never fires on the only devices the app is built for (#367).
///
/// The two halves below catch different things, and the comment on each says which:
///
/// * the source half catches a widget that reads a pointer the device does not have;
/// * the linkage half catches a tappable widget nobody has pressed in a test, which is the only way to find a control
///   whose ripple is drawn correctly and then covered by its own background — what the result warnings chip did.
///
/// Neither half catches an animation that runs on an unmounted child, the fourth defect of #367; that one is pinned by
/// `test/app/connectivity/connectivity_banner_test.dart`.
void main() {
  Map<String, String> readAll(String root, String Function(String) transform) {
    final files = <String, String>{};
    final dir = Directory(root);
    if (!dir.existsSync()) return files;
    for (final file in dir.listSync(recursive: true).whereType<File>()) {
      final path = file.path.replaceAll(r'\', '/');
      if (!path.endsWith('.dart')) continue;
      files[path] = transform(file.readAsStringSync());
    }
    return files;
  }

  /// Every Dart file under [root], as code with its comments and strings taken out — a widget named in a comment is
  /// not a widget the file builds.
  Map<String, String> sourcesUnder(String root) => readAll(root, (source) => codeOnly(source));

  /// Every Dart file under [root], verbatim. An import path is a string, so a scan for one has to keep strings.
  Map<String, String> verbatimUnder(String root) => readAll(root, (source) => source);

  test('no widget takes its interaction state from a pointer a phone does not have', () {
    // A `MouseRegion` that writes state is a hover state, and a hover state is the whole of a widget's response only
    // on a desktop. A widget that has one must also offer ink, which is what a finger produces.
    final sources = sourcesUnder('lib/');
    expect(sources, isNotEmpty, reason: 'no Dart file was read at all — the guard is looking in the wrong place');

    final offenders = <String>[];
    sources.forEach((path, code) {
      // `onHover:` is the same hover through a different door, and a `WidgetStateProperty` that answers `hovered`
      // without answering `pressed` is the modern spelling of exactly this bug.
      final hovers =
          (code.contains('MouseRegion') &&
              (code.contains('onEnter:') || code.contains('onExit:') || code.contains('onHover:'))) ||
          (code.contains('WidgetState.hovered') && !code.contains('WidgetState.pressed'));
      final inks = code.contains('InkWell') || code.contains('InkResponse');
      if (hovers && !inks) offenders.add(path);
    });

    expect(
      offenders,
      isEmpty,
      reason:
          'these widgets change only under a mouse, so on a phone they do not change at all.\n'
          'Give the widget an InkWell and let the press drive the same state the hover does:\n'
          '${offenders.join('\n')}',
    );
  });

  test('every shared widget the user can tap has been pressed in a test', () {
    // A widget under `lib/shared/` is used by many screens, so one that answers a finger with nothing is wrong
    // everywhere at once. Declaring an `onTap` is the widget saying it is a control; this asks for the proof.
    final tappable = <String>[];
    sourcesUnder('lib/shared/').forEach((path, code) {
      if (RegExp(r'final\s+VoidCallback\??\s+onTap;').hasMatch(code)) tappable.add(path);
    });
    expect(tappable, isNotEmpty, reason: 'the pattern stopped matching how a shared widget declares an onTap');

    /// The widget classes [path] declares, which is what a test has to build to press one.
    Set<String> classesOf(String path) =>
        RegExp(r'class\s+([A-Z]\w*)')
            .allMatches(codeOnly(File(path).readAsStringSync()))
            .map((match) => match.group(1)!)
            .toSet();

    final pressing = <({Set<String> libraries, String code})>[];
    verbatimUnder('test/').forEach((path, code) {
      if (!code.contains('rendersPressedState') && !code.contains('pressedAndRestingFrames')) return;
      final libraries = RegExp(r"import 'package:libredb_mobile/([^']+)'")
          .allMatches(code)
          .map((match) => 'lib/${match.group(1)}')
          .toSet();
      // The imports come from the verbatim text because a path is a string; the search for a constructor call does
      // not, or a widget named in a doc comment would count as one a test pressed.
      pressing.add((libraries: libraries, code: codeOnly(code)));
    });

    /// Importing the library is not enough — a test that presses one widget and merely mentions another would cover
    /// it by accident — so the test has to name a class the file declares as well.
    bool isPressed(String path) {
      final classes = classesOf(path);
      return pressing.any(
        (test) => test.libraries.contains(path) && classes.any((name) => RegExp('\\b$name\\(').hasMatch(test.code)),
      );
    }

    final unpressed = tappable.where((path) => !isPressed(path)).toList();
    expect(
      unpressed,
      isEmpty,
      reason:
          'these widgets take an onTap, and no test has ever held a finger on them.\n'
          'Add one with `rendersPressedState` from `test/support/pressed_frame.dart`:\n'
          '${unpressed.join('\n')}',
    );
  });
}
