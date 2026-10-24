@Tags(['widget'])
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/app/router/app_routes_constants.dart';
import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/core/testing/app_key_constants.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/object_browser/navigation/browse_navigation.dart';
import 'package:libredb_mobile/features/object_browser/presentation/pages/object_rows_page.dart';
import 'package:libredb_mobile/features/object_browser/presentation/widgets/browse_failure_view.dart';
import 'package:libredb_mobile/infrastructure/studio/provider_meta_json.dart';
import 'package:libredb_mobile/infrastructure/studio/query_result_json.dart';
import 'package:libredb_mobile/shared/active_connection/active_connection_cubit.dart';
import 'package:libredb_mobile/shared/models/cancel_signal.dart';
import 'package:libredb_mobile/shared/models/query_page.dart';
import 'package:libredb_mobile/shared/models/query_result.dart';
import 'package:libredb_mobile/shared/models/studio_connection.dart';
import 'package:libredb_mobile/shared/widgets/offline_status.dart';
import 'package:libredb_mobile/shared/widgets/result_view/result_table.dart';
import 'package:libredb_mobile/shared/widgets/result_view/result_view.dart';
import 'package:libredb_mobile/shared/widgets/studio_error_banner.dart';
import 'package:mocktail/mocktail.dart';

import '../../browse_answers.dart';
import '../../browse_harness.dart';
import '../../result_scroll.dart';

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
      cancelSignal: any(named: 'cancelSignal'),
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
      cancelSignal: any(named: 'cancelSignal'),
    ),
  ).callCount;

  Finder countButton() => find.widgetWithText(TextButton, 'Count rows');

  group('back online after a failed preview', () {
    testWidgets('a failure without a code runs nothing again by itself, since its statement may have run', (
      tester,
    ) async {
      answerPreview(const Failure(NetworkError('socket closed')));
      await harness.pump(tester, location: customersLocation);
      expect(find.byType(BrowseFailureView), findsOneWidget);

      await harness.setOffline(tester, true);
      await harness.setOffline(tester, false);

      expect(runsOf(_postgres.id, _preview), 1);
    });

    testWidgets('a preview the offline device never sent runs once the device is back online', (tester) async {
      answerPreview(Failure(NetworkError('offline', code: AppErrorCode.networkOffline.key)));
      await harness.pump(tester, location: customersLocation, offline: true);

      await harness.setOffline(tester, false);

      expect(runsOf(_postgres.id, _preview), 2);
    });
  });

  testWidgets('a preview refused with the account runs nothing again by itself once Retry clears the refusal', (
    tester,
  ) async {
    answerPreview(Failure(AuthError('No role', code: AppErrorCode.studioAccountHasNoRole.key)));
    await harness.pump(tester, location: customersLocation);
    await harness.refuseAccount(tester, AppErrorCode.studioAccountHasNoRole);

    await harness.retryAccepted(tester);

    expect(find.byKey(accountRefusalRetryKey), findsNothing, reason: 'the page is uncovered');
    expect(find.byType(BrowseFailureView), findsOneWidget);
    expect(runsOf(_postgres.id, _preview), 1);
  });

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
          cancelSignal: any(named: 'cancelSignal'),
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

  group('scrolling a loaded result', () {
    final platforms = TargetPlatformVariant({TargetPlatform.android, TargetPlatform.iOS});

    Future<void> showTable(WidgetTester tester) async {
      await tester.tap(find.byTooltip('Table'));
      await tester.pumpAndSettle();
    }

    testWidgets('the cards settle at the first and the last row', (tester) async {
      answerPreview(Success(wideResult()));
      await harness.pump(tester, location: customersLocation);
      // Offline a pull past the first row runs nothing, so the same list is measured at both ends.
      await harness.setOffline(tester, true);

      await expectSettlesAtEachEnd(tester, cardListScrollable());
    }, variant: platforms);

    testWidgets('the table settles at the first and the last row', (tester) async {
      answerPreview(Success(wideResult()));
      await harness.pump(tester, location: customersLocation);
      await showTable(tester);
      await harness.setOffline(tester, true);

      await expectSettlesAtEachEnd(tester, tableRowsScrollable());
    }, variant: platforms);

    testWidgets('the table settles at the first and the last column', (tester) async {
      answerPreview(Success(wideResult()));
      await harness.pump(tester, location: customersLocation);
      await showTable(tester);

      await expectSettlesAtEachEnd(tester, tableColumnsScrollable());
    }, variant: platforms);

    testWidgets('a pull on the cards springs back, offline', (tester) async {
      answerPreview(Success(wideResult()));
      await harness.pump(tester, location: customersLocation);
      await harness.setOffline(tester, true);

      await pullAndExpectSpringBack(tester, cardListScrollable());
      expect(find.widgetWithText(SnackBar, 'No internet connection'), findsOneWidget);
      expect(runsOf(_postgres.id, _preview), 1);
    }, variant: platforms);

    testWidgets('a one-row result on the cards still pulls to refresh, and springs back', (tester) async {
      answerPreview(Success(wideResult(rows: 1, columns: 2)));
      await harness.pump(tester, location: customersLocation);

      await pullAndExpectSpringBack(tester, cardListScrollable());
      expect(runsOf(_postgres.id, _preview), 2);
    }, variant: platforms);

    for (final (rows, name) in [(100, '100 rows'), (1, 'one row')]) {
      testWidgets('a pull on a table of $name refreshes once, and springs back', (tester) async {
        answerPreview(Success(wideResult(rows: rows)));
        await harness.pump(tester, location: customersLocation);
        await showTable(tester);

        await pullAndExpectSpringBack(tester, tableRowsScrollable());
        expect(runsOf(_postgres.id, _preview), 2);
      }, variant: platforms);
    }

    testWidgets('a sideways scroll of the table past either end refreshes nothing', (tester) async {
      answerPreview(Success(wideResult()));
      await harness.pump(tester, location: customersLocation);
      await showTable(tester);

      await expectSettlesAtEachEnd(tester, tableColumnsScrollable());
      await tester.flingFrom(tester.getCenter(find.byType(ResultTable)), const Offset(400, 0), 1000);
      await tester.pumpAndSettle();
      expect(runsOf(_postgres.id, _preview), 1);
    }, variant: platforms);
  });

  // The preview's request is dropped when the page goes, and Studio cancels the run itself; no /db/cancel is posted,
  // so leaving spends no request slot (#116).
  testWidgets('leaving the page during a preview drops its request and posts no cancel', (tester) async {
    final signals = <CancelSignal?>[];
    when(
      () => harness.statements.run(
        _postgres.id,
        _preview,
        queryId: any(named: 'queryId'),
        page: any(named: 'page'),
        catalog: any(named: 'catalog'),
        cancelSignal: any(named: 'cancelSignal'),
      ),
    ).thenAnswer((invocation) {
      signals.add(invocation.namedArguments[#cancelSignal] as CancelSignal?);
      return Completer<Result<QueryResult>>().future;
    });
    await harness.pump(tester, location: customersLocation, settle: false);
    expect(signals.single!.isCancelled, isFalse);

    harness.router.go(ApplicationRoutesConstants.connectionList);
    await tester.pumpAndSettle();

    expect(find.byType(ObjectRowsPage), findsNothing);
    expect(signals.single!.isCancelled, isTrue);
    verifyNever(() => harness.statements.cancel(any(), any()));
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
        cancelSignal: any(named: 'cancelSignal'),
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

  testWidgets(
    'a preview dropped after a switch to another app says it was interrupted, and runs again only on a retry',
    (tester) async {
      var calls = 0;
      answerRun(_postgres.id, _preview, () async {
        if (calls++ > 0) return Success(_recorded('query_preview_postgres_customers'));
        harness.lifecycle.leaveAndComeBack();
        return const Failure(NetworkError('Connection closed before full header was received'));
      });
      await harness.pump(tester, location: customersLocation);

      expect(
        find.text('Reading the rows was interrupted when the app went to the background; Studio cancelled it.'),
        findsOneWidget,
      );
      await harness.setOffline(tester, true);
      await harness.setOffline(tester, false);
      expect(calls, 1);

      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pumpAndSettle();

      expect(calls, 2);
      expect(find.byType(StudioErrorBanner), findsNothing);
      expect(find.byType(ResultView), findsOneWidget);
    },
  );

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
    verifyNever(
      () => harness.statements.run(
        any(),
        any(),
        page: any(named: 'page'),
        cancelSignal: any(named: 'cancelSignal'),
      ),
    );
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

  group('Load more on the recorded sales.ledger', () {
    const ledger = ['sales', 'ledger'];
    const ledgerPreview = 'SELECT * FROM sales.ledger;';
    final ledgerLocation = _location(_postgres.id, 'table', ledger);
    const orderNotice = 'Without an ORDER BY the engine may return rows that repeat or are skipped between pages.';

    void answerPage(QueryPage page, String fixture) => when(
      () => harness.statements.run(
        _postgres.id,
        ledgerPreview,
        queryId: any(named: 'queryId'),
        page: page,
        catalog: any(named: 'catalog'),
        cancelSignal: any(named: 'cancelSignal'),
      ),
    ).thenAnswer((_) async => Success(_recorded(fixture)));

    setUp(() {
      answerPage(const QueryPage(limit: 50), 'query_page_postgres_first');
      answerPage(const QueryPage(limit: 50, offset: 50), 'query_page_postgres_second');
    });

    testWidgets('offers 50 more with the order notice, runs the same preview for the next page, and then ends', (
      tester,
    ) async {
      await harness.pump(tester, location: ledgerLocation);

      expect(find.text('Load 50 more'), findsOneWidget);
      expect(find.text(orderNotice), findsOneWidget);
      await tester.tap(find.text('Load 50 more'));
      await tester.pumpAndSettle();

      final captured = verify(
        () => harness.statements.run(
          _postgres.id,
          ledgerPreview,
          queryId: captureAny(named: 'queryId'),
          page: captureAny(named: 'page'),
          catalog: null,
          cancelSignal: any(named: 'cancelSignal'),
        ),
      ).captured;
      expect(captured, hasLength(4));
      // mocktail lists the captured named arguments by name: the page, then the run id, of each call.
      expect([captured[0], captured[2]], [const QueryPage(limit: 50), const QueryPage(limit: 50, offset: 50)]);
      expect(captured[3], isNot(captured[1]));
      expect(find.text('Load 50 more'), findsNothing);
      expect(find.text(orderNotice), findsNothing);
      expect(find.textContaining('100 rows'), findsOneWidget);
    });

    group('on a phone held sideways', () {
      Future<void> pumpSideways(WidgetTester tester) async {
        sideways(tester);
        await harness.pump(tester, location: ledgerLocation);
        await tester.tap(find.byTooltip('Table'));
        await tester.pumpAndSettle();
      }

      testWidgets('shows at least three rows of the table after Load more', (tester) async {
        await pumpSideways(tester);

        await tester.tap(find.text('Load 50 more'));
        await tester.pumpAndSettle();

        expect(find.textContaining('100 rows'), findsOneWidget);
        expect(fullyShownTableRows(tester), greaterThanOrEqualTo(3));
      });

      testWidgets('a rotation keeps the rows, the table and its scroll position, with no new request', (tester) async {
        await pumpSideways(tester);
        tester.view.physicalSize = const Size(393, 829);
        await tester.pumpAndSettle();
        scrollPositionOf(tester, tableRowsScrollable()).jumpTo(300);
        await tester.pumpAndSettle();

        tester.view.physicalSize = const Size(829, 393);
        await tester.pumpAndSettle();
        expect(scrollPositionOf(tester, tableRowsScrollable()).pixels, 300);
        tester.view.physicalSize = const Size(393, 829);
        await tester.pumpAndSettle();

        expect(find.byType(ResultTable), findsOneWidget);
        expect(scrollPositionOf(tester, tableRowsScrollable()).pixels, 300);
        verify(
          () => harness.statements.run(
            _postgres.id,
            ledgerPreview,
            queryId: any(named: 'queryId'),
            page: any(named: 'page'),
            catalog: any(named: 'catalog'),
            cancelSignal: any(named: 'cancelSignal'),
          ),
        ).called(1);
      });
    });

    testWidgets('a page refused with a vanished connection goes to the active connection\'s vanish flow', (
      tester,
    ) async {
      harness.active.select(_postgres);
      when(
        () => harness.statements.run(
          _postgres.id,
          ledgerPreview,
          queryId: any(named: 'queryId'),
          page: const QueryPage(limit: 50, offset: 50),
          catalog: any(named: 'catalog'),
          cancelSignal: any(named: 'cancelSignal'),
        ),
      ).thenAnswer((_) async => const Failure(NotFoundError('gone', code: 'studio.connection_not_available')));
      await harness.pump(tester, location: ledgerLocation);
      expect(harness.active.state, isA<ActiveConnectionSelected>());

      await tester.tap(find.text('Load 50 more'));
      await tester.pumpAndSettle();

      expect(harness.active.state, isA<ActiveConnectionVanished>());
    });

    testWidgets('a page dropped after a switch to another app says it was interrupted, keeps the rows and offers a '
        'retry', (tester) async {
      var pages = 0;
      when(
        () => harness.statements.run(
          _postgres.id,
          ledgerPreview,
          queryId: any(named: 'queryId'),
          page: const QueryPage(limit: 50, offset: 50),
          catalog: any(named: 'catalog'),
          cancelSignal: any(named: 'cancelSignal'),
        ),
      ).thenAnswer((_) async {
        if (pages++ > 0) return Success(_recorded('query_page_postgres_second'));
        harness.lifecycle.leaveAndComeBack();
        return const Failure(NetworkError('Connection closed before full header was received'));
      });
      await harness.pump(tester, location: ledgerLocation);

      await tester.tap(find.text('Load 50 more'));
      await tester.pumpAndSettle();

      expect(
        find.text('Loading more was interrupted when the app went to the background; Studio cancelled it.'),
        findsOneWidget,
      );
      expect(find.textContaining('50 rows'), findsOneWidget);
      expect(pages, 1);

      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pumpAndSettle();

      expect(pages, 2);
      expect(find.textContaining('100 rows'), findsOneWidget);
    });

    testWidgets('an engine that cannot page offers no Load more', (tester) async {
      final meta = File('test/fixtures/studio/meta_postgres.json')
          .readAsStringSync()
          .replaceFirst('"supportsResultPagination":true', '"supportsResultPagination":false');
      harness.answerMeta(_postgres.id, ProviderMetaJson.read(meta));
      await harness.pump(tester, location: ledgerLocation);

      expect(find.textContaining('50 rows'), findsOneWidget);
      expect(find.text('Load 50 more'), findsNothing);
      expect(find.text(orderNotice), findsNothing);
    });
  });
}
