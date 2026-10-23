import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/shared/models/query_result.dart';
import 'package:libredb_mobile/shared/widgets/result_view/result_card.dart';
import 'package:libredb_mobile/shared/widgets/result_view/result_table.dart';

/// A result taller and wider than the phone: [rows] rows of [columns] plain text columns.
QueryResult wideResult({int rows = 100, int columns = 23}) {
  final fields = [for (var c = 1; c <= columns; c++) 'column_$c'];
  return QueryResult(
    fields: fields,
    rows: [
      for (var r = 1; r <= rows; r++) {for (final field in fields) field: 'row $r $field'},
    ],
    rowCount: rows,
    executionTime: Duration.zero,
  );
}

Finder _scrollableIn(Finder parent, AxisDirection direction) => find
    .descendant(
      of: parent,
      matching: find.byWidgetPredicate((widget) => widget is Scrollable && widget.axisDirection == direction),
    )
    .first;

/// The card list's vertical scrollable.
Finder cardListScrollable() => _scrollableIn(find.byType(ResultCardList), AxisDirection.down);

/// The table's vertical scrollable, the rows under its header.
Finder tableRowsScrollable() => _scrollableIn(find.byType(ResultTable), AxisDirection.down);

/// The table's sideways scrollable, the columns.
Finder tableColumnsScrollable() => _scrollableIn(find.byType(ResultTable), AxisDirection.right);

ScrollPosition scrollPositionOf(WidgetTester tester, Finder scrollable) =>
    tester.state<ScrollableState>(scrollable).position;

/// The middle of the part of [scrollable] on the screen: the table's rows are as wide as all its columns, so their
/// own middle can lie past the right edge.
Offset _onScreen(WidgetTester tester, Finder scrollable) {
  final view = tester.view;
  final screen = Offset.zero & (view.physicalSize / view.devicePixelRatio);
  return tester.getRect(scrollable).intersect(screen).center;
}

/// Drags [scrollable] from near its far end far past it, then from near its near end far past that, and expects it to
/// settle at each end.
Future<void> expectSettlesAtEachEnd(WidgetTester tester, Finder scrollable) async {
  final vertical = scrollPositionOf(tester, scrollable).axis == Axis.vertical;
  Offset by(double distance) => vertical ? Offset(0, distance) : Offset(distance, 0);

  final start = scrollPositionOf(tester, scrollable);
  expect(start.maxScrollExtent, greaterThan(200), reason: 'the result must be longer than the view');
  start.jumpTo(start.maxScrollExtent - 100);
  await tester.pump();
  await tester.dragFrom(_onScreen(tester, scrollable), by(-2000));
  await tester.pumpAndSettle();
  final atEnd = scrollPositionOf(tester, scrollable);
  expect(atEnd.pixels, moreOrLessEquals(atEnd.maxScrollExtent), reason: 'past the far end');

  atEnd.jumpTo(atEnd.minScrollExtent + 100);
  await tester.pump();
  await tester.dragFrom(_onScreen(tester, scrollable), by(2000));
  await tester.pumpAndSettle();
  final atStart = scrollPositionOf(tester, scrollable);
  expect(atStart.pixels, moreOrLessEquals(atStart.minScrollExtent), reason: 'past the near end');
}

/// Pulls [scrollable] down from its top to refresh, and expects it to spring back to its top.
Future<void> pullAndExpectSpringBack(WidgetTester tester, Finder scrollable) async {
  await tester.flingFrom(_onScreen(tester, scrollable), const Offset(0, 400), 1000);
  await tester.pumpAndSettle();
  final position = scrollPositionOf(tester, scrollable);
  expect(position.pixels, moreOrLessEquals(position.minScrollExtent), reason: 'after the pull');
}
