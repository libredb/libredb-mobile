@Tags(['widget'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/shared/models/query_page.dart';
import 'package:libredb_mobile/shared/models/query_result.dart';
import 'package:libredb_mobile/shared/widgets/result_view/result_notices.dart';

import '../../../support/pressed_frame.dart';

/// What the warnings chip does under a finger.
///
/// The chip is already an `InkWell`, and `result_view_test.dart` proves its tap opens and shuts the warning list. What
/// neither says is whether the user can see that the chip is a control: its splash paints on the nearest `Material`,
/// which sits behind the chip's own opaque background, so the ripple was drawn and then covered (#367).
void main() {
  const warnings = [QueryWarning(message: 'first'), QueryWarning(message: 'second')];

  QueryResult result() => const QueryResult(
    fields: ['id'],
    rows: [
      {'id': 1},
    ],
    rowCount: 1,
    executionTime: Duration(milliseconds: 3),
    warnings: warnings,
    pagination: QueryPagination(limit: 500, offset: 0, hasMore: false, totalReturned: 1, wasLimited: false),
  );

  testWidgets('the warnings chip draws a different frame while held', (tester) async {
    final pressed = await rendersPressedState(
      tester,
      ResultStatsStrip(result: result()),
      pressAt: find.byKey(const ValueKey('result-warnings-chip')),
    );
    expect(
      pressed,
      isTrue,
      reason: 'the one affordance saying the warnings can be opened answers a finger with nothing',
    );
  });
}
