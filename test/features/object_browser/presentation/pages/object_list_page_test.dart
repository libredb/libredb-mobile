@Tags(['widget'])
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/object_browser/domain/entities/database_object.dart';
import 'package:libredb_mobile/shared/models/provider_meta.dart';
import 'package:libredb_mobile/shared/models/studio_connection.dart';
import 'package:libredb_mobile/shared/widgets/local_filter_field.dart';
import 'package:libredb_mobile/shared/widgets/studio_error_banner.dart';
import 'package:libredb_mobile/shared/models/query_result.dart';
import 'package:libredb_mobile/features/object_browser/navigation/browse_navigation.dart';
import 'package:mocktail/mocktail.dart';

import '../../browse_answers.dart';
import '../../browse_harness.dart';
import '../../result_scroll.dart';

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
      ).thenAnswer((_) async => answeredResult(answer));

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

  testWidgets('a link to a page of the active connection opens that page, not the session default container', (
    tester,
  ) async {
    answerList(_postgres.id, ['public'], 'table', Success(objectsAnswer('list_postgres')));
    harness.active.select(_postgres);
    await harness.pump(tester, location: _tables);

    expect(harness.location, _tables);
    expect(find.text('orders'), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(harness.router.state.uri.path, '/browse', reason: 'the root the link built under it stays put');
    expect(find.text('public'), findsOneWidget);
  });

  testWidgets('a list that failed offline loads again by itself once the device is back online', (tester) async {
    var answers = 0;
    when(
      () => harness.repository.list(
        _postgres.id,
        container: ['public'],
        kind: 'table',
        refresh: any(named: 'refresh'),
      ),
    ).thenAnswer(
      (_) async => answers++ == 0
          ? Failure(NetworkError('offline', code: AppErrorCode.networkOffline.key))
          : answered(objectsAnswer('list_postgres')),
    );
    await harness.pump(tester, location: _tables, offline: true);
    expect(find.text('orders'), findsNothing);

    await harness.setOffline(tester, false);

    expect(answers, 2);
    expect(find.text('orders'), findsOneWidget);
  });

  testWidgets('back from a page opened by a link returns to the Browse root, with no query left over', (tester) async {
    answerList(_postgres.id, ['public'], 'table', Success(objectsAnswer('list_postgres')));
    await harness.pump(tester, location: _tables);
    expect(find.text('orders'), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(harness.router.state.uri.path, '/browse');
  });

  testWidgets('starts its heading at the page\'s start edge, as every Browse page does', (tester) async {
    answerList(_postgres.id, ['public'], 'table', Success(objectsAnswer('list_postgres')));
    await harness.pump(tester, location: _tables);

    expect(tester.getTopLeft(find.text('Tables')).dx, tester.getTopLeft(find.text('orders')).dx);
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

    testWidgets('are leaves: their child kinds show as text, and a tap opens the source, never a list of them', (
      tester,
    ) async {
      when(() => harness.repository.source(_oracle, path: ['APP', 'APP_ORDERS_PKG'], kind: 'package'))
          .thenAnswer((_) async => Success(sourceAnswer('handwritten/oracle/source_package')));
      await harness.pump(tester, location: _packages);

      expect(
        find.descendant(of: rowOf('APP_ORDERS_PKG'), matching: find.text('Procedures, Functions')),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.chevron_right), findsNothing);
      await tester.tap(find.text('APP_ORDERS_PKG'));
      await tester.pumpAndSettle();

      expect(harness.router.state.uri.path, '/browse/seed%3Aoracle/source/package');
      expect(harness.router.state.uri.queryParametersAll['path'], ['APP', 'APP_ORDERS_PKG']);
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

  testWidgets('any other status shows as Studio sends it, such as DB2\'s INOPERATIVE', (tester) async {
    answerList(
      _postgres.id,
      ['public'],
      'view',
      const Success([
        DatabaseObject(path: ['public', 'v_old'], name: 'v_old', kind: 'view', status: 'INOPERATIVE'),
      ]),
    );
    await harness.pump(tester, location: '/browse/seed%3Adev-postgres/objects/view?container=public');

    expect(find.descendant(of: rowOf('v_old'), matching: find.text('INOPERATIVE')), findsOneWidget);
  });

  testWidgets('a kind that declares attachedTo names the parent whatever its role, as a Couchbase index does', (
    tester,
  ) async {
    harness.answerMeta(
      'seed:couchbase',
      const ProviderMeta(
        queryLanguage: 'sql',
        schemaRefreshPattern: 'x',
        containerLevels: [ContainerLevel(id: 'scope', label: 'Scope', labelPlural: 'Scopes')],
        objectKinds: [
          ObjectKind(id: 'collection', role: 'relation', label: 'Collection', labelPlural: 'Collections'),
          ObjectKind(id: 'index', role: 'config', label: 'Index', labelPlural: 'Indexes', attachedTo: 'collection'),
        ],
      ),
    );
    answerList(
      'seed:couchbase',
      ['inventory'],
      'index',
      const Success([
        DatabaseObject(path: ['inventory', 'airline', 'idx_name'], name: 'idx_name', kind: 'index'),
      ]),
    );
    await harness.pump(tester, location: '/browse/seed%3Acouchbase/objects/index?container=inventory');

    expect(find.descendant(of: rowOf('idx_name'), matching: find.text('On airline')), findsOneWidget);
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

  group('tap rule', () {
    const function = DatabaseObject(path: ['public', 'order_total(integer)'], name: 'order_total', kind: 'function');

    setUp(() {
      answerList(_postgres.id, ['public'], 'function', const Success([function]));
      when(() => harness.repository.source(_postgres.id, path: function.path, kind: 'function'))
          .thenAnswer((_) async => Success(sourceAnswer('source_postgres_function')));
    });

    testWidgets('a kind with source and no columns opens the object\'s source by its path, and back returns here', (
      tester,
    ) async {
      await harness.pump(tester, location: '/browse/seed%3Adev-postgres/objects/function?container=public');

      await tester.tap(find.text('order_total'));
      await tester.pumpAndSettle();

      expect(harness.router.state.uri.path, '/browse/seed%3Adev-postgres/source/function');
      expect(harness.router.state.uri.queryParametersAll['path'], function.path);
      verify(() => harness.repository.source(_postgres.id, path: function.path, kind: 'function')).called(1);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(harness.location, '/browse/seed%3Adev-postgres/objects/function?container=public');
      expect(rowOf('order_total'), findsOneWidget);
    });

    testWidgets('a long press on a kind with source offers View source, which opens it', (tester) async {
      await harness.pump(tester, location: '/browse/seed%3Adev-postgres/objects/function?container=public');

      await tester.longPress(find.text('order_total'));
      await tester.pumpAndSettle();
      expect(find.text('Copy name'), findsOneWidget);
      expect(find.text('View rows'), findsNothing, reason: 'a routine never gets a SELECT');
      expect(find.text('Open in editor'), findsNothing, reason: 'a routine never gets a SELECT');
      await tester.tap(find.text('View source'));
      await tester.pumpAndSettle();

      expect(harness.router.state.uri.path, '/browse/seed%3Adev-postgres/source/function');
    });

    testWidgets('a kind with columns opens the object\'s detail by its path, even when it also has source', (
      tester,
    ) async {
      const view = DatabaseObject(path: ['public', 'v_orders'], name: 'v_orders', kind: 'view');
      answerList(_postgres.id, ['public'], 'view', const Success([view]));
      when(
        () => harness.repository.describe(
          _postgres.id,
          path: view.path,
          kind: 'view',
          refresh: any(named: 'refresh'),
        ),
      ).thenAnswer((_) async => answered(detailAnswer('describe_postgres_orders_readonly')));
      await harness.pump(tester, location: '/browse/seed%3Adev-postgres/objects/view?container=public');

      await tester.tap(find.text('v_orders'));
      await tester.pumpAndSettle();

      expect(harness.router.state.uri.path, '/browse/seed%3Adev-postgres/detail/view');
      expect(harness.router.state.uri.queryParametersAll['path'], view.path);
      verify(() => harness.repository.describe(_postgres.id, path: view.path, kind: 'view', refresh: false)).called(1);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(harness.location, '/browse/seed%3Adev-postgres/objects/view?container=public');

      await tester.longPress(find.text('v_orders'));
      await tester.pumpAndSettle();
      expect(find.text('Details'), findsOneWidget);
      expect(find.text('View source'), findsOneWidget);
      await tester.tap(find.text('Details'));
      await tester.pumpAndSettle();
      expect(harness.router.state.uri.path, '/browse/seed%3Adev-postgres/detail/view');
    });

    testWidgets('a kind with neither columns nor source opens nothing', (tester) async {
      harness.answerMeta(
        'seed:mssql',
        const ProviderMeta(
          queryLanguage: 'sql',
          schemaRefreshPattern: 'x',
          containerLevels: [ContainerLevel(id: 'schema', label: 'Schema', labelPlural: 'Schemas')],
          objectKinds: [ObjectKind(id: 'synonym', role: 'config', label: 'Synonym', labelPlural: 'Synonyms')],
        ),
      );
      answerList(
        'seed:mssql',
        ['dbo'],
        'synonym',
        const Success([
          DatabaseObject(path: ['dbo', 'syn'], name: 'syn', kind: 'synonym'),
        ]),
      );
      await harness.pump(tester, location: '/browse/seed%3Amssql/objects/synonym?container=dbo');

      expect(tester.widget<ListTile>(rowOf('syn')).onTap, isNull);
      await tester.longPress(find.text('syn'));
      await tester.pumpAndSettle();
      expect(find.text('View source'), findsNothing);
      expect(find.text('Details'), findsNothing);
    });
  });

  group('long press', () {
    testWidgets(
      'offers View rows, Details and Copy name on a table, which has columns and no source, and copies the name',
      (tester) async {
        final copied = <String>[];
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') copied.add((call.arguments as Map)['text'] as String);
          return null;
        });
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null),
        );
        answerList(_postgres.id, ['public'], 'table', Success(objectsAnswer('list_postgres')));
        await harness.pump(tester, location: _tables);

        await tester.longPress(find.text('orders'));
        await tester.pumpAndSettle();

        expect(find.text('Copy name'), findsOneWidget);
        expect(find.text('View source'), findsNothing);
        expect(find.text('Details'), findsOneWidget);
        expect(find.text('View rows'), findsOneWidget);
        expect(find.text('Open in editor'), findsOneWidget);

        await tester.tap(find.text('Copy name'));
        await tester.pumpAndSettle();

        expect(copied, ['orders']);
        expect(find.text('Name copied'), findsOneWidget);
        expect(find.text('Copy name'), findsNothing);
      },
    );

    testWidgets('shows all its entries at once on a phone held sideways', (tester) async {
      sideways(tester);
      answerList(_postgres.id, ['public'], 'table', Success(objectsAnswer('list_postgres')));
      await harness.pump(tester, location: _tables);
      await tester.ensureVisible(find.text('orders', skipOffstage: false));
      await tester.pumpAndSettle();

      await tester.longPress(find.text('orders'));
      await tester.pumpAndSettle();

      final shown = [
        'View rows',
        'Open in editor',
        'Details',
        'Copy name',
      ].where((entry) => find.text(entry).hitTestable().evaluate().isNotEmpty);
      expect(shown, hasLength(4), reason: 'shown: $shown');
    });
  });

  group('View rows', () {
    testWidgets('from the long press of a table opens its rows, and back returns to the list', (tester) async {
      answerList(_postgres.id, ['public'], 'table', Success(objectsAnswer('list_postgres')));
      when(
        () => harness.statements.run(
          _postgres.id,
          'SELECT * FROM public.orders;',
          queryId: any(named: 'queryId'),
          page: any(named: 'page'),
          catalog: any(named: 'catalog'),
          cancelSignal: any(named: 'cancelSignal'),
        ),
      ).thenAnswer(
        (_) async => const Success(QueryResult(fields: ['id'], rows: [], rowCount: 0, executionTime: Duration.zero)),
      );
      await harness.pump(tester, location: _tables);

      await tester.longPress(find.text('orders'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('View rows'));
      await tester.pumpAndSettle();

      expect(harness.router.state.name, BrowseRouteNames.rows);
      expect(harness.router.state.uri.queryParametersAll['path'], ['public', 'orders']);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(harness.location, _tables);
    });

    testWidgets('offline, the long press shows View rows disabled with the reason', (tester) async {
      answerList(_postgres.id, ['public'], 'table', Success(objectsAnswer('list_postgres')));
      await harness.pump(tester, location: _tables, offline: true);

      await tester.longPress(find.text('orders'));
      await tester.pumpAndSettle();

      expect(tester.widget<ListTile>(find.widgetWithText(ListTile, 'View rows')).enabled, isFalse);
      expect(find.text('Needs an internet connection'), findsOneWidget);
      expect(find.text('Copy name'), findsOneWidget);
    });

    testWidgets('a relation kind whose preview the app does not write shows it disabled and says why', (tester) async {
      const spark = 'seed:spark';
      harness.answerMeta(
        spark,
        const ProviderMeta(
          queryLanguage: 'sql',
          schemaRefreshPattern: '',
          identifierQuoting: 'backtick',
          spellsContainerNamesAsEngine: true,
          containerLevels: [ContainerLevel(id: 'schema', label: 'Namespace', labelPlural: 'Namespaces')],
          objectKinds: [
            ObjectKind(id: 'table', role: 'relation', label: 'Table', labelPlural: 'Tables', hasColumns: true),
          ],
        ),
      );
      answerList(
        spark,
        ['lake'],
        'table',
        const Success([
          DatabaseObject(path: ['lake', 'events'], name: 'events', kind: 'table'),
        ]),
      );
      await harness.pump(tester, location: '/browse/seed%3Aspark/objects/table?container=lake');

      await tester.longPress(find.text('events'));
      await tester.pumpAndSettle();

      expect(tester.widget<ListTile>(find.widgetWithText(ListTile, 'View rows')).enabled, isFalse);
      expect(find.text('Preview is not available for this engine yet'), findsOneWidget);
      expect(find.text('Open in editor'), findsNothing, reason: 'the generator writes no preview to open');
    });
  });

  group('Open in editor', () {
    testWidgets('offline, the long press still offers it enabled while View rows is disabled', (tester) async {
      answerList(_postgres.id, ['public'], 'table', Success(objectsAnswer('list_postgres')));
      await harness.pump(tester, location: _tables, offline: true);

      await tester.longPress(find.text('customers'));
      await tester.pumpAndSettle();

      expect(tester.widget<ListTile>(find.widgetWithText(ListTile, 'View rows')).enabled, isFalse);
      expect(tester.widget<ListTile>(find.widgetWithText(ListTile, 'Open in editor')).enabled, isTrue);
    });

    testWidgets('sits right under View rows in the long-press menu', (tester) async {
      answerList(_postgres.id, ['public'], 'table', Success(objectsAnswer('list_postgres')));
      await harness.pump(tester, location: _tables);

      await tester.longPress(find.text('customers'));
      await tester.pumpAndSettle();

      final titles = [
        for (final tile in tester.widgetList<ListTile>(find.byType(ListTile)))
          if (tile.title case Text(:final data?)) data,
      ];
      final viewRows = titles.indexOf('View rows');
      expect(viewRows, isNonNegative);
      expect(titles[viewRows + 1], 'Open in editor');
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

    testWidgets('a refresh that empties the kind drops the filter, so the objects that come back all show', (
      tester,
    ) async {
      answerList(_postgres.id, ['public'], 'table', const Success(cities));
      await harness.pump(tester, location: _tables);
      await filter(tester, 'ankara');
      expect(find.text('1 of 3 match'), findsOneWidget);

      answerList(_postgres.id, ['public'], 'table', const Success([]));
      await tester.fling(find.byType(ListView).last, const Offset(0, 400), 1000);
      await tester.pumpAndSettle();
      expect(find.text('Studio lists no objects of this kind here.'), findsOneWidget);

      answerList(_postgres.id, ['public'], 'table', const Success(cities));
      await tester.fling(find.byType(ListView).last, const Offset(0, 400), 1000);
      await tester.pumpAndSettle();

      expect(find.text('3 objects'), findsOneWidget);
      expect(rowOf('İstanbul'), findsOneWidget);
      expect(rowOf('ankara'), findsOneWidget);
      expect(rowOf('izmir_istanbul_route'), findsOneWidget);
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

    testWidgets('a refresh that empties the level drops the filter, so the containers that come back all show', (
      tester,
    ) async {
      harness.active.select(_server);
      await harness.pump(tester);
      await filter(tester, 'arch');

      harness.answerContainers(_server.id, null, const []);
      await tester.fling(find.byType(ListView).last, const Offset(0, 400), 1000);
      await tester.pumpAndSettle();
      expect(find.text('Studio lists nothing at this level.'), findsOneWidget);

      harness.answerContainers(_server.id, null, containersAnswer('containers_postgres_server'));
      await tester.fling(find.byType(ListView).last, const Offset(0, 400), 1000);
      await tester.pumpAndSettle();

      expect(find.text('app'), findsOneWidget);
      expect(find.text('archive'), findsOneWidget);
      expect(find.text('postgres'), findsOneWidget);
    });
  });
}
