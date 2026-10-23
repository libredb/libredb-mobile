@Tags(['widget'])
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/shared/models/query_result.dart';
import 'package:libredb_mobile/shared/widgets/result_view/result_table.dart';

// Real fonts, so that a width depends on the characters: this file's isolate draws 'monospace' in Roboto Condensed, a
// proportional face, as a platform whose 'monospace' is not fixed width would, and the theme's Roboto in Roboto.
// The fonts stay registered for this isolate only, which is why these tests have a file of their own.

String get _materialFonts {
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root == null) throw StateError('FLUTTER_ROOT is not set. Run this test with flutter test.');
  return '$root/bin/cache/artifacts/material_fonts';
}

Future<void> _load(String family, List<String> files) async {
  final loader = FontLoader(family);
  for (final file in files) {
    final bytes = File('$_materialFonts/$file').readAsBytesSync();
    loader.addFont(Future.value(ByteData.sublistView(bytes)));
  }
  await loader.load();
}

/// Text above 12 px at its size, and smaller text three times as large: a nonlinear scaler, as Android 14 applies.
class _SmallTextLarger implements TextScaler {
  const _SmallTextLarger();

  @override
  double scale(double fontSize) => fontSize < 12 ? fontSize * 3 : fontSize;

  @override
  // ignore: deprecated_member_use
  double get textScaleFactor => 1;

  @override
  TextScaler clamp({double minScaleFactor = 0, double maxScaleFactor = double.infinity}) => this;
}

Future<void> _pump(
  WidgetTester tester,
  QueryResult result, {
  Set<String> maskedColumns = const {},
  TextScaler? textScaler,
}) async {
  tester.view.physicalSize = const Size(4000, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: const [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: S.delegate.supportedLocales,
      builder: (context, child) => textScaler == null
          ? child!
          : MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: textScaler),
              child: child!,
            ),
      home: Scaffold(
        body: ResultTable(result: result, maskedColumns: maskedColumns),
      ),
    ),
  );
}

/// Expects [text] to show whole in its cell, as a [TextPainter] of its rendered style lays it out.
void _expectWhole(WidgetTester tester, Finder text) {
  final paragraph = tester.renderObject<RenderParagraph>(
    find.descendant(of: text, matching: find.byType(RichText), matchRoot: true),
  );
  final painter = TextPainter(
    text: paragraph.text,
    textDirection: paragraph.textDirection,
    textScaler: paragraph.textScaler,
    maxLines: 1,
  )..layout();
  addTearDown(painter.dispose);
  final reason = paragraph.text.toPlainText();
  expect(paragraph.didExceedMaxLines, isFalse, reason: reason);
  expect(painter.width, lessThanOrEqualTo(paragraph.size.width), reason: reason);
}

Finder _cell(String text) => find.descendant(of: find.byKey(const ValueKey('result-row-0')), matching: find.text(text));

void main() {
  setUpAll(() async {
    await _load('monospace', ['RobotoCondensed-Regular.ttf', 'RobotoCondensed-Italic.ttf']);
    await _load('Roboto', ['Roboto-Regular.ttf', 'Roboto-Italic.ttf']);
  });

  testWidgets('a value of wide characters in a proportional cell font shows whole', (tester) async {
    await _pump(
      tester,
      QueryResult(
        fields: const ['code'],
        rows: const [
          {'code': 'WWWWWWWWWWWW'},
          {'code': '111111111111'},
        ],
        rowCount: 2,
        executionTime: Duration.zero,
      ),
    );

    _expectWhole(tester, _cell('WWWWWWWWWWWW'));
  });

  testWidgets("a masked column's value shows whole in the proportional italic it is drawn in", (tester) async {
    await _pump(
      tester,
      QueryResult(
        fields: const ['secret'],
        rows: const [
          {'secret': 'MMMMMMMMMMMM'},
        ],
        rowCount: 1,
        executionTime: Duration.zero,
      ),
      maskedColumns: const {'secret'},
    );

    _expectWhole(tester, _cell('MMMMMMMMMMMM'));
  });

  testWidgets('a nonlinear text scaler scales the declared type at its own 11 px size', (tester) async {
    await _pump(
      tester,
      QueryResult(
        fields: const ['id'],
        rows: const [
          {'id': 1},
        ],
        rowCount: 1,
        executionTime: Duration.zero,
        columnTypes: const {'id': 'integer'},
      ),
      textScaler: const _SmallTextLarger(),
    );

    _expectWhole(tester, find.byKey(const ValueKey('result-column-type-id')));
    _expectWhole(
      tester,
      find.descendant(of: find.byKey(const ValueKey('result-header-id')), matching: find.text('id')),
    );
  });
}
