@Tags(['widget'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/shared/models/vector_column.dart';
import 'package:libredb_mobile/shared/utils/cell_values.dart';
import 'package:libredb_mobile/shared/widgets/cells/compact_cell.dart';
import 'package:libredb_mobile/shared/widgets/cells/detail_cell.dart';

Widget _app(Widget child, {Locale locale = const Locale('en')}) => MaterialApp(
  locale: locale,
  localizationsDelegates: const [
    S.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: S.delegate.supportedLocales,
  home: Scaffold(body: SizedBox(width: 160, child: child)),
);

Text _textOf(WidgetTester tester, String text) => tester.widget<Text>(find.text(text));

void main() {
  group('CompactCell', () {
    testWidgets('NULL is a muted italic marker that a screen reader reads as null, not as letters', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_app(CompactCell(cell: classifyCell(null))));

      final marker = _textOf(tester, 'NULL');
      final theme = Theme.of(tester.element(find.text('NULL')));
      expect(marker.style?.fontStyle, FontStyle.italic);
      expect(marker.style?.color, theme.colorScheme.onSurfaceVariant);
      expect(find.bySemanticsLabel('Null value'), findsOneWidget);
      expect(find.bySemanticsLabel('NULL'), findsNothing);
      handle.dispose();
    });

    testWidgets('the NULL label is Turkish in Turkish', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_app(CompactCell(cell: classifyCell(null)), locale: const Locale('tr')));

      expect(find.bySemanticsLabel('Boş değer'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('the string NULL is plain text, not the marker', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_app(CompactCell(cell: classifyCell('NULL'))));

      final text = _textOf(tester, 'NULL');
      expect(text.style?.fontStyle, isNot(FontStyle.italic));
      expect(find.bySemanticsLabel('Null value'), findsNothing);
      handle.dispose();
    });

    testWidgets('a value is one line with an ellipsis', (tester) async {
      await tester.pumpWidget(_app(CompactCell(cell: classifyCell('a long value ' * 20))));

      final text = tester.widget<Text>(find.byType(Text));
      expect(text.maxLines, 1);
      expect(text.overflow, TextOverflow.ellipsis);
      expect(text.softWrap, isFalse);
    });

    testWidgets('a multi-line JSON string shows on one line, its line breaks as spaces', (tester) async {
      await tester.pumpWidget(_app(CompactCell(cell: classifyCell('{\n  "id": 1\n}'))));

      expect(find.text('{ "id": 1 }'), findsOneWidget);
    });

    testWidgets('a 1536-element vector shows its preview and size, and never builds its whole text', (tester) async {
      final cell = classifyCell([
        for (var index = 0; index < 1536; index++) index / 4,
      ], vector: const VectorColumn(kind: 'dense', dtype: 'float32', dimension: 1536)) as VectorCell;
      await tester.pumpWidget(_app(CompactCell(cell: cell)));

      expect(find.text('[0.0, 0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, …] 1536 dims'), findsOneWidget);
      expect(cell.isCopyBuilt, isFalse);
    });
  });

  group('DetailCell', () {
    TextStyle? styleOf(WidgetTester tester) => tester.widget<SelectableText>(find.byType(SelectableText)).style;

    testWidgets('NULL shows null in muted italic, and is read as null', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_app(DetailCell(cell: classifyCell(null))));

      expect(find.text('null'), findsOneWidget);
      expect(styleOf(tester)?.fontStyle, FontStyle.italic);
      expect(find.bySemanticsLabel('Null value'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('a field the row lacks shows NULL in muted italic, and is read as null', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_app(DetailCell(cell: classifyCell(null, isAbsent: true))));

      expect(find.text('NULL'), findsOneWidget);
      expect(styleOf(tester)?.fontStyle, FontStyle.italic);
      expect(find.bySemanticsLabel('Null value'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('a scalar is selectable text in the body font', (tester) async {
      await tester.pumpWidget(_app(DetailCell(cell: classifyCell('9007199254740993'))));

      expect(find.text('9007199254740993'), findsOneWidget);
      expect(styleOf(tester)?.fontFamily, isNot('monospace'));
    });

    testWidgets('JSON is the pretty text in monospace', (tester) async {
      await tester.pumpWidget(_app(DetailCell(cell: classifyCell({'a': 1}))));

      expect(find.text('{\n  "a": 1\n}'), findsOneWidget);
      expect(styleOf(tester)?.fontFamily, 'monospace');
    });

    testWidgets('binary is the whole hex in monospace', (tester) async {
      await tester.pumpWidget(_app(DetailCell(cell: classifyCell({'type': 'Buffer', 'data': List.filled(33, 0xab)}))));

      expect(find.text('\\x${'ab' * 33}'), findsOneWidget);
      expect(styleOf(tester)?.fontFamily, 'monospace');
    });

    testWidgets('a vector is its header over its whole value in monospace', (tester) async {
      await tester.pumpWidget(
        _app(
          DetailCell(
            cell: classifyCell([1, 0.5, 0], vector: const VectorColumn(kind: 'dense', dtype: 'float32', dimension: 3)),
          ),
        ),
      );

      expect(find.text('dense float32, 3 dims\n[1.0,0.5,0.0]'), findsOneWidget);
      expect(styleOf(tester)?.fontFamily, 'monospace');
    });
  });
}
