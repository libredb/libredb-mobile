import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/shared/design_system/brand/svg_path.dart';

/// The subset of SVG path syntax the product's brand mark is written in.
///
/// It is parsed rather than rendered by a package because the app carries none that can, and the one shape it needs
/// is one file. What the mark actually uses — measured from `tool/design-system/assets/lb-icon.svg` — is `M`, `L`,
/// `l`, `C`, `c`, `s`, `h`, `v` and `Z`, so those are what this understands; anything else throws rather than
/// drawing something subtly wrong (#390).
void main() {
  Rect boundsOf(String d) => parseSvgPath(d).getBounds();

  test('an absolute square closes on itself', () {
    final path = parseSvgPath('M 0 0 L 10 0 L 10 10 L 0 10 Z');

    expect(path.getBounds(), const Rect.fromLTRB(0, 0, 10, 10));
    expect(path.contains(const Offset(5, 5)), isTrue);
    expect(path.contains(const Offset(15, 5)), isFalse);
  });

  test('a relative square draws the same square', () {
    expect(boundsOf('m 0 0 l 10 0 l 0 10 l -10 0 z'), const Rect.fromLTRB(0, 0, 10, 10));
  });

  test('commas, spaces and a leading minus all separate numbers', () {
    // The mark is minified: `l-10,0` and `l -10 0` are the same two numbers, and `10-5` is two.
    expect(boundsOf('M0,0L10,0L10-5Z'), const Rect.fromLTRB(0, -5, 10, 0));
    expect(boundsOf('M 0 0 L 10 0 L 10 -5 Z'), const Rect.fromLTRB(0, -5, 10, 0));
  });

  test('h and v move on one axis only', () {
    expect(boundsOf('M0,0h10v10z'), const Rect.fromLTRB(0, 0, 10, 10));
    expect(boundsOf('M10,10H0V0Z'), const Rect.fromLTRB(0, 0, 10, 10));
  });

  test('a cubic bends between its ends', () {
    // Sampled rather than measured by `getBounds`, which reports the control hull and not the curve: both control
    // points sit at y=10 while the curve only reaches 7.5, so the bounds would say nothing about the bend.
    final path = parseSvgPath('M0,0C0,10 10,10 10,0');
    final metric = path.computeMetrics().single;
    final middle = metric.getTangentForOffset(metric.length / 2)!.position;

    expect(middle.dx, closeTo(5, 0.01), reason: 'halfway along, halfway across');
    expect(middle.dy, greaterThan(0), reason: 'the curve leaves the line between its ends');
    expect(middle.dy, lessThan(10), reason: 'and does not reach its control points');
  });

  test('a smooth cubic reflects the previous control point', () {
    // `s` with no cubic before it uses the current point as its first control, which is what the spec says and
    // what the mark relies on after an `h`.
    final reflected = boundsOf('M0,0C0,-10 10,-10 10,0s10,10 10,0');
    final spelled = boundsOf('M0,0C0,-10 10,-10 10,0C10,10 20,10 20,0');

    expect(reflected, spelled);
  });

  test('a repeated command keeps drawing without being named again', () {
    // `L10,0 10,10` is two line commands with one letter, which the minifier relies on.
    expect(boundsOf('M0,0L10,0 10,10 0,10Z'), const Rect.fromLTRB(0, 0, 10, 10));
  });

  test('a command it does not understand throws rather than drawing something else', () {
    // An arc would silently become nothing, and a mark that is silently wrong is worse than one that fails loudly.
    expect(() => parseSvgPath('M0,0A5,5 0 0 1 10,10'), throwsFormatException);
  });

  test('a path that does not start with a move throws', () {
    expect(() => parseSvgPath('L10,10'), throwsFormatException);
  });
}
