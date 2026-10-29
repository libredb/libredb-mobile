@Tags(['widget'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/features/onboarding/presentation/widgets/engine_mark.dart';
import 'package:libredb_mobile/shared/design_system/tokens/tokens.dart';

/// The introduction's per-engine marks.
///
/// `engineIcon` maps a *family*, so `postgres` and `mysql` share a glyph there and four production screens depend on
/// that. The prototype's first screen draws the engine instead — `PG` and `MY` are two different SVGs in `ob.html` —
/// so the introduction carries its own two marks. What is settled here is that each mark really is the prototype's
/// path, read off the path's own extents, and that the shared token was left as it is.
///
/// **The font trap:** no claim in this file involves text. Path coordinates and widget types are identical under
/// Ahem and on a phone, so nothing measured here is a number that exists only in the test font.
void main() {
  /// The extents of a path, as `Path.getBounds` reports them: for a cubic that is the hull of its control points,
  /// which is exactly the set of numbers the SVG's `c`/`s` commands are written in.
  void expectBounds(Rect bounds, {required double l, required double t, required double r, required double b}) {
    expect(bounds.left, closeTo(l, 0.01), reason: 'left');
    expect(bounds.top, closeTo(t, 0.01), reason: 'top');
    expect(bounds.right, closeTo(r, 0.01), reason: 'right');
    expect(bounds.bottom, closeTo(b, 0.01), reason: 'bottom');
  }

  /// Where one contour of [path] starts, turns and ends — its 0, half and full arc length.
  ///
  /// Extents alone are not enough and that is not a guess: moving the arc's apex from y 9 to y 10 left the hull
  /// untouched, because the second cubic's own control point still sat at y 9, and a bounds-only test stayed green
  /// on a visibly different drawing. A point measured along the curve moves when the curve does.
  ({Offset start, Offset mid, Offset end}) contour(Path path, int index) {
    final metric = path.computeMetrics().elementAt(index);
    return (
      start: metric.getTangentForOffset(0)!.position,
      mid: metric.getTangentForOffset(metric.length / 2)!.position,
      end: metric.getTangentForOffset(metric.length)!.position,
    );
  }

  Matcher isOffset(double dx, double dy) => within(distance: 0.02, from: Offset(dx, dy), distanceFunction: _apart);

  group('which engine gets which mark', () {
    test('postgres is the cylinder and mysql the arc, as the prototype draws its three rows', () {
      // `[[PG,'orders-prod',…],[MY,'billing-stage',…],[PG,'lab',…]]`.
      expect(EngineMark.of('postgres'), EngineMark.cylinder);
      expect(EngineMark.of('mysql'), EngineMark.dolphin);
    });

    test('an engine the introduction has no mark for gets none, and the type is an opaque string', () {
      expect(EngineMark.of('oracle'), isNull, reason: 'the introduction draws only the two engines it shows');
      expect(EngineMark.of('Postgres'), isNull, reason: 'another case is another type, as everywhere else');
      expect(EngineMark.of(''), isNull);
    });

    test('the shared family token is left alone, since the list, the browser and the switcher read it', () {
      // This is the guard on where the fix went. `engine_icons.dart` groups by family on purpose and
      // `engine_icons_test.dart` pins it; giving postgres and mysql their own glyphs there would have changed four
      // production screens for a screen of the introduction.
      expect(engineIcon('postgres'), engineIcon('mysql'));
    });
  });

  group('the marks are the prototype\'s own paths, in its 24-unit viewBox', () {
    test('the cylinder is a disc at cy 6 over a body that bottoms at 21, with its band half way down', () {
      // `<ellipse cx="12" cy="6" rx="7.5" ry="3"/>` spans x 4.5..19.5 and y 3..9; the body
      // `M4.5 6v12c0 1.7 3.4 3 7.5 3s7.5-1.3 7.5-3V6` reaches y 21 at the foot and no wider than the disc.
      final path = EngineMark.cylinder.strokePath();
      expectBounds(path.getBounds(), l: 4.5, t: 3, r: 19.5, b: 21);
      expect(path.computeMetrics().length, 3, reason: 'the disc, the body and the one band');

      // The body: down the left side at x 4.5, round the foot at 12,21, up the right side to 19.5,6.
      expect(contour(path, 1).start, isOffset(4.5, 6));
      expect(contour(path, 1).mid, isOffset(12, 21), reason: 'the foot of the cylinder');
      expect(contour(path, 1).end, isOffset(19.5, 6));

      // The band, `M4.5 12c0 1.7 3.4 3 7.5 3s7.5-1.3 7.5-3`: it leaves and rejoins the sides at y 12 and dips to 15.
      expect(contour(path, 2).start, isOffset(4.5, 12));
      expect(contour(path, 2).mid, isOffset(12, 15), reason: 'the band dips as far as the foot does, 3 units');
      expect(contour(path, 2).end, isOffset(19.5, 12));

      expect(EngineMark.cylinder.fillPath().getBounds().isEmpty, isTrue, reason: 'PG is `fill="none"` throughout');
    });

    test('the arc rises from 3,18 to its apex at 12,9 and falls to 21,18, with the dot filled at the apex', () {
      // `<path d="M3 18c3-6 6-9 9-9s6 3 9 9"/>`: one contour, symmetric, so its half-length point *is* the apex.
      final path = EngineMark.dolphin.strokePath();
      expectBounds(path.getBounds(), l: 3, t: 9, r: 21, b: 18);
      expect(path.computeMetrics().length, 1, reason: 'MY is drawn in one stroke');
      expect(contour(path, 0).start, isOffset(3, 18));
      expect(contour(path, 0).mid, isOffset(12, 9), reason: 'the apex, where the dot sits');
      expect(contour(path, 0).end, isOffset(21, 18));

      // `<circle cx="12" cy="9" r="1.6" fill="currentColor"/>`, centred on that apex.
      expectBounds(EngineMark.dolphin.fillPath().getBounds(), l: 10.4, t: 7.4, r: 13.6, b: 10.6);
    });

    test('the two marks are not the same drawing', () {
      expect(
        EngineMark.cylinder.strokePath().getBounds(),
        isNot(EngineMark.dolphin.strokePath().getBounds()),
        reason: 'if the two paths had the same extents the screen would be back to one glyph for both engines',
      );
    });
  });

  group('the widget', () {
    Future<void> show(WidgetTester tester, String type) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: EngineMarkIcon(type: type, color: const Color(0xFF4F46E5)),
          ),
        ),
      ),
    );

    testWidgets('draws a marked engine itself, at the row\'s icon size', (tester) async {
      await show(tester, 'postgres');

      expect(find.byType(CustomPaint), findsWidgets, reason: 'the mark is drawn, not looked up in the icon font');
      expect(tester.getSize(find.byType(EngineMarkIcon)), const Size(AppSizes.iconMd, AppSizes.iconMd));
    });

    testWidgets('falls back to the shared family icon for an engine it has no mark for', (tester) async {
      await show(tester, 'oracle');

      // So a fourth demo row added later draws something rather than nothing.
      expect(tester.widget<Icon>(find.byType(Icon)).icon, engineIcon('oracle'));
    });

    testWidgets('describes the mark it draws, not the engine, so two engines of one mark read alike', (tester) async {
      await show(tester, 'postgres');
      final postgres = tester.widget(find.byType(EngineMarkIcon)).toString();
      await show(tester, 'mysql');
      final mysql = tester.widget(find.byType(EngineMarkIcon)).toString();

      expect(postgres, contains('cylinder'));
      expect(mysql, contains('dolphin'));
      expect(postgres, isNot(mysql));
      expect(postgres, isNot(contains('postgres')), reason: 'the engine name would tell them apart for free');
    });
  });
}

/// How far apart two points are, for [within]: a mark whose curve has moved is a mark drawn differently.
double _apart(Offset a, Offset b) => (a - b).distance;
