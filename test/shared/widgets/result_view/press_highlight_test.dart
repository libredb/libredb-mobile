@Tags(['widget'])
library;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/shared/design_system/theme/app_theme.dart';
import 'package:libredb_mobile/shared/widgets/result_view/press_highlight.dart';

/// What [PressHighlight] does with a pointer, beyond what the rows that use it measure in pixels.
///
/// `result_row_touch_test.dart` presses a row and looks at the frame, which is the thing that matters and the thing
/// that regressed. It cannot see the two decisions underneath: that a pointer which turns into a scroll stops counting
/// as a press, and that a row with nothing to open never lights up at all.
void main() {
  Widget host({bool enabled = true}) => MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(
      body: Center(
        child: PressHighlight(enabled: enabled, child: const SizedBox(width: 200, height: 48)),
      ),
    ),
  );

  /// The colour the tint is painted with right now. The box is looked up under the widget rather than by type alone,
  /// because a `Scaffold` paints its own background with one too.
  Color tint(WidgetTester tester) => tester
      .widget<ColoredBox>(find.descendant(of: find.byType(PressHighlight), matching: find.byType(ColoredBox)))
      .color;

  Color highlightOf(WidgetTester tester) => Theme.of(tester.element(find.byType(PressHighlight))).highlightColor;

  testWidgets('tints with the theme highlight while the finger is down, and clears when it lifts', (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    expect(tint(tester), Colors.transparent);

    final gesture = await tester.startGesture(tester.getCenter(find.byType(PressHighlight)));
    await tester.pump();
    expect(tint(tester), highlightOf(tester), reason: 'a held row shows no tint, so the press is invisible');

    await gesture.up();
    await tester.pumpAndSettle();
    expect(tint(tester), Colors.transparent, reason: 'the tint outlived the finger');
  });

  // A result list is scrolled by dragging a row, and the pointer that starts the drag is the same one that would have
  // been a tap. Without this, flinging the list would leave a lit row behind the finger.
  testWidgets('drops the tint once the finger travels far enough to be a scroll', (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    final gesture = await tester.startGesture(tester.getCenter(find.byType(PressHighlight)));
    await tester.pump();
    expect(tint(tester), highlightOf(tester));

    await gesture.moveBy(const Offset(0, kTouchSlop / 2));
    await tester.pump();
    expect(tint(tester), highlightOf(tester), reason: 'a finger that has barely moved is still a press');

    await gesture.moveBy(const Offset(0, kTouchSlop));
    await tester.pump();
    expect(tint(tester), Colors.transparent, reason: 'a row stayed lit while the list was being dragged');

    await gesture.up();
    await tester.pumpAndSettle();
  });

  // A row with no onTap opens nothing, and #367 is as much about a control that cannot be used looking as though it
  // can as it is about the other way round.
  testWidgets('stays inert when there is nothing to open', (tester) async {
    await tester.pumpWidget(host(enabled: false));
    await tester.pumpAndSettle();

    final gesture = await tester.startGesture(tester.getCenter(find.byType(PressHighlight)));
    await tester.pump();
    expect(tint(tester), Colors.transparent, reason: 'a row that cannot be opened lights up as though it can');

    await gesture.up();
    await tester.pumpAndSettle();
  });

  // The row can lose its tap under the finger: a refresh replaces the result while a row is held, and the pointer
  // stream alone would never clear a tint whose widget stopped being tappable.
  testWidgets('clears the tint when the row stops being tappable under the finger', (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    final gesture = await tester.startGesture(tester.getCenter(find.byType(PressHighlight)));
    await tester.pump();
    expect(tint(tester), highlightOf(tester));

    await tester.pumpWidget(host(enabled: false));
    await tester.pump();
    expect(tint(tester), Colors.transparent, reason: 'the row stayed lit with nothing left to open');

    await gesture.up();
    await tester.pumpAndSettle();
  });
}
