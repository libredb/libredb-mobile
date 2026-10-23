@Tags(['widget'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/features/sql_editor/presentation/widgets/editor_accessory_row.dart';
import 'package:libredb_mobile/generated/l10n.dart';

void main() {
  group('insertAtSelection', () {
    test('inserts at the cursor and puts the cursor after the insert', () {
      const value = TextEditingValue(text: 'select  from t', selection: TextSelection.collapsed(offset: 7));

      expect(
        insertAtSelection(value, '*'),
        const TextEditingValue(text: 'select * from t', selection: TextSelection.collapsed(offset: 8)),
      );
    });

    test('replaces the selection, whichever way it was made', () {
      const forward = TextEditingValue(text: 'a = b', selection: TextSelection(baseOffset: 2, extentOffset: 3));
      const backward = TextEditingValue(text: 'a = b', selection: TextSelection(baseOffset: 3, extentOffset: 2));

      for (final value in [forward, backward]) {
        expect(
          insertAtSelection(value, ','),
          const TextEditingValue(text: 'a , b', selection: TextSelection.collapsed(offset: 3)),
        );
      }
    });

    test('a field without a cursor gets the insert at its end', () {
      const value = TextEditingValue(text: 'select 1');

      expect(
        insertAtSelection(value, ';'),
        const TextEditingValue(text: 'select 1;', selection: TextSelection.collapsed(offset: 9)),
      );
    });
  });

  group('EditorAccessoryRow', () {
    late TextEditingController controller;
    late UndoHistoryController undo;

    setUp(() {
      controller = TextEditingController();
      undo = UndoHistoryController();
    });

    tearDown(() {
      controller.dispose();
      undo.dispose();
    });

    Future<void> pump(WidgetTester tester, {Locale? locale}) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: locale,
          localizationsDelegates: const [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.delegate.supportedLocales,
          home: Scaffold(
            body: Column(
              children: [
                TextField(key: const ValueKey('field'), controller: controller, undoController: undo, maxLines: null),
                EditorAccessoryRow(controller: controller, undoController: undo),
              ],
            ),
          ),
        ),
      );
    }

    Future<void> tapKey(WidgetTester tester, Key key) async {
      await tester.ensureVisible(find.byKey(key));
      await tester.tap(find.byKey(key));
      await tester.pump();
    }

    for (final symbol in EditorAccessoryRow.symbols) {
      testWidgets('$symbol inserts at the cursor and replaces a selection', (tester) async {
        await pump(tester);
        controller.value = const TextEditingValue(text: 'ab', selection: TextSelection.collapsed(offset: 1));

        await tapKey(tester, EditorAccessoryRow.symbolKey(symbol));
        expect(controller.text, 'a${symbol}b');
        expect(controller.selection, const TextSelection.collapsed(offset: 2));

        controller.value = const TextEditingValue(
          text: 'abc',
          selection: TextSelection(baseOffset: 0, extentOffset: 2),
        );
        await tapKey(tester, EditorAccessoryRow.symbolKey(symbol));
        expect(controller.text, '${symbol}c');
      });
    }

    testWidgets('Tab inserts two spaces at the cursor and replaces a selection', (tester) async {
      await pump(tester);
      controller.value = const TextEditingValue(text: 'ab', selection: TextSelection.collapsed(offset: 1));

      await tapKey(tester, EditorAccessoryRow.tabKey);
      expect(controller.text, 'a  b');
      expect(controller.selection, const TextSelection.collapsed(offset: 3));

      controller.selection = const TextSelection(baseOffset: 0, extentOffset: 4);
      await tapKey(tester, EditorAccessoryRow.tabKey);
      expect(controller.text, '  ');
    });

    testWidgets('Undo and Redo walk the edits, and are disabled with nothing to walk', (tester) async {
      await pump(tester);
      await tester.showKeyboard(find.byKey(const ValueKey('field')));
      bool enabled(Key key) => tester.widget<IconButton>(find.byKey(key)).onPressed != null;
      expect(enabled(EditorAccessoryRow.undoKey), isFalse);
      expect(enabled(EditorAccessoryRow.redoKey), isFalse);

      await tester.enterText(find.byKey(const ValueKey('field')), 'select');
      await tester.pump(const Duration(seconds: 1));
      await tapKey(tester, EditorAccessoryRow.symbolKey('*'));
      await tester.pump(const Duration(seconds: 1));
      expect(controller.text, 'select*');
      expect(enabled(EditorAccessoryRow.undoKey), isTrue);

      await tapKey(tester, EditorAccessoryRow.undoKey);
      expect(controller.text, 'select');
      expect(enabled(EditorAccessoryRow.redoKey), isTrue);

      await tapKey(tester, EditorAccessoryRow.redoKey);
      expect(controller.text, 'select*');
      expect(enabled(EditorAccessoryRow.redoKey), isFalse);
    });

    testWidgets('names Tab, Undo and Redo in Turkish', (tester) async {
      await pump(tester, locale: const Locale('tr'));

      expect(find.byTooltip('Sekme'), findsOneWidget);
      expect(find.byTooltip('Geri al'), findsOneWidget);
      expect(find.byTooltip('Yinele'), findsOneWidget);
    });
  });
}
