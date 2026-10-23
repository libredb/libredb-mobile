@Tags(['widget'])
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/object_browser/navigation/browse_navigation.dart';
import 'package:libredb_mobile/features/object_browser/presentation/pages/object_rows_page.dart';
import 'package:libredb_mobile/features/object_browser/presentation/widgets/browse_failure_view.dart';
import 'package:libredb_mobile/infrastructure/studio/query_result_json.dart';
import 'package:libredb_mobile/shared/active_connection/active_connection_cubit.dart';
import 'package:libredb_mobile/shared/models/query_page.dart';
import 'package:libredb_mobile/shared/models/query_result.dart';
import 'package:libredb_mobile/shared/models/studio_connection.dart';
import 'package:libredb_mobile/shared/widgets/offline_status.dart';
import 'package:libredb_mobile/shared/widgets/result_view/result_view.dart';
import 'package:libredb_mobile/shared/widgets/studio_error_banner.dart';
import 'package:mocktail/mocktail.dart';

import '../../browse_answers.dart';
import '../../browse_harness.dart';

const _postgres = StudioConnection(id: 'seed:dev-postgres', name: 'Dev (PostgreSQL)', type: 'postgres');
const _server = StudioConnection(id: 'seed:dev-postgres-server', name: 'Dev server', type: 'postgres');
const _redis = 'seed:dev-redis';

const _customers = ['public', 'customers'];
const _preview = 'SELECT * FROM public.customers;';
const _count = 'SELECT COUNT(*) AS row_count\nFROM public.customers;';

QueryResult _recorded(String name) => QueryResultJson.read(File('test/fixtures/studio/$name.json').readAsStringSync());

QueryResult _countAnswer(String field, Object? value) => QueryResult(
  fields: [field],
  rows: [
    {field: value},
  ],
  rowCount: 1,
  executionTime: Duration.zero,
);

String _location(String connectionId, String kind, List<String> path) =>
    Uri(path: '/browse/${Uri.encodeComponent(connectionId)}/rows/$kind', queryParameters: {'path': path}).toString();

void main() {
  late BrowseHarness harness;
  final customersLocation = _location(_postgres.id, 'table', _customers);

  setUp(() {
    harness = BrowseHarness();
    harness.answerMeta(_postgres.id, metaAnswer('meta_postgres'));
    harness.answerContainers(_postgres.id, null, containersAnswer('containers_postgres'));
    harness.answerCounts(_postgres.id, ['public'], countsAnswer('counts_postgres'));
    harness.answerMeta(_server.id, metaAnswer('meta_postgres_server'));
    harness.answerContainers(_server.id, null, containersAnswer('containers_postgres_server'));
    harness.answerContainers(_server.id, ['app'], containersAnswer('containers_postgres_catalog'));
    harness.answerMeta(_redis, metaAnswer('meta_redis'));
  });

  void answerRun(String connectionId, String sql, Future<Result<QueryResult>> Function() answer) => when(
    () => harness.statements.run(
      connectionId,
      sql,
      queryId: any(named: 'queryId'),
      page: any(named: 'page'),
      catalog: any(named: 'catalog'),
    ),
  ).thenAnswer((_) => answer());

  void answerPreview(Result<QueryResult> answer) => answerRun(_postgres.id, _preview, () async => answer);

  int runsOf(String connectionId, String sql) => verify(
    () => harness.statements.run(
      connectionId,
      sql,
      queryId: any(named: 'queryId'),
      page: any(named: 'page'),
      catalog: any(named: 'catalog'),
    ),
  ).callCount;

  Finder countButton() => find.widgetWithText(TextButton, 'Count rows');

  group('the recorded customers table', () {
    setUp(() => answerPreview(Success(_recorded('query_preview_postgres_customers'))));

    testWidgets('shows its rows from a run of 50 with email and card_number masked', (tester) async {
      await harness.pump(tester, location: customersLocation);

      expect(find.byType(ObjectRowsPage), findsOneWidget);
      expect(find.byType(ResultView), findsOneWidget);
      expect(find.text('customers'), findsOneWidget);
      expect(find.text('Table'), findsOneWidget);
      expect(find.textContaining('Ada Lovelace'), findsWidgets);
      expect(find.textContaining('ada@example.com'), findsNothing);
      expect(find.textContaining('4111111111111111'), findsNothing);
      verify(
        () => harness.statements.run(
          _postgres.id,
          _preview,
          queryId: any(named: 'queryId', that: isNotEmpty),
          page: const QueryPage(limit: 50),
          catalog: null,
        ),
      ).called(1);
    });

    testWidgets('Count rows shows the count of a decimal string, grouped, and the rows stay', (tester) async {
      answerRun(_postgres.id, _count, () async => Success(_recorded('query_count_postgres_customers')));
      await harness.pump(tester, location: customersLocation);

      await tester.tap(countButton());
      await tester.pumpAndSettle();

      expect(find.text('3 rows'), findsOneWidget);
      expect(find.byType(ResultView), findsOneWidget);
      expect(runsOf(_postgres.id, _count), 1);
      expect(runsOf(_postgres.id, _preview), 1);
    });

    for (final (field, value) in [('row_count', 20000), ('ROW_COUNT', '20000'), ('count', 20000)]) {
      testWidgets('Count rows reads $field, grouped as 20,000 rows', (tester) async {
        answerRun(_postgres.id, _count, () async => Success(_countAnswer(field, value)));
        await harness.pump(tester, location: customersLocation);

        await tester.tap(countButton());
        await tester.pumpAndSettle();

        expect(find.text('20,000 rows'), findsOneWidget);
      });
    }

    testWidgets('Count rows is disabled while a count runs, so a second tap runs nothing', (tester) async {
      final answer = Completer<Result<QueryResult>>();
      answerRun(_postgres.id, _count, () => answer.future);
      await harness.pump(tester, location: customersLocation);

      await tester.tap(countButton());
      await tester.pump();
      expect(tester.widget<TextButton>(countButton()).onPressed, isNull);
      await tester.tap(countButton(), warnIfMissed: false);
      await tester.pump();

      answer.complete(Success(_countAnswer('row_count', 1)));
      await tester.pumpAndSettle();
      expect(find.text('1 row'), findsOneWidget);
      expect(tester.widget<TextButton>(countButton()).onPressed, isNotNull);
      expect(runsOf(_postgres.id, _count), 1);
    });

    testWidgets('a refused count says so with its code in the heading, and the rows stay', (tester) async {
      answerRun(
        _postgres.id,
        _count,
        () async => const Failure(ValidationError('permission denied', code: 'studio.query_error')),
      );
      await harness.pump(tester, location: customersLocation);

      await tester.tap(countButton());
      await tester.pumpAndSettle();

      expect(find.text('Could not count the rows (studio.query_error)'), findsOneWidget);
      expect(find.textContaining('permission denied'), findsNothing);
      expect(find.byType(ResultView), findsOneWidget);
      expect(find.byType(BrowseFailureView), findsNothing);
    });

    testWidgets('offline, the rows stay marked stale, Count rows is disabled with the reason, and a pull sends '
        'nothing', (tester) async {
      await harness.pump(tester, location: customersLocation);

      await harness.setOffline(tester, true);

      expect(find.byType(ResultView), findsOneWidget);
      expect(
        find.descendant(of: find.byType(OfflineStaleMarker), matching: find.byIcon(Icons.history)),
        findsOneWidget,
      );
      expect(tester.widget<TextButton>(countButton()).onPressed, isNull);
      expect(find.text('Needs an internet connection'), findsOneWidget);

      await tester.fling(find.textContaining('Ada Lovelace').first, const Offset(0, 400), 1000);
      await tester.pumpAndSettle();
      expect(find.widgetWithText(SnackBar, 'No internet connection'), findsOneWidget);
      expect(runsOf(_postgres.id, _preview), 1);
    });

    testWidgets('a pull runs the preview again, online', (tester) async {
      await harness.pump(tester, location: customersLocation);

      await tester.fling(find.textContaining('Ada Lovelace').first, const Offset(0, 400), 1000);
      await tester.pumpAndSettle();

      expect(runsOf(_postgres.id, _preview), 2);
      expect(find.byType(ResultView), findsOneWidget);
    });

    testWidgets('fits its heading, count and rows at twice the text size on a small phone', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      answerRun(_postgres.id, _count, () async => Success(_recorded('query_count_postgres_customers')));

      await harness.pump(tester, location: customersLocation);
      await tester.tap(countButton());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('3 rows'), findsOneWidget);
    });

    testWidgets('the back arrow returns a page opened by a link to the Browse root', (tester) async {
      await harness.pump(tester, location: customersLocation);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      expect(harness.router.state.uri.path, '/browse');
      expect(find.byType(ObjectRowsPage), findsNothing);
    });
  });

  testWidgets('a connection switch returns Browse to the new connection\'s first entry', (tester) async {
    harness.active.select(_server);
    answerRun(
      _server.id,
      'SELECT * FROM app.public.orders;',
      () async => Success(_recorded('query_preview_postgres_server_orders')),
    );
    await harness.pump(tester, location: _location(_server.id, 'table', const ['app', 'public', 'orders']));
    expect(find.byType(ObjectRowsPage), findsOneWidget);

    harness.active.select(_postgres);
    await tester.pumpAndSettle();

    expect(find.byType(ObjectRowsPage), findsNothing);
    expect(harness.location, '/browse/seed%3Adev-postgres/kinds?container=public');
  });

  testWidgets('on a server-level connection the run carries the catalog and the full path', (tester) async {
    harness.active.select(_server);
    answerRun(
      _server.id,
      'SELECT * FROM app.public.orders;',
      () async => Success(_recorded('query_preview_postgres_server_orders')),
    );

    await harness.pump(tester, location: _location(_server.id, 'table', const ['app', 'public', 'orders']));

    verify(
      () => harness.statements.run(
        _server.id,
        'SELECT * FROM app.public.orders;',
        queryId: any(named: 'queryId'),
        page: const QueryPage(limit: 50),
        catalog: 'app',
      ),
    ).called(1);
    expect(find.byType(ResultView), findsOneWidget);
  });

  testWidgets('a failed preview shows the banner and the database\'s words, and runs again only on a retry', (
    tester,
  ) async {
    var calls = 0;
    answerRun(
      _postgres.id,
      _preview,
      () async => calls++ == 0
          ? const Failure(ValidationError('permission denied for table customers', code: 'studio.query_error'))
          : Success(_recorded('query_preview_postgres_customers')),
    );
    await harness.pump(tester, location: customersLocation);

    expect(find.byType(StudioErrorBanner), findsOneWidget);
    expect(find.text('The statement failed.'), findsOneWidget);
    expect(find.text('permission denied for table customers'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(runsOf(_postgres.id, _preview), 1);

    await tester.tap(find.byIcon(Icons.refresh));
    await tester.pumpAndSettle();

    expect(find.byType(StudioErrorBanner), findsNothing);
    expect(find.text('permission denied for table customers'), findsNothing);
    expect(find.byType(ResultView), findsOneWidget);
  });

  testWidgets('another failure shows the banner without the error\'s text', (tester) async {
    answerPreview(const Failure(ServerError('connect ECONNREFUSED 10.0.0.1', code: 'studio.database_unreachable')));
    await harness.pump(tester, location: customersLocation);

    expect(find.byType(StudioErrorBanner), findsOneWidget);
    expect(find.textContaining('ECONNREFUSED'), findsNothing);
  });

  testWidgets('a vanished connection goes to the active connection\'s vanish flow', (tester) async {
    harness.active.select(_server);
    answerRun(
      _server.id,
      'SELECT * FROM app.public.orders;',
      () async => const Failure(NotFoundError('gone', code: 'studio.connection_not_available')),
    );

    await harness.pump(tester, location: _location(_server.id, 'table', const ['app', 'public', 'orders']));

    expect(harness.active.state, isA<ActiveConnectionVanished>());
  });

  testWidgets('an engine whose preview the app does not write says so and runs nothing', (tester) async {
    await harness.pump(tester, location: _location(_redis, 'keyspace', const ['0', 'user:*']));

    expect(find.text('Preview is not available for this engine yet'), findsOneWidget);
    expect(countButton(), findsNothing);
    verifyNever(() => harness.statements.run(any(), any(), page: any(named: 'page')));
  });

  testWidgets('an object path whose names hold /, a space and İ survives the round trip through browseRows', (
    tester,
  ) async {
    const path = ['app', 'sales/eu (q1)', 'İzmir orders'];
    const statement = 'SELECT * FROM app."sales/eu (q1)"."İzmir orders";';
    harness.active.select(_server);
    answerRun(_server.id, statement, () async => Success(_recorded('query_preview_postgres_customers')));
    await harness.pump(tester);

    openBrowseRows(tester.element(find.text('Databases')), _server.id, path, 'table');
    await tester.pumpAndSettle();

    expect(harness.router.state.pathParameters['connectionId'], _server.id);
    expect(harness.router.state.pathParameters['kind'], 'table');
    expect(harness.router.state.uri.queryParametersAll['path'], path);
    expect(find.text('İzmir orders'), findsOneWidget);
    expect(runsOf(_server.id, statement), 1);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(harness.router.state.uri.path, '/browse');
    expect(find.byType(ObjectRowsPage), findsNothing);
  });
}
