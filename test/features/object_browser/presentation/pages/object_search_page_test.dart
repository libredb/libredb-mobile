@Tags(['widget'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/object_browser/application/object_search_bloc.dart';
import 'package:libredb_mobile/features/object_browser/domain/entities/database_object.dart';
import 'package:libredb_mobile/shared/models/provider_meta.dart';
import 'package:libredb_mobile/shared/models/studio_connection.dart';
import 'package:libredb_mobile/shared/widgets/studio_error_banner.dart';
import 'package:libredb_mobile/shared/models/query_result.dart';
import 'package:mocktail/mocktail.dart';

import '../../browse_answers.dart';
import '../../browse_harness.dart';

const _postgres = StudioConnection(id: 'seed:dev-postgres', name: 'Dev (PostgreSQL)', type: 'postgres');
const _server = 'seed:dev-postgres-server';
const _search = '/browse/seed%3Adev-postgres/search';
const _sample = StudioConnection(id: 'seed:sample', name: 'Sample (SQLite)', type: 'sqlite');

void main() {
  late BrowseHarness harness;

  setUp(() {
    harness = BrowseHarness();
    harness.answerMeta(_postgres.id, metaAnswer('meta_postgres'));
    harness.answerContainers(_postgres.id, null, containersAnswer('containers_postgres'));
    harness.answerCounts(_postgres.id, ['public'], countsAnswer('counts_postgres'));
    harness.answerMeta(_server, metaAnswer('meta_postgres_server'));
  });

  void answerSearch(String connectionId, Result<List<DatabaseObject>> answer) => when(
    () => harness.repository.search(
      connectionId,
      term: any(named: 'term'),
      kinds: any(named: 'kinds'),
    ),
  ).thenAnswer((_) async => answer);

  void verifyNoSearch() => verifyNever(
    () => harness.repository.search(
      any(),
      term: any(named: 'term'),
      kinds: any(named: 'kinds'),
    ),
  );

  Finder field() => find.byKey(const ValueKey('object-search-field'));

  /// A screen tall enough to hold every match of search_postgres.json.
  void tallScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(2400, 4800);
    addTearDown(tester.view.resetPhysicalSize);
  }

  /// Types [term] and lets the search's pause pass.
  Future<void> type(WidgetTester tester, String term) async {
    await tester.enterText(field(), term);
    await tester.pump(ObjectSearchBloc.debounce);
    await tester.pumpAndSettle();
  }

  testWidgets('the search action in the heading row of /browse opens the search, whose hint is the engine\'s', (
    tester,
  ) async {
    harness.active.select(_postgres);
    await harness.pump(tester);
    // The first entry opens the session default schema; back is the root, whose heading carries the action.
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(harness.router.state.uri.path, '/browse');

    await tester.tap(find.byTooltip('Search objects'));
    await tester.pumpAndSettle();

    expect(harness.location, _search);
    expect(find.widgetWithText(TextField, 'Search tables or columns...'), findsOneWidget);
    verifyNoSearch();
  });

  testWidgets('on an engine with no container level the kinds at /browse carry the search action', (tester) async {
    harness.answerMeta(_sample.id, metaAnswer('meta'));
    harness.answerCounts(_sample.id, const [], countsAnswer('counts'));
    harness.active.select(_sample);
    await harness.pump(tester);
    expect(harness.location, '/browse');

    await tester.tap(find.byTooltip('Search objects'));
    await tester.pumpAndSettle();

    expect(harness.location, '/browse/seed%3Asample/search');
    expect(field(), findsOneWidget);
  });

  testWidgets('the pages under /browse carry no search action', (tester) async {
    harness.active.select(_postgres);
    await harness.pump(tester);
    expect(harness.location, '/browse/seed%3Adev-postgres/kinds?container=public');

    expect(find.byTooltip('Search objects'), findsNothing);
  });

  testWidgets('uses the app\'s own hint when the engine names none', (tester) async {
    harness.answerMeta(
      _postgres.id,
      const ProviderMeta(queryLanguage: 'sql', schemaRefreshPattern: 'x', containerLevels: [], objectKinds: []),
    );
    await harness.pump(tester, location: _search);

    expect(find.widgetWithText(TextField, 'Search by name'), findsOneWidget);
  });

  testWidgets('uses the app\'s own hint on an engine with a key browser, whose search finds names, not keys', (
    tester,
  ) async {
    harness.answerMeta('seed:dev-redis', metaAnswer('meta_redis'));
    await harness.pump(tester, location: '/browse/seed%3Adev-redis/search');

    expect(find.widgetWithText(TextField, 'Search by name'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Search keys...'), findsNothing);
  });

  testWidgets('ord finds orders and order_items, grouped by schema, each row with its kind\'s label', (tester) async {
    tallScreen(tester);
    answerSearch(_postgres.id, Success(objectsAnswer('search_postgres')));
    await harness.pump(tester, location: _search);

    await type(tester, 'ord');

    expect(find.text('public'), findsOneWidget);
    expect(find.text('sales'), findsOneWidget);
    expect(tester.getTopLeft(find.text('public')).dy, lessThan(tester.getTopLeft(find.text('orders')).dy));
    expect(tester.getTopLeft(find.text('orders')).dy, lessThan(tester.getTopLeft(find.text('sales')).dy));
    expect(
      find.descendant(of: find.widgetWithText(ListTile, 'orders'), matching: find.text('Table · 48 KB')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: find.widgetWithText(ListTile, 'order_items'), matching: find.text('Table · 32 KB')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: find.widgetWithText(ListTile, 'order_total'), matching: find.text('Function')),
      findsOneWidget,
    );
    verify(() => harness.repository.search(_postgres.id, term: 'ord')).called(1);
  });

  testWidgets('a one-character term sends nothing and says how many characters a search needs', (tester) async {
    answerSearch(_postgres.id, const Success([]));
    await harness.pump(tester, location: _search);

    await type(tester, 'o');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(find.text('Type at least 2 characters to search.'), findsOneWidget);
    verifyNoSearch();
  });

  testWidgets('a keyboard submit searches at once, without the pause', (tester) async {
    answerSearch(_postgres.id, Success(objectsAnswer('search_postgres')));
    await harness.pump(tester, location: _search);

    await tester.enterText(field(), 'ord');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();
    await tester.pump();

    verify(() => harness.repository.search(_postgres.id, term: 'ord')).called(1);
    await tester.pumpAndSettle();
    expect(find.text('orders'), findsOneWidget);
    verifyNoSearch();
  });

  testWidgets('a search that finds nothing says so', (tester) async {
    answerSearch(_postgres.id, const Success([]));
    await harness.pump(tester, location: _search);

    await type(tester, 'zz');

    expect(find.text('No object\'s name holds "zz".'), findsOneWidget);
  });

  testWidgets('a server-level connection is not searchable: it says to browse instead and sends no request', (
    tester,
  ) async {
    answerSearch(_server, const Success([]));
    await harness.pump(tester, location: '/browse/seed%3Adev-postgres-server/search');

    expect(find.text('Search is not available on this connection; browse instead'), findsOneWidget);
    expect(field(), findsNothing);
    verifyNoSearch();
  });

  testWidgets('a 400 shows the generic Studio error in the Browse failure view, whose retry sends it again', (
    tester,
  ) async {
    answerSearch(_postgres.id, const Failure(ValidationError('this search would list 1200 container and kind pairs')));
    await harness.pump(tester, location: _search);

    await type(tester, 'ord');

    expect(find.byType(StudioErrorBanner), findsOneWidget);
    expect(find.text('Something went wrong'), findsOneWidget);
    expect(find.textContaining('pairs'), findsNothing);
    expect(field(), findsOneWidget);

    answerSearch(_postgres.id, Success(objectsAnswer('search_postgres')));
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.text('orders'), findsOneWidget);
    verify(() => harness.repository.search(_postgres.id, term: 'ord')).called(2);
  });

  testWidgets('a CONFIG_ERROR shows Studio\'s configuration message', (tester) async {
    answerSearch(
      _postgres.id,
      Failure(ValidationError('reaches every database', code: AppErrorCode.studioConfigError.key)),
    );
    await harness.pump(tester, location: _search);

    await type(tester, 'ord');

    expect(find.byType(StudioErrorBanner), findsOneWidget);
    expect(find.text('Something went wrong'), findsNothing);
  });

  testWidgets('a match opens by the object list\'s tap rule: a kind with source and no columns opens its source', (
    tester,
  ) async {
    tallScreen(tester);
    answerSearch(_postgres.id, Success(objectsAnswer('search_postgres')));
    when(() => harness.repository.source(_postgres.id, path: ['sales', 'order_total(bigint)'], kind: 'function'))
        .thenAnswer((_) async => Success(sourceAnswer('source_postgres_function')));
    await harness.pump(tester, location: _search);
    await type(tester, 'ord');

    await tester.tap(find.text('order_total'));
    await tester.pumpAndSettle();

    expect(harness.router.state.uri.path, '/browse/seed%3Adev-postgres/source/function');
    expect(harness.router.state.uri.queryParametersAll['path'], ['sales', 'order_total(bigint)']);
  });

  testWidgets('a match carries the object list\'s status badge and size beside its kind\'s label', (tester) async {
    answerSearch(
      _postgres.id,
      const Success([
        DatabaseObject(path: ['sales', 'order_totals'], name: 'order_totals', kind: 'view', status: 'INVALID'),
        DatabaseObject(path: ['public', 'orders'], name: 'orders', kind: 'table', sizeBytes: 49152),
      ]),
    );
    await harness.pump(tester, location: _search);
    await type(tester, 'ord');

    expect(
      find.descendant(of: find.widgetWithText(ListTile, 'order_totals'), matching: find.text('Invalid')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: find.widgetWithText(ListTile, 'orders'), matching: find.text('Table · 48 KB')),
      findsOneWidget,
    );
  });

  testWidgets("the recorded view, for which Studio 1.1.0 sends no size, shows its kind's label and no size", (
    tester,
  ) async {
    tallScreen(tester);
    answerSearch(_postgres.id, Success(objectsAnswer('search_postgres')));
    await harness.pump(tester, location: _search);
    await type(tester, 'ord');

    final view = find.widgetWithText(ListTile, 'order_totals');
    expect(find.descendant(of: view, matching: find.text('View')), findsOneWidget);
    expect(find.descendant(of: view, matching: find.textContaining(' B')), findsNothing);
  });

  testWidgets('a long press on a match offers the object list\'s menu, whose View source opens the source', (
    tester,
  ) async {
    tallScreen(tester);
    answerSearch(_postgres.id, Success(objectsAnswer('search_postgres')));
    when(() => harness.repository.source(_postgres.id, path: ['sales', 'order_total(bigint)'], kind: 'function'))
        .thenAnswer((_) async => Success(sourceAnswer('source_postgres_function')));
    await harness.pump(tester, location: _search);
    await type(tester, 'ord');

    await tester.longPress(find.text('order_total'));
    await tester.pumpAndSettle();
    expect(find.text('Copy name'), findsOneWidget);
    await tester.tap(find.text('View source'));
    await tester.pumpAndSettle();

    expect(harness.router.state.uri.path, '/browse/seed%3Adev-postgres/source/function');
  });

  testWidgets('a table match offers View rows from its long press, which opens its rows; a function match does not', (
    tester,
  ) async {
    tallScreen(tester);
    answerSearch(_postgres.id, Success(objectsAnswer('search_postgres')));
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
    await harness.pump(tester, location: _search);
    await type(tester, 'ord');

    await tester.longPress(find.text('order_total'));
    await tester.pumpAndSettle();
    expect(find.text('Copy name'), findsOneWidget);
    expect(find.text('View rows'), findsNothing);
    Navigator.of(tester.element(find.text('Copy name'))).pop();
    await tester.pumpAndSettle();

    await tester.longPress(find.text('orders'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('View rows'));
    await tester.pumpAndSettle();

    expect(harness.router.state.uri.path, '/browse/seed%3Adev-postgres/rows/table');
    expect(harness.router.state.uri.queryParametersAll['path'], ['public', 'orders']);
  });

  for (final viaMenu in [false, true]) {
    testWidgets('a table match opens its Details ${viaMenu ? 'from the long-press menu' : 'by the tap rule'}', (
      tester,
    ) async {
      answerSearch(_postgres.id, Success(objectsAnswer('search_postgres')));
      when(
        () => harness.repository.describe(
          _postgres.id,
          path: ['public', 'orders'],
          kind: 'table',
          refresh: any(named: 'refresh'),
        ),
      ).thenAnswer((_) async => answered(detailAnswer('describe_postgres_orders')));
      // The detail page lists the schema's tables to link the foreign keys.
      when(
        () => harness.repository.list(
          _postgres.id,
          container: ['public'],
          kind: 'table',
          refresh: any(named: 'refresh'),
        ),
      ).thenAnswer((_) async => answered(objectsAnswer('list_postgres')));
      await harness.pump(tester, location: _search);
      await type(tester, 'ord');

      if (viaMenu) {
        await tester.longPress(find.text('orders'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Details'));
      } else {
        await tester.tap(find.text('orders'));
      }
      await tester.pumpAndSettle();

      expect(harness.router.state.uri.path, '/browse/seed%3Adev-postgres/detail/table');
      expect(harness.router.state.uri.queryParametersAll['path'], ['public', 'orders']);
    });
  }

  testWidgets('a match of a kind the engine does not declare shows without a kind and opens nothing', (tester) async {
    answerSearch(
      _postgres.id,
      const Success([
        DatabaseObject(path: ['public', 'orders_q'], name: 'orders_q', kind: 'queue'),
      ]),
    );
    await harness.pump(tester, location: _search);
    await type(tester, 'ord');

    final tile = tester.widget<ListTile>(find.widgetWithText(ListTile, 'orders_q'));
    expect(tile.onTap, isNull);
    expect(find.text('queue'), findsNothing);
  });

  testWidgets("Studio's pair limit asks for kinds, with a chip per kind a search lists, instead of an error", (
    tester,
  ) async {
    tallScreen(tester);
    answerSearch(
      _postgres.id,
      Failure(ValidationError('too many pairs', code: AppErrorCode.studioSearchPairLimit.key)),
    );
    await harness.pump(tester, location: _search);
    expect(find.byType(FilterChip), findsNothing, reason: 'no kinds are offered before Studio asks for them');

    await type(tester, 'ord');

    expect(find.text('Too many places to search. Pick object kinds to narrow the search.'), findsOneWidget);
    expect(find.byType(StudioErrorBanner), findsNothing);
    expect(find.text('Retry'), findsNothing);
    expect(
      [for (final chip in tester.widgetList<FilterChip>(find.byType(FilterChip))) (chip.label as Text).data],
      ['Tables', 'Views', 'Materialized Views', 'Sequences', 'Functions', 'Procedures', 'Triggers'],
    );
    expect(tester.widgetList<FilterChip>(find.byType(FilterChip)).every((chip) => !chip.selected), isTrue);
  });

  testWidgets('a picked kind searches the term again with it at once, and its chip stays with the results', (
    tester,
  ) async {
    tallScreen(tester);
    answerSearch(
      _postgres.id,
      Failure(ValidationError('too many pairs', code: AppErrorCode.studioSearchPairLimit.key)),
    );
    await harness.pump(tester, location: _search);
    await type(tester, 'ord');

    answerSearch(_postgres.id, Success(objectsAnswer('search_postgres_kinds')));
    await tester.tap(find.widgetWithText(FilterChip, 'Tables'));
    await tester.pumpAndSettle();

    verify(() => harness.repository.search(_postgres.id, term: 'ord', kinds: ['table'])).called(1);
    expect(find.text('orders'), findsOneWidget);
    expect(tester.widget<FilterChip>(find.widgetWithText(FilterChip, 'Tables')).selected, isTrue);
    expect(tester.widget<FilterChip>(find.widgetWithText(FilterChip, 'Views')).selected, isFalse);
  });

  testWidgets('back from the search opened by a link returns to the Browse root, with no query left over', (
    tester,
  ) async {
    await harness.pump(tester, location: _search);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(harness.router.state.uri.path, '/browse');
    expect(harness.router.state.uri.query, isEmpty);
  });
}
