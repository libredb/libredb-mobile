@Tags(['widget'])
library;

import 'dart:io';

import 'package:flutter/material.dart';
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
import 'package:libredb_mobile/shared/widgets/result_view/result_card.dart';
import 'package:libredb_mobile/shared/widgets/result_view/result_view.dart';
import 'package:libredb_mobile/shared/widgets/result_view/result_view_bloc.dart';

final _policy = MaskingPolicy.forRole(const StudioUserRole());

QueryResult _result({
  List<String> fields = const ['id', 'name', 'city'],
  List<Map<String, Object?>>? rows,
  int? rowCount,
  Duration executionTime = const Duration(milliseconds: 3),
  List<QueryWarning> warnings = const [],
  bool wasLimited = false,
  bool rolledBack = false,
}) {
  final shown =
      rows ??
      const [
        {'id': 1, 'name': 'Alice', 'city': 'Izmir'},
        {'id': 2, 'name': 'Bob', 'city': 'Ankara'},
      ];
  return QueryResult(
    fields: fields,
    rows: shown,
    rowCount: rowCount ?? shown.length,
    executionTime: executionTime,
    warnings: warnings,
    pagination: QueryPagination(
      limit: 500,
      offset: 0,
      hasMore: false,
      totalReturned: shown.length,
      wasLimited: wasLimited,
    ),
    openTransactionRolledBack: rolledBack,
  );
}

Future<ResultViewBloc> _pump(
  WidgetTester tester,
  QueryResult result, {
  Locale locale = const Locale('en'),
  double textScale = 1,
  Size? screen,
}) async {
  if (screen != null) {
    tester.view.physicalSize = screen;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }
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
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
          child: Scaffold(
            appBar: screen == null ? null : AppBar(title: const Text('rows')),
            body: BlocProvider.value(value: bloc, child: const ResultView()),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return bloc;
}

Finder _inCard(int index, Finder finder) =>
    find.descendant(of: find.byKey(ValueKey('result-card-$index')), matching: finder);

void main() {
  group('card list', () {
    testWidgets('500 rows build only the cards on screen, and the last one scrolls into view', (tester) async {
      final rows = [
        for (var i = 0; i < 500; i++) {'id': i, 'name': 'person $i', 'city': 'city $i'},
      ];
      await _pump(tester, _result(rows: rows));

      final built = find.byType(ResultCard).evaluate().length;
      expect(built, greaterThan(0));
      expect(built, lessThan(30));

      await tester.scrollUntilVisible(
        find.text('person 499'),
        5000,
        scrollable: find.byType(Scrollable).last,
        maxScrolls: 100,
      );
      expect(find.text('person 499'), findsOneWidget);
      expect(find.byType(ResultCard).evaluate().length, lessThan(30));
    });

    testWidgets('a name field is the title, the id field under it, and the rest are preview fields', (tester) async {
      await _pump(tester, _result());

      expect(_inCard(0, find.text('Alice')), findsOneWidget);
      expect(_inCard(0, find.text('#1')), findsOneWidget);
      expect(_inCard(0, find.text('city')), findsOneWidget);
      expect(_inCard(0, find.text('Izmir')), findsOneWidget);
      expect(_inCard(0, find.text('name')), findsNothing);
      expect(_inCard(0, find.text('id')), findsNothing);
    });

    testWidgets('without an id field, the fields a card leaves out are counted', (tester) async {
      await _pump(
        tester,
        _result(
          fields: const ['name', 'a', 'b', 'c', 'd', 'e', 'f'],
          rows: const [
            {'name': 'Alice', 'a': 1, 'b': 2, 'c': 3, 'd': 4, 'e': 5, 'f': 6},
          ],
        ),
      );

      expect(_inCard(0, find.text('+2 more fields')), findsOneWidget);
    });

    testWidgets('a title that is also the id field is counted once', (tester) async {
      await _pump(
        tester,
        _result(
          fields: const ['id', 'a', 'b', 'c', 'd', 'e', 'f'],
          rows: const [
            {'id': 1, 'a': 2, 'b': 3, 'c': 4, 'd': 5, 'e': 6, 'f': 7},
          ],
        ),
      );

      expect(_inCard(0, find.text('1')), findsOneWidget);
      expect(_inCard(0, find.text('+2 more fields')), findsOneWidget);
    });

    testWidgets('a NULL title reads Row n', (tester) async {
      await _pump(
        tester,
        _result(
          rows: const [
            {'id': 1, 'name': 'Alice', 'city': 'Izmir'},
            {'id': 2, 'name': null, 'city': 'Ankara'},
          ],
        ),
      );

      expect(_inCard(1, find.text('Row 2')), findsOneWidget);
    });

    testWidgets('a row without the title field reads Row n too, in Turkish Satır n', (tester) async {
      await _pump(
        tester,
        _result(
          fields: const ['name', 'city'],
          rows: const [
            {'city': 'Izmir'},
          ],
        ),
        locale: const Locale('tr'),
      );

      expect(_inCard(0, find.text('Satır 1')), findsOneWidget);
    });

    testWidgets('query_types_postgres.json: big_value is the title and id the id field', (tester) async {
      final result = QueryResultJson.read(File('test/fixtures/studio/query_types_postgres.json').readAsStringSync());
      await _pump(tester, result);

      expect(_inCard(0, find.text('9007199254740993')), findsOneWidget);
      expect(_inCard(0, find.text('#1')), findsOneWidget);
      for (final field in ['small_value', 'numeric_value', 'real_value', 'double_value']) {
        expect(_inCard(0, find.text(field)), findsOneWidget, reason: field);
      }
      expect(_inCard(0, find.text('bool_value')), findsNothing);
      // 23 fields: the title, the id field and four previews are shown.
      expect(_inCard(0, find.text('+17 more fields')), findsOneWidget);
    });

    testWidgets('a NULL preview value is the NULL marker', (tester) async {
      await _pump(
        tester,
        _result(
          rows: const [
            {'id': 1, 'name': 'Alice', 'city': null},
          ],
        ),
      );

      expect(_inCard(0, find.text('NULL')), findsOneWidget);
    });

    testWidgets('cards grow with the system text size and do not overflow', (tester) async {
      await _pump(tester, _result());
      final normal = tester.getSize(find.byKey(const ValueKey('result-card-0'))).height;

      await _pump(tester, _result(), textScale: 2);
      final large = tester.getSize(find.byKey(const ValueKey('result-card-0'))).height;

      expect(large, greaterThan(normal * 1.5));
      expect(tester.takeException(), isNull);
    });
  });

  group('masked fields', () {
    const clearEmail = 'alice@example.com';
    const clearPassword = 'hunter2-hunter2';

    testWidgets('a masked preview field shows its mask and a lock, never the clear value', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        _result(
          fields: const ['id', 'name', 'password'],
          rows: const [
            {'id': 1, 'name': 'Alice', 'password': clearPassword},
          ],
        ),
      );

      expect(find.textContaining(clearPassword), findsNothing);
      expect(_inCard(0, find.text('password')), findsOneWidget);
      expect(_inCard(0, find.byIcon(Icons.lock_outline)), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('Masked value')), findsOneWidget);
      handle.dispose();
    });

    testWidgets('a masked title shows its mask and a lock, never the clear value', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        _result(
          fields: const ['id', 'email'],
          rows: const [
            {'id': 1, 'email': clearEmail},
          ],
        ),
      );

      expect(find.textContaining(clearEmail), findsNothing);
      expect(_inCard(0, find.byIcon(Icons.lock_outline)), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('Masked value')), findsOneWidget);
      handle.dispose();
    });

    testWidgets('a masked id field shows its mask and a lock, never the clear value', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        _result(
          fields: const ['name', 'national_id'],
          rows: const [
            {'name': 'Alice', 'national_id': '123-45-6789'},
          ],
        ),
      );

      expect(find.textContaining('123-45-6789'), findsNothing);
      expect(_inCard(0, find.textContaining('#')), findsOneWidget);
      expect(_inCard(0, find.byIcon(Icons.lock_outline)), findsOneWidget);
      final id = tester.widget<Text>(_inCard(0, find.textContaining('#')));
      expect(id.style?.fontStyle, FontStyle.italic);
      expect(find.bySemanticsLabel(RegExp('Masked value')), findsOneWidget);
      handle.dispose();
    });

    testWidgets('a masked field that is NULL has no lock, as nothing is hidden', (tester) async {
      await _pump(
        tester,
        _result(
          fields: const ['id', 'name', 'password'],
          rows: const [
            {'id': 1, 'name': 'Alice', 'password': null},
          ],
        ),
      );

      expect(find.byIcon(Icons.lock_outline), findsNothing);
    });

    testWidgets('the lock label is Turkish in Turkish', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        _result(
          fields: const ['id', 'name', 'password'],
          rows: const [
            {'id': 1, 'name': 'Alice', 'password': clearPassword},
          ],
        ),
        locale: const Locale('tr'),
      );

      expect(find.bySemanticsLabel(RegExp('Maskelenmiş değer')), findsOneWidget);
      handle.dispose();
    });
  });

  group('stats strip', () {
    testWidgets('the row count and execution time', (tester) async {
      await _pump(tester, _result(executionTime: const Duration(microseconds: 3250)));

      expect(find.text('2 rows, 3.25 ms'), findsOneWidget);
      expect(find.text('limited'), findsNothing);
      expect(find.byKey(const ValueKey('result-warnings-chip')), findsNothing);
      expect(find.byKey(const ValueKey('result-rolled-back')), findsNothing);
    });

    testWidgets('one row reads in the singular', (tester) async {
      await _pump(
        tester,
        _result(
          rows: const [
            {'id': 1, 'name': 'Alice', 'city': 'Izmir'},
          ],
        ),
      );

      expect(find.text('1 row, 3 ms'), findsOneWidget);
    });

    final many = [
      for (var i = 0; i < 1207; i++) {'id': i, 'name': 'n$i', 'city': 'c'},
    ];

    testWidgets('a count of 1207 reads 1,207 in English', (tester) async {
      await _pump(tester, _result(rows: many));

      expect(find.text('1,207 rows, 3 ms'), findsOneWidget);
    });

    testWidgets('a count of 1207 reads 1.207 in Turkish', (tester) async {
      await _pump(tester, _result(rows: many), locale: const Locale('tr'));

      expect(find.text('1.207 satır, 3 ms'), findsOneWidget);
    });

    testWidgets('warnings: a chip with their count, open on the list, which the chip shuts', (tester) async {
      await _pump(
        tester,
        _result(
          warnings: const [
            QueryWarning(message: 'Segment 3 is unavailable', code: 'W042', severity: 'WARNING'),
            QueryWarning(message: 'plain notice'),
            QueryWarning(message: '', code: '99'),
          ],
        ),
      );

      expect(find.text('3 warnings'), findsOneWidget);
      expect(find.text('WARNING: Segment 3 is unavailable'), findsOneWidget);
      expect(find.text('Code W042'), findsOneWidget);
      expect(find.text('plain notice'), findsOneWidget);
      expect(find.text('Warning'), findsOneWidget);
      expect(find.text('Code 99'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('result-warnings-chip')));
      await tester.pump();
      expect(find.text('plain notice'), findsNothing);
      expect(find.text('3 warnings'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('result-warnings-chip')));
      await tester.pump();
      expect(find.text('plain notice'), findsOneWidget);
    });

    testWidgets('one warning reads in the singular, in Turkish too', (tester) async {
      await _pump(
        tester,
        _result(warnings: const [QueryWarning(message: 'x')]),
        locale: const Locale('tr'),
      );

      expect(find.text('1 uyarı'), findsOneWidget);
    });

    testWidgets('limited: a chip whose notice is its semantics and its tooltip', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, _result(wasLimited: true));

      expect(find.text('limited'), findsOneWidget);
      const notice = 'Studio bounded this result. Anything beyond the bound is not in it.';
      expect(find.bySemanticsLabel(RegExp(RegExp.escape(notice))), findsWidgets);

      await tester.tap(find.text('limited'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text(notice), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      handle.dispose();
    });

    testWidgets('a rolled back transaction is a banner above the cards', (tester) async {
      await _pump(tester, _result(rolledBack: true));

      expect(find.byKey(const ValueKey('result-rolled-back')), findsOneWidget);
      expect(
        find.text('This statement left a transaction open, and Studio rolled it back, so its changes were discarded.'),
        findsOneWidget,
      );
      expect(find.byType(ResultCard), findsWidgets);
    });

    for (final (screen, scale) in const [(Size(360, 640), 2.0), (Size(800, 360), 2.0), (Size(360, 640), 3.0)]) {
      testWidgets('at ${screen.width.toInt()}x${screen.height.toInt()} and text scale $scale every notice is reachable '
          'and the cards keep room', (tester) async {
        final rows = [
          for (var i = 0; i < 50; i++) {'id': i, 'name': 'person $i', 'city': 'city $i'},
        ];
        await _pump(
          tester,
          _result(
            rows: rows,
            warnings: const [
              QueryWarning(message: 'Segment 3 is unavailable', code: 'W042', severity: 'WARNING'),
              QueryWarning(message: 'the last notice of the engine'),
            ],
            wasLimited: true,
            rolledBack: true,
          ),
          textScale: scale,
          screen: screen,
        );

        expect(tester.takeException(), isNull);
        final notices = find.byKey(const ValueKey('result-notices'));
        final body = tester.getRect(find.byType(ResultView));
        expect(tester.getSize(notices).height, lessThanOrEqualTo(body.height * 0.5));
        expect(find.byType(ResultCard), findsWidgets);

        final strip = find.descendant(of: notices, matching: find.byType(Scrollable)).first;
        for (final notice in [
          find.text('limited'),
          find.byKey(const ValueKey('result-warnings-chip')),
          find.text('the last notice of the engine'),
          find.byKey(const ValueKey('result-rolled-back')),
        ]) {
          await tester.scrollUntilVisible(notice, 40, scrollable: strip);
          final rect = tester.getRect(notice);
          final shown = tester.getRect(notices);
          expect(rect.top, greaterThanOrEqualTo(shown.top - 0.5));
          expect(rect.top, lessThan(shown.bottom));
        }
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('a replaced result is shown', (tester) async {
      final bloc = await _pump(tester, _result());

      bloc.add(
        ResultViewReplaced(
          maskResult(
            _result(
              rows: const [
                {'id': 9, 'name': 'Zed', 'city': 'Bursa'},
              ],
            ),
            _policy,
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Zed'), findsOneWidget);
      expect(find.text('Alice'), findsNothing);
    });
  });

  group('empty states', () {
    const warning = QueryWarning(message: 'every segment is unavailable', severity: 'WARNING');

    testWidgets('a write reads its affected rows', (tester) async {
      await _pump(tester, _result(fields: const [], rows: const [], rowCount: 1207));

      expect(find.text('1,207 rows affected'), findsOneWidget);
      expect(find.text('Query returned no data'), findsNothing);
    });

    testWidgets('a write of one row reads in the singular, in Turkish too', (tester) async {
      await _pump(
        tester,
        _result(fields: const [], rows: const [], rowCount: 1),
        locale: const Locale('tr'),
      );

      expect(find.text('1 satır etkilendi'), findsOneWidget);
    });

    testWidgets('a bounded empty answer says it was cut before its first row', (tester) async {
      await _pump(tester, _result(rows: const [], wasLimited: true));

      expect(find.text('No row is shown: the result was cut before its first row'), findsOneWidget);
      expect(find.text('Query returned no data'), findsNothing);
    });

    testWidgets('any other empty answer has no rows', (tester) async {
      await _pump(tester, _result(rows: const []));

      expect(find.text('Query returned no data'), findsOneWidget);
      expect(find.text('The engine reported:'), findsNothing);
    });

    testWidgets('a zero count with no fields is no data, not affected rows', (tester) async {
      await _pump(tester, _result(fields: const [], rows: const [], rowCount: 0));

      expect(find.text('Query returned no data'), findsOneWidget);
    });

    for (final (name, result) in [
      ('affected rows', _result(fields: const [], rows: const [], rowCount: 3, warnings: const [warning])),
      ('bounded empty', _result(rows: const [], wasLimited: true, warnings: const [warning])),
      ('plain empty', _result(rows: const [], warnings: const [warning])),
    ]) {
      testWidgets('$name shows its warnings outright', (tester) async {
        await _pump(tester, result);

        expect(find.text('The engine reported:'), findsOneWidget);
        expect(find.text('WARNING: every segment is unavailable'), findsOneWidget);
        expect(find.byKey(const ValueKey('result-warnings-chip')), findsNothing);
      });
    }

    testWidgets('an empty answer keeps the rollback notice', (tester) async {
      await _pump(tester, _result(rows: const [], rolledBack: true));

      expect(find.byKey(const ValueKey('result-rolled-back')), findsOneWidget);
      expect(find.text('Query returned no data'), findsOneWidget);
    });

    testWidgets('the empty states read in Turkish', (tester) async {
      await _pump(tester, _result(rows: const [], wasLimited: true), locale: const Locale('tr'));

      expect(find.text('Hiçbir satır gösterilmiyor: sonuç ilk satırından önce kesildi'), findsOneWidget);
    });
  });
}
