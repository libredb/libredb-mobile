@Tags(['widget'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/infrastructure/studio/query_result_json.dart';
import 'package:libredb_mobile/shared/models/query_page.dart';
import 'package:libredb_mobile/shared/models/query_result.dart';
import 'package:libredb_mobile/shared/models/studio_identity.dart';
import 'package:libredb_mobile/shared/security/result_masking/mask_result.dart';
import 'package:libredb_mobile/shared/security/result_masking/masking_policy.dart';
import 'package:libredb_mobile/shared/utils/sensitive_clipboard.dart';
import 'package:libredb_mobile/shared/widgets/result_view/result_view.dart';
import 'package:libredb_mobile/shared/widgets/result_view/result_view_bloc.dart';
import 'package:libredb_mobile/shared/widgets/result_view/row_detail_sheet.dart';

final _policy = MaskingPolicy.forRole(const StudioUserRole());

const _clearEmail = 'alice@example.com';

QueryResult _result({
  List<String> fields = const ['id', 'name', 'email', 'score', 'note'],
  List<Map<String, Object?>>? rows,
  Map<String, String> columnTypes = const {'id': 'integer', 'name': 'text', 'email': 'text', 'score': 'numeric'},
}) {
  final shown =
      rows ??
      const [
        {'id': 1, 'name': 'Alice', 'email': _clearEmail, 'score': 1.5, 'note': null},
        {'id': 2, 'name': 'Bob', 'email': null, 'score': 7, 'note': 'second'},
        {'id': 3, 'name': 'Carol', 'email': 'carol@example.com', 'score': 0, 'note': 'third'},
      ];
  return QueryResult(
    fields: fields,
    rows: shown,
    rowCount: shown.length,
    executionTime: const Duration(milliseconds: 2),
    columnTypes: columnTypes,
    pagination: QueryPagination(limit: 500, offset: 0, hasMore: true, totalReturned: shown.length, wasLimited: false),
  );
}

QueryResult _postgresTypes() =>
    QueryResultJson.read(File('test/fixtures/studio/query_types_postgres.json').readAsStringSync());

/// The texts the fake platform clipboard channel received, in order.
final _copied = <String>[];
final _calls = <MethodCall>[];

void _fakeClipboard({PlatformException? failure}) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
    SensitiveClipboard.channel,
    (call) async {
      _calls.add(call);
      if (failure != null) throw failure;
      _copied.add((call.arguments as Map)['text'] as String);
      return null;
    },
  );
}

Future<ResultViewBloc> _pump(WidgetTester tester, QueryResult result, {Locale locale = const Locale('en')}) async {
  final bloc = ResultViewBloc(masked: maskResult(result, _policy), policy: _policy);
  addTearDown(bloc.close);
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
        body: BlocProvider.value(value: bloc, child: const ResultView()),
      ),
    ),
  );
  await tester.pump();
  return bloc;
}

Future<void> _openRow(WidgetTester tester, int index) async {
  await tester.tap(find.byKey(ValueKey('result-card-$index')));
  await tester.pumpAndSettle();
}

Finder _inSheet(Finder finder) => find.descendant(of: find.byType(RowDetailSheet), matching: finder);

/// The vertical list of the row on screen.
Finder _fieldList() => find
    .descendant(
      of: find.byKey(const ValueKey('row-pages')),
      matching: find.byWidgetPredicate((widget) => widget is Scrollable && widget.axisDirection == AxisDirection.down),
    )
    .first;

Finder _field(String field) => find.byKey(ValueKey('row-field-$field'));

Future<void> _copyField(WidgetTester tester, String field) async {
  await tester.tap(find.descendant(of: _field(field), matching: find.byIcon(Icons.copy)));
  await tester.pumpAndSettle();
}

Future<void> _copyRow(WidgetTester tester) async {
  await tester.tap(_inSheet(find.byKey(const ValueKey('row-copy-json'))));
  await tester.pumpAndSettle();
}

Future<void> _swipe(WidgetTester tester, {required bool toNext}) async {
  await tester.fling(find.byKey(const ValueKey('row-pages')), Offset(toNext ? -600 : 600, 0), 2000);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    _copied.clear();
    _calls.clear();
    _fakeClipboard();
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      SensitiveClipboard.channel,
      null,
    );
  });

  group('the sheet', () {
    testWidgets('a tap on a card opens its row: every field with its declared type and detail form', (tester) async {
      await _pump(tester, _result());
      await _openRow(tester, 1);

      expect(find.byType(RowDetailSheet), findsOneWidget);
      expect(_inSheet(find.text('Row 2 of 3')), findsOneWidget);
      for (final field in ['id', 'name', 'email', 'score', 'note']) {
        expect(_field(field), findsOneWidget, reason: field);
      }
      expect(find.descendant(of: _field('id'), matching: find.text('integer')), findsOneWidget);
      expect(find.descendant(of: _field('score'), matching: find.text('numeric')), findsOneWidget);
      expect(find.descendant(of: _field('name'), matching: find.text('Bob')), findsOneWidget);
      expect(find.descendant(of: _field('email'), matching: find.text('null')), findsOneWidget);
      expect(find.descendant(of: _field('note'), matching: find.text('second')), findsOneWidget);
    });

    testWidgets('it is a full-height modal sheet over the page', (tester) async {
      await _pump(tester, _result());
      await _openRow(tester, 0);

      final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
      expect(tester.getSize(find.byType(RowDetailSheet)).height, greaterThan(screen.height * 0.9));
      expect(find.byType(ResultView), findsOneWidget);
    });

    testWidgets('values are selectable', (tester) async {
      await _pump(tester, _result());
      await _openRow(tester, 0);

      expect(find.descendant(of: _field('name'), matching: find.byType(SelectableText)), findsOneWidget);
    });

    testWidgets('a JSON value is pretty-printed and a binary value is its full hex', (tester) async {
      await _pump(tester, _postgresTypes());
      await _openRow(tester, 0);

      await tester.scrollUntilVisible(_field('jsonb_value'), 200, scrollable: _fieldList());
      expect(
        find.descendant(of: _field('jsonb_value'), matching: find.text('{\n  "b": {\n    "c": true\n  }\n}')),
        findsOneWidget,
      );
      expect(find.descendant(of: _field('jsonb_value'), matching: find.text('jsonb')), findsOneWidget);
      await tester.scrollUntilVisible(_field('bytea_value'), 200, scrollable: _fieldList());
      expect(find.descendant(of: _field('bytea_value'), matching: find.text(r'\xdeadbeef')), findsOneWidget);
    });

    testWidgets('a field without a declared type shows no type line', (tester) async {
      await _pump(tester, _result());
      await _openRow(tester, 0);

      final texts = tester.widgetList<Text>(find.descendant(of: _field('note'), matching: find.byType(Text)));
      expect(texts.map((text) => text.data), isNot(contains('text')));
    });

    testWidgets('a masked field shows its mask and a lock, never the clear value', (tester) async {
      final handle = tester.ensureSemantics();
      final masked = maskResult(_result(), _policy).result.rows.first['email']! as String;
      await _pump(tester, _result());
      await _openRow(tester, 0);

      expect(find.textContaining(_clearEmail), findsNothing);
      expect(find.descendant(of: _field('email'), matching: find.text(masked)), findsOneWidget);
      expect(find.descendant(of: _field('email'), matching: find.byIcon(Icons.lock_outline)), findsOneWidget);
      expect(find.descendant(of: _field('name'), matching: find.byIcon(Icons.lock_outline)), findsNothing);
      handle.dispose();
    });
  });

  group('copy of a field', () {
    testWidgets('the copy icon writes the field through the sensitive clipboard and says so', (tester) async {
      await _pump(tester, _result());
      await _openRow(tester, 0);

      await _copyField(tester, 'name');

      expect(_copied, ['Alice']);
      expect(_calls.single.method, 'copy');
      expect((_calls.single.arguments as Map)['sensitive'], isTrue);
      expect(_inSheet(find.text('Copied')), findsOneWidget);
    });

    testWidgets('a long press on the field copies it too', (tester) async {
      await _pump(tester, _result());
      await _openRow(tester, 0);

      await tester.longPress(
        find.descendant(of: _field('note'), matching: find.byKey(const ValueKey('row-field-label'))),
      );
      await tester.pumpAndSettle();

      expect(_copied, ['null']);
    });

    testWidgets('a masked email copies as its mask', (tester) async {
      final masked = maskResult(_result(), _policy).result.rows.first['email']! as String;
      await _pump(tester, _result());
      await _openRow(tester, 0);

      await _copyField(tester, 'email');

      expect(_copied, [masked]);
      expect(_copied.single, isNot(contains('alice@')));
    });

    testWidgets('NULL copies as null, and a field the row lacks as NULL', (tester) async {
      await _pump(
        tester,
        _result(
          fields: const ['name', 'note', 'missing'],
          rows: const [
            {'name': 'Alice', 'note': null},
          ],
        ),
      );
      await _openRow(tester, 0);

      await _copyField(tester, 'note');
      await _copyField(tester, 'missing');

      expect(_copied, ['null', 'NULL']);
    });

    testWidgets('query_types_postgres.json: bytea copies as \\xdeadbeef and big_value with every digit', (
      tester,
    ) async {
      await _pump(tester, _postgresTypes());
      await _openRow(tester, 0);

      await _copyField(tester, 'big_value');
      await tester.scrollUntilVisible(_field('bytea_value'), 200, scrollable: _fieldList());
      await _copyField(tester, 'bytea_value');

      expect(_copied, ['9007199254740993', r'\xdeadbeef']);
    });

    testWidgets('a JSON field copies its pretty form', (tester) async {
      await _pump(tester, _postgresTypes());
      await _openRow(tester, 0);

      await tester.scrollUntilVisible(_field('json_value'), 200, scrollable: _fieldList());
      await _copyField(tester, 'json_value');

      expect(_copied, ['{\n  "a": [\n    1,\n    2\n  ]\n}']);
    });

    testWidgets('a failed copy says so with its code inside the sheet', (tester) async {
      _fakeClipboard(failure: PlatformException(code: 'clipboard_unavailable'));
      await _pump(tester, _result());
      await _openRow(tester, 0);

      await _copyField(tester, 'name');

      expect(_inSheet(find.text('Could not copy (clipboard_unavailable)')), findsOneWidget);
      expect(_inSheet(find.text('Copied')), findsNothing);
    });

    testWidgets('a build without the native side says the copy failed', (tester) async {
      // A mock handler that throws MissingPluginException answers as a channel nobody registered does.
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        SensitiveClipboard.channel,
        (call) async => throw MissingPluginException(),
      );
      await _pump(tester, _result());
      await _openRow(tester, 0);

      await _copyField(tester, 'name');

      expect(_inSheet(find.text('Could not copy (MissingPluginException)')), findsOneWidget);
    });
  });

  group('a mask that reads as JSON', () {
    // A custom mask is free text; one that parses as JSON stays the text it is, never a document.
    final result = _result(
      fields: const ['name', 'secret'],
      rows: const [
        {'name': 'Alice', 'secret': '{"a":1}'},
      ],
      columnTypes: const {},
    );

    test('copies as its text', () {
      expect(fieldCopyText(result, const {'secret'}, 0, 'secret'), '{"a":1}');
      expect(fieldCopyText(result, const {}, 0, 'secret'), '{\n  "a": 1\n}');
    });

    testWidgets('shows as its text with a lock', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [S.delegate, GlobalMaterialLocalizations.delegate],
          supportedLocales: S.delegate.supportedLocales,
          home: Scaffold(
            body: RowDetailSheet(result: result, maskedColumns: const {'secret'}, initialIndex: 0),
          ),
        ),
      );

      expect(find.descendant(of: _field('secret'), matching: find.text('{"a":1}')), findsOneWidget);
      expect(find.descendant(of: _field('secret'), matching: find.byIcon(Icons.lock_outline)), findsOneWidget);
    });
  });

  group('Copy row', () {
    testWidgets('writes masked fields as their masks and keeps a number a JSON number', (tester) async {
      final masked = maskResult(_result(), _policy).result.rows.first['email']! as String;
      await _pump(tester, _result());
      await _openRow(tester, 0);

      await _copyRow(tester);

      expect(_copied, hasLength(1));
      expect(_copied.single, isNot(contains('alice@')));
      expect(_copied.single, contains('\n  "id": 1,\n'));
      final decoded = jsonDecode(_copied.single) as Map<String, Object?>;
      expect(decoded, {'id': 1, 'name': 'Alice', 'email': masked, 'score': 1.5, 'note': null});
      expect(_inSheet(find.text('Copied')), findsOneWidget);
    });

    testWidgets('query_types_postgres.json: bytea as the \\xdeadbeef string, big_value with every digit', (
      tester,
    ) async {
      await _pump(tester, _postgresTypes());
      await _openRow(tester, 0);

      await _copyRow(tester);

      expect(_copied.single, contains('  "bytea_value": "\\\\xdeadbeef",\n'));
      expect(_copied.single, contains('  "big_value": "9007199254740993",\n'));
      expect(_copied.single, contains('  "null_value": null\n'));
    });

    testWidgets('copies the row on screen after a swipe', (tester) async {
      await _pump(tester, _result());
      await _openRow(tester, 0);
      await _swipe(tester, toNext: true);

      await _copyRow(tester);

      expect((jsonDecode(_copied.single) as Map)['name'], 'Bob');
    });
  });

  group('swipe', () {
    testWidgets('a swipe shows the next row, and a swipe back the previous one', (tester) async {
      await _pump(tester, _result());
      await _openRow(tester, 0);

      await _swipe(tester, toNext: true);
      expect(_inSheet(find.text('Row 2 of 3')), findsOneWidget);
      expect(find.descendant(of: _field('name'), matching: find.text('Bob')), findsOneWidget);

      await _swipe(tester, toNext: false);
      expect(_inSheet(find.text('Row 1 of 3')), findsOneWidget);
      expect(find.descendant(of: _field('name'), matching: find.text('Alice')), findsOneWidget);
    });

    testWidgets('past the last loaded row nothing changes and nothing is asked for', (tester) async {
      final bloc = await _pump(tester, _result());
      final before = bloc.state;
      await _openRow(tester, 2);

      await _swipe(tester, toNext: true);

      expect(_inSheet(find.text('Row 3 of 3')), findsOneWidget);
      expect(find.descendant(of: _field('name'), matching: find.text('Carol')), findsOneWidget);
      expect(bloc.state, same(before));
      expect(_calls, isEmpty);
      expect(tester.takeException(), isNull);
    });

    testWidgets('before the first row nothing changes', (tester) async {
      final bloc = await _pump(tester, _result());
      final before = bloc.state;
      await _openRow(tester, 0);

      await _swipe(tester, toNext: false);

      expect(_inSheet(find.text('Row 1 of 3')), findsOneWidget);
      expect(find.descendant(of: _field('name'), matching: find.text('Alice')), findsOneWidget);
      expect(bloc.state, same(before));
      expect(_calls, isEmpty);
    });
  });

  group('long press on a card field', () {
    Future<void> openMenu(WidgetTester tester, String field) async {
      await tester.longPress(
        find.descendant(
          of: find.byKey(const ValueKey('result-card-0')),
          matching: find.byKey(ValueKey('card-field-$field')),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('offers Copy value and Copy row as JSON, and opens no sheet', (tester) async {
      await _pump(tester, _result());

      await openMenu(tester, 'score');

      expect(find.text('Copy value'), findsOneWidget);
      expect(find.text('Copy row as JSON'), findsOneWidget);
      expect(find.byType(RowDetailSheet), findsNothing);
    });

    testWidgets('Copy value writes the field', (tester) async {
      await _pump(tester, _result());

      await openMenu(tester, 'score');
      await tester.tap(find.text('Copy value'));
      await tester.pumpAndSettle();

      expect(_copied, ['1.5']);
      expect(find.text('Copied'), findsOneWidget);
    });

    testWidgets('Copy value of a masked field writes its mask', (tester) async {
      final masked = maskResult(_result(), _policy).result.rows.first['email']! as String;
      await _pump(tester, _result());

      await openMenu(tester, 'email');
      await tester.tap(find.text('Copy value'));
      await tester.pumpAndSettle();

      expect(_copied, [masked]);
    });

    testWidgets('Copy row as JSON writes the row as the sheet does', (tester) async {
      await _pump(tester, _result());

      await openMenu(tester, 'name');
      await tester.tap(find.text('Copy row as JSON'));
      await tester.pumpAndSettle();

      expect((jsonDecode(_copied.single) as Map)['id'], 1);
    });

    testWidgets('the title and the id line take a long press too', (tester) async {
      await _pump(tester, _result());

      await openMenu(tester, 'name');
      await tester.tap(find.text('Copy value'));
      await tester.pumpAndSettle();
      await openMenu(tester, 'id');
      await tester.tap(find.text('Copy value'));
      await tester.pumpAndSettle();

      expect(_copied, ['Alice', '1']);
    });

    testWidgets('a failed copy from the menu says so', (tester) async {
      _fakeClipboard(failure: PlatformException(code: 'clipboard_unavailable'));
      await _pump(tester, _result());

      await openMenu(tester, 'score');
      await tester.tap(find.text('Copy value'));
      await tester.pumpAndSettle();

      expect(find.text('Could not copy (clipboard_unavailable)'), findsOneWidget);
    });
  });

  testWidgets('the sheet and the menu read in Turkish', (tester) async {
    await _pump(tester, _result(), locale: const Locale('tr'));

    await tester.longPress(
      find.descendant(
        of: find.byKey(const ValueKey('result-card-0')),
        matching: find.byKey(const ValueKey('card-field-score')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Değeri kopyala'), findsOneWidget);
    expect(find.text('Satırı JSON olarak kopyala'), findsOneWidget);
    await tester.tap(find.text('Değeri kopyala'));
    await tester.pumpAndSettle();
    expect(find.text('Kopyalandı'), findsOneWidget);

    await _openRow(tester, 0);
    expect(_inSheet(find.text('Satır 1 / 3')), findsOneWidget);
  });
}
