@Tags(['widget'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/shared/widgets/result_view/result_card.dart';
import 'package:libredb_mobile/shared/widgets/result_view/result_fields.dart';
import 'package:libredb_mobile/shared/widgets/result_view/result_table.dart';

import '../../../support/pressed_frame.dart';

/// What a result row does under a finger, in both of the ways a result is shown.
///
/// A row is the control a user of this app touches most, and neither view had ever been pressed in a test. Each row is
/// built here on its own rather than through the page that lists them: that keeps the measurement away from the
/// scrollable the page wraps them in, and away from the row detail its real `onTap` would open over the frame being
/// measured (#367).
void main() {
  const fields = ['id', 'name'];
  const row = {'id': 1, 'name': 'Alice'};

  testWidgets('a table row draws a different frame when pressed', (tester) async {
    final pressed = await rendersPressedState(
      tester,
      ResultTableRow(
        index: 0,
        row: row,
        fields: fields,
        widths: const [80, 160],
        maskedColumns: const {},
        vectorColumns: const {},
        onTap: () {},
        onCellLongPress: (_) {},
      ),
      pressAt: find.text('Alice'),
      surface: const Size(300, 60),
      // Its cells take a long press, which keeps the gesture arena open until the finger lifts.
      measureOnRelease: true,
    );
    expect(pressed, isTrue, reason: 'a table row answers a finger with nothing');
  });

  testWidgets('a card row draws a different frame when pressed', (tester) async {
    const rows = [row];
    final primary = primaryField(fields, rows);
    final id = idField(fields);
    final pressed = await rendersPressedState(
      tester,
      ResultCard(
        row: row,
        index: 0,
        fieldCount: fields.length,
        primary: primary,
        id: id,
        preview: previewFields(fields, primary: primary, id: id),
        maskedColumns: const {},
        vectorColumns: const {},
        onTap: () {},
        onFieldLongPress: (_) {},
      ),
      pressAt: find.text('Alice'),
      surface: const Size(360, 200),
      // Its fields take a long press, which keeps the gesture arena open until the finger lifts.
      measureOnRelease: true,
    );
    expect(pressed, isTrue, reason: 'a card row answers a finger with nothing');
  });
}
