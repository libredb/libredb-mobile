@Tags(['widget'])
library;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/shared/design_system/tokens/app_sizes.dart';
import 'package:libredb_mobile/shared/widgets/result_view/result_card.dart';
import 'package:libredb_mobile/shared/widgets/result_view/result_fields.dart';
import 'package:libredb_mobile/shared/widgets/result_view/result_table.dart';

/// What a result row is, to a finger and to a screen reader.
///
/// It is the control a user of this app touches most, and the one whose neighbours are identical — a miss opens the
/// wrong row rather than nothing. It carried no semantics of its own, so a screen reader read its cells as loose text
/// with no row and no sign the row could be opened (#373).
///
/// The floor here is [AppSizes.minDenseTarget], not [AppSizes.minDenseTarget]. The 48 pt one is this repository's house
/// rule for buttons and chips; holding a result row to it leaves room for two rows where #177 guarantees three on a
/// phone held sideways. WCAG 2.2 asks 24 pt at AA (2.5.8), and 44 pt only at AAA.
void main() {
  const fields = ['id', 'name'];
  const row = {'id': 1, 'name': 'Alice'};

  Future<void> pump(WidgetTester tester, Widget subject) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.delegate.supportedLocales,
        locale: const Locale('en'),
        home: Scaffold(body: subject),
      ),
    );
    await tester.pumpAndSettle();
  }

  Widget tableRow() => ResultTableRow(
    index: 0,
    row: row,
    fields: fields,
    widths: const [80, 160],
    maskedColumns: const {},
    vectorColumns: const {},
    onTap: () {},
    onCellLongPress: (_) {},
  );

  Widget cardRow() {
    const rows = [row];
    final primary = primaryField(fields, rows);
    final id = idField(fields);
    return ResultCard(
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
    );
  }

  group('a finger', () {
    testWidgets('a table row is at least ${AppSizes.minDenseTarget} pt tall', (tester) async {
      await pump(tester, tableRow());
      expect(tester.getSize(find.byType(ResultTableRow)).height, greaterThanOrEqualTo(AppSizes.minDenseTarget));
    });

    testWidgets('a card row is at least ${AppSizes.minDenseTarget} pt tall', (tester) async {
      await pump(tester, cardRow());
      expect(tester.getSize(find.byType(ResultCard)).height, greaterThanOrEqualTo(AppSizes.minDenseTarget));
    });
  });

  group('a screen reader', () {
    testWidgets('hears a table row as one thing it can open', (tester) async {
      final handle = tester.ensureSemantics();
      await pump(tester, tableRow());

      final node = tester.getSemantics(find.byType(ResultTableRow));
      expect(node.label, isNotEmpty, reason: 'the row says nothing about which row it is');
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      handle.dispose();
    });

    testWidgets('hears a card row as one thing it can open', (tester) async {
      final handle = tester.ensureSemantics();
      await pump(tester, cardRow());

      final node = tester.getSemantics(find.byType(ResultCard));
      expect(node.label, isNotEmpty, reason: 'the row says nothing about which row it is');
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      handle.dispose();
    });
  });
}
