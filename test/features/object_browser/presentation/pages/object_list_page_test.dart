@Tags(['widget'])
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/object_browser/domain/entities/database_object.dart';
import 'package:libredb_mobile/shared/models/studio_connection.dart';
import 'package:libredb_mobile/shared/widgets/local_filter_field.dart';
import 'package:libredb_mobile/shared/widgets/studio_error_banner.dart';
import 'package:mocktail/mocktail.dart';

import '../../browse_answers.dart';
import '../../browse_harness.dart';

const _postgres = StudioConnection(id: 'seed:dev-postgres', name: 'Dev (PostgreSQL)', type: 'postgres');
const _server = StudioConnection(id: 'seed:dev-postgres-server', name: 'Dev server', type: 'postgres');
const _oracle = 'seed:oracle';

const _tables = '/browse/seed%3Adev-postgres/objects/table?container=public';
const _packages = '/browse/seed%3Aoracle/objects/package?container=APP';

void main() {
  late BrowseHarness harness;

  setUp(() {
    harness = BrowseHarness();
    harness.answerMeta(_postgres.id, metaAnswer('meta_postgres'));
    harness.answerContainers(_postgres.id, null, containersAnswer('containers_postgres'));
    harness.answerCounts(_postgres.id, ['public'], countsAnswer('counts_postgres'));
    harness.answerMeta(_oracle, metaAnswer('handwritten/oracle/meta'));
  });

  void answerList(String connectionId, List<String> container, String kind, Result<List<DatabaseObject>> answer) =>
      when(
        () => harness.repository.list(
          connectionId,
          container: container,
          kind: kind,
          refresh: any(named: 'refresh'),
        ),
      ).thenAnswer((_) async => answer);

  /// The row of the object named [name].
  Finder rowOf(String name) => find.widgetWithText(ListTile, name);

  Future<void> filter(WidgetTester tester, String query) async {
    await tester.enterText(find.byType(LocalFilterField), query);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
  }

  testWidgets('a kind row of the kind screen opens its objects: heading, counts line and each row\'s size', (
    tester,
  ) async {
    answerList(_postgres.id, ['public'], 'table', Success(objectsAnswer('list_postgres')));
    harness.active.select(_postgres);
    await harness.pump(tester);
    expect(harness.location, '/browse/seed%3Adev-postgres/kinds?container=public');

    await tester.tap(find.text('Tables'));
    await tester.pumpAndSettle();

    expect(harness.location, _tables);
    expect(find.text('Tables'), findsOneWidget);
    expect(find.text('4 objects'), findsOneWidget);
    expect(find.descendant(of: rowOf('orders'), matching: find.text('48 KB')), findsOneWidget);
    expect(find.descendant(of: rowOf('customers'), matching: find.text('32 KB')), findsOneWidget);
    verify(() => harness.repository.list(_postgres.id, container: ['public'], kind: 'table', refresh: false)).called(1);
  });

  testWidgets('back from a page opened by a link returns to the Browse root, with no query left over', (tester) async {
    answerList(_postgres.id, ['public'], 'table', Success(objectsAnswer('list_postgres')));
    await harness.pump(tester, location: _tables);
    expect(find.text('orders'), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(harness.router.state.uri.path, '/browse');
  });

  testWidgets('shows the row count and the size together when Studio sends both', (tester) async {
    answerList(
      _postgres.id,
      ['public'],
      'table',
      const Success([
        DatabaseObject(path: ['public', 'orders'], name: 'orders', kind: 'table', rowCount: 12000, sizeBytes: 1835008),
        DatabaseObject(path: ['public', 'one'], name: 'one', kind: 'table', rowCount: 1),
      ]),
    );
    await harness.pump(tester, location: _tables);

    expect(find.descendant(of: rowOf('orders'), matching: find.text('12,000 rows · 1.8 MB')), findsOneWidget);
    expect(find.descendant(of: rowOf('one'), matching: find.text('1 row')), findsOneWidget);
  });

  testWidgets('shows name, never the last path segment, which may differ', (tester) async {
    answerList(
      _postgres.id,
      ['public'],
      'function',
      const Success([
        DatabaseObject(path: ['public', 'order_total(integer)'], name: 'order_total', kind: 'function'),
      ]),
    );
    await harness.pump(tester, location: '/browse/seed%3Adev-postgres/objects/function?container=public');

    expect(find.text('order_total'), findsOneWidget);
    expect(find.text('order_total(integer)'), findsNothing);
    expect(find.text('Functions'), findsOneWidget);
  });

  group('Oracle packages', () {
    setUp(() => answerList(_oracle, ['APP'], 'package', Success(objectsAnswer('handwritten/oracle/list_package'))));

    testWidgets('mark the package Studio sends as INVALID with a text badge, and no other', (tester) async {
      await harness.pump(tester, location: _packages);

      expect(find.descendant(of: rowOf('APP_BROKEN_PKG'), matching: find.text('Invalid')), findsOneWidget);
      expect(find.descendant(of: rowOf('APP_ORDERS_PKG'), matching: find.text('Invalid')), findsNothing);
    });

    testWidgets('are leaves: their child kinds show as text, and a tap pushes no list of them', (tester) async {
      await harness.pump(tester, location: _packages);

      expect(
        find.descendant(of: rowOf('APP_ORDERS_PKG'), matching: find.text('Procedures, Functions')),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.chevron_right), findsNothing);
      await tester.tap(find.text('APP_ORDERS_PKG'));
      await tester.pumpAndSettle();

      expect(harness.location, _packages);
      verifyNever(
        () => harness.repository.list(
          _oracle,
          container: any(named: 'container'),
          kind: 'procedure',
          refresh: false,
        ),
      );
      verifyNever(
        () => harness.repository.list(
          _oracle,
          container: any(named: 'container'),
          kind: 'function',
          refresh: false,
        ),
      );
    });
  });

  testWidgets('a DISABLED object carries its own text badge', (tester) async {
    answerList(
      _postgres.id,
      ['public'],
      'trigger',
      const Success([
        DatabaseObject(path: ['public', 'orders', 'audit'], name: 'audit', kind: 'trigger', status: 'DISABLED'),
      ]),
    );
    await harness.pump(tester, location: '/browse/seed%3Adev-postgres/objects/trigger?container=public');

    expect(find.descendant(of: rowOf('audit'), matching: find.text('Disabled')), findsOneWidget);
  });

  testWidgets('an attached object names its parent table as secondary text', (tester) async {
    answerList(
      _postgres.id,
      ['public'],
      'trigger',
      const Success([
        DatabaseObject(path: ['public', 'orders', 'orders_touch'], name: 'orders_touch', kind: 'trigger'),
      ]),
    );
    await harness.pump(tester, location: '/browse/seed%3Adev-postgres/objects/trigger?container=public');

    expect(find.descendant(of: rowOf('orders_touch'), matching: find.text('On orders')), findsOneWidget);
  });

  group('long press', () {
    testWidgets('offers Copy name only while no source or details screen exists, and copies the name', (tester) async {
      final copied = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') copied.add((call.arguments as Map)['text'] as String);
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
      answerList(_postgres.id, ['public'], 'table', Success(objectsAnswer('list_postgres')));
      await harness.pump(tester, location: _tables);

      await tester.longPress(find.text('orders'));
      await tester.pumpAndSettle();

      expect(find.text('Copy name'), findsOneWidget);
      expect(find.text('View source'), findsNothing);
      expect(find.text('Details'), findsNothing);
      expect(find.text('View rows'), findsNothing);

      await tester.tap(find.text('Copy name'));
      await tester.pumpAndSettle();

      expect(copied, ['orders']);
      expect(find.text('Name copied'), findsOneWidget);
      expect(find.text('Copy name'), findsNothing);
    });
  });

  group('counts line and filter', () {
    const cities = [
      DatabaseObject(path: ['public', 'İstanbul'], name: 'İstanbul', kind: 'table'),
      DatabaseObject(path: ['public', 'ankara'], name: 'ankara', kind: 'table'),
      DatabaseObject(path: ['public', 'izmir_istanbul_route'], name: 'izmir_istanbul_route', kind: 'table'),
    ];

    testWidgets('filtering istanbul finds İstanbul and says n of m match, without a request', (tester) async {
      answerList(_postgres.id, ['public'], 'table', const Success(cities));
      await harness.pump(tester, location: _tables);
      expect(find.text('3 objects'), findsOneWidget);

      await filter(tester, 'istanbul');

      expect(find.text('2 of 3 match'), findsOneWidget);
      expect(find.text('İstanbul'), findsOneWidget);
      expect(find.text('ankara'), findsNothing);
      verify(() => harness.repository.list(_postgres.id, container: ['public'], kind: 'table', refresh: false))
          .called(1);
      verifyNoMoreInteractions(harness.repository);
    });

    testWidgets('a filter that matches nothing says so', (tester) async {
      answerList(_postgres.id, ['public'], 'table', const Success(cities));
      await harness.pump(tester, location: _tables);

      await filter(tester, 'bursa');

      expect(find.text('0 of 3 match'), findsOneWidget);
      expect(find.text('Nothing matches the filter.'), findsOneWidget);
    });

    testWidgets('an empty kind says so in words, with no filter to type into', (tester) async {
      answerList(_postgres.id, ['public'], 'table', const Success([]));
      await harness.pump(tester, location: _tables);

      expect(find.text('Studio lists no objects of this kind here.'), findsOneWidget);
      expect(find.byType(LocalFilterField), findsNothing);
    });

    testWidgets('20,000 objects build only the rows on screen as they scroll, and the filter finds the last one', (
      tester,
    ) async {
      final many = [
        for (var i = 0; i < 20000; i++)
          DatabaseObject(path: ['public', 't$i'], name: 't${i.toString().padLeft(5, '0')}', kind: 'table'),
      ];
      answerList(_postgres.id, ['public'], 'table', Success(many));
      await harness.pump(tester, location: _tables);

      expect(find.text('20,000 objects'), findsOneWidget);
      expect(tester.widgetList(find.byType(ListTile)).length, lessThan(40));

      await tester.drag(find.byType(ListView).last, const Offset(0, -2000));
      await tester.pumpAndSettle();
      expect(find.text('t00000'), findsNothing);
      expect(tester.widgetList(find.byType(ListTile)).length, lessThan(40));

      await filter(tester, 't19999');
      expect(find.text('1 of 20,000 match'), findsOneWidget);
      expect(rowOf('t19999'), findsOneWidget);
    });
  });

  testWidgets('shows a failure in the Browse failure view, whose retry reads the list again', (tester) async {
    answerList(_postgres.id, ['public'], 'table', const Failure(ServerError('down')));
    await harness.pump(tester, location: _tables);
    expect(find.byType(StudioErrorBanner), findsOneWidget);

    answerList(_postgres.id, ['public'], 'table', Success(objectsAnswer('list_postgres')));
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.byType(StudioErrorBanner), findsNothing);
    expect(find.text('orders'), findsOneWidget);
  });

  group('container list filter', () {
    setUp(() {
      harness.answerMeta(_server.id, metaAnswer('meta_postgres_server'));
      harness.answerContainers(_server.id, null, containersAnswer('containers_postgres_server'));
    });

    testWidgets('narrows the level to the containers whose name matches', (tester) async {
      harness.active.select(_server);
      await harness.pump(tester);
      expect(find.text('archive'), findsOneWidget);

      await filter(tester, 'ARCH');

      expect(find.text('archive'), findsOneWidget);
      expect(find.text('app'), findsNothing);
      expect(find.text('postgres'), findsNothing);

      await filter(tester, 'zzz');
      expect(find.text('Nothing matches the filter.'), findsOneWidget);
    });
  });
}
