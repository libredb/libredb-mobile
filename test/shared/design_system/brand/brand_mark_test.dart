@Tags(['widget'])
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/shared/design_system/brand/brand_mark.dart';
import 'package:libredb_mobile/shared/design_system/brand/svg_path.dart';

/// Holds the brand mark to the file it was copied from, and holds the copy to being drawable.
///
/// The geometry is a copy, for the same reason the design system's tokens are: the app draws the mark
/// synchronously, in a frame, and an asset it has to wait for would make every caller asynchronous for a shape
/// that never changes. What makes a copy safe is that the original is in the repository and a test reads it —
/// `tool/design-system/assets/lb-icon.svg`, itself a verbatim copy of the design system's own (#390).
void main() {
  final svg = File('tool/design-system/assets/lb-icon.svg').readAsStringSync();

  test('the mark is the geometry the design system declares', () {
    final viewBox = RegExp(r'viewBox="0 0 ([\d.]+) ([\d.]+)"').firstMatch(svg)!;
    expect(BrandMark.viewBox.width, double.parse(viewBox.group(1)!));
    expect(BrandMark.viewBox.height, double.parse(viewBox.group(2)!));

    // The frame and the rows are the brand gradient; the two chevrons are the data gradient. Reading them by their
    // fill rather than by their order is what makes this fail if the system ever recolours a part.
    final brandPaths = RegExp(r'<path d="([^"]+)" fill="url\(#gb\)"').allMatches(svg).map((m) => m.group(1)).toList();
    final dataPaths = RegExp(r'<path d="([^"]+)" fill="url\(#gd\)"').allMatches(svg).map((m) => m.group(1)).toList();

    expect(brandPaths, [BrandMark.frame], reason: 'the hexagon frame');
    expect(dataPaths, BrandMark.chevrons, reason: 'the two chevrons');
  });

  test('the three data rows are the rectangles the design system declares', () {
    final rects = RegExp(r'<rect x="([\d.]+)" y="([\d.]+)" width="([\d.]+)" height="([\d.]+)" rx="([\d.]+)"')
        .allMatches(svg)
        .toList();

    expect(rects, hasLength(BrandMark.rows.length));
    for (final (index, match) in rects.indexed) {
      expect(
        BrandMark.rows[index],
        Rect.fromLTWH(
          double.parse(match.group(1)!),
          double.parse(match.group(2)!),
          double.parse(match.group(3)!),
          double.parse(match.group(4)!),
        ),
        reason: 'row ${index + 1}',
      );
      expect(BrandMark.rowRadius, double.parse(match.group(5)!), reason: 'row ${index + 1} corner');
    }
  });

  test('every path of the mark parses, and none of them is empty', () {
    // The parser refuses what it does not understand, so this is also the check that the mark stays inside the
    // nine commands it was measured to use. A silently empty path would draw nothing at all.
    for (final (name, d) in [
      ('frame', BrandMark.frame),
      ...BrandMark.chevrons.indexed.map((e) => ('chevron ${e.$1}', e.$2)),
    ]) {
      final path = parseSvgPath(d);
      expect(path.getBounds().isEmpty, isFalse, reason: '$name drew nothing');
      expect(path.getBounds().width, greaterThan(0), reason: name);
    }
  });

  test('the frame fills the viewBox and the rows sit inside it', () {
    // `getBounds` reports the control hull, which reaches a few units past the curve, so this asks the frame to
    // *cover* the viewBox rather than to equal it — the claim being that the mark is the whole icon and not a
    // shape sitting in a corner of it.
    final frame = parseSvgPath(BrandMark.frame).getBounds();

    expect(frame.left, lessThanOrEqualTo(0.5));
    expect(frame.top, lessThanOrEqualTo(0.5));
    expect(frame.right, greaterThanOrEqualTo(BrandMark.viewBox.width - 0.5));
    expect(frame.bottom, greaterThanOrEqualTo(BrandMark.viewBox.height - 0.5));
    expect(frame.width, lessThan(BrandMark.viewBox.width * 1.05), reason: 'and not much more than it');
    for (final row in BrandMark.rows) {
      expect(frame.contains(row.topLeft), isTrue, reason: 'a data row outside the frame');
      expect(frame.contains(row.bottomRight), isTrue, reason: 'a data row outside the frame');
    }
  });

  testWidgets('it takes the width it is given and the height the system draws it at', (tester) async {
    // Centred, because the test root hands down tight constraints and a SizedBox under them takes the screen.
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Center(child: BrandMark(size: 120)),
      ),
    );

    final box = tester.getSize(find.byType(BrandMark));
    expect(box.width, 120);
    expect(box.height, closeTo(120 * BrandMark.viewBox.height / BrandMark.viewBox.width, 0.01));
  });

  testWidgets('it paints without throwing, in both its gradient and its single-ink form', (tester) async {
    for (final colour in [null, const Color(0xFFFFFFFF)]) {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: BrandMark(size: 64, color: colour),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull, reason: 'colour: $colour');
    }
  });
}
