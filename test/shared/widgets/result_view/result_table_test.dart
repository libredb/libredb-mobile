@Tags(['widget'])
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/infrastructure/studio/query_result_json.dart';
import 'package:libredb_mobile/shared/models/query_page.dart';
import 'package:libredb_mobile/shared/models/query_result.dart';
import 'package:libredb_mobile/shared/models/studio_identity.dart';
import 'package:libredb_mobile/shared/security/result_masking/mask_result.dart';
import 'package:libredb_mobile/shared/security/result_masking/masking_policy.dart';
import 'package:libredb_mobile/shared/widgets/offline_status.dart';
import 'package:libredb_mobile/shared/widgets/result_view/result_card.dart';
import 'package:libredb_mobile/shared/widgets/result_view/result_table.dart';
import 'package:libredb_mobile/shared/widgets/result_view/result_view.dart';
import 'package:libredb_mobile/shared/widgets/result_view/result_view_bloc.dart';
import 'package:libredb_mobile/shared/widgets/result_view/result_view_mode_cubit.dart';
import 'package:libredb_mobile/shared/widgets/result_view/result_view_mode_store.dart';
import 'package:libredb_mobile/shared/widgets/studio_error_banner.dart';

final _policy = MaskingPolicy.forRole(const StudioUserRole());

const _orderNotice = 'Without an ORDER BY the engine may return rows that repeat or are skipped between pages.';

QueryResult _page({required int from, required int count, int limit = 2, bool hasMore = true, bool paged = true}) {
  final rows = [
    for (var id = from; id < from + count; id++) {'id': id, 'name': 'person $id', 'email': 'p$id@example.com'},
  ];
  return QueryResult(
    fields: const ['id', 'name', 'email'],
    rows: rows,
    rowCount: rows.length,
    executionTime: const Duration(milliseconds: 3),
    columnTypes: const {'id': 'integer', 'name': 'text'},
    pagination: paged
        ? QueryPagination(
            limit: limit,
            offset: from - 1,
            hasMore: hasMore,
            totalReturned: rows.length,
            wasLimited: hasMore,
          )
        : null,
  );
}

class _Harness {
  _Harness(this.tester);

  final WidgetTester tester;
  final requested = <QueryPage>[];
  late ResultViewBloc bloc;
  late ResultViewModeCubit modes;
  final offline = ValueNotifier(false);

  Future<void> pump(
    QueryResult result, {
    ResultViewMode mode = ResultViewMode.table,
    ResultPageLoader? loadPage,
    bool noLoader = false,
    bool supportsResultPagination = true,
    bool? hasOuterOrderBy,
    Size? screen,
  }) async {
    if (screen != null) {
      tester.view.physicalSize = screen;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }
    final store = _MemoryStore(mode);
    modes = ResultViewModeCubit(store: store);
    await modes.restore();
    addTearDown(modes.close);
    bloc = ResultViewBloc(
      masked: maskResult(result, _policy),
      policy: _policy,
      supportsResultPagination: supportsResultPagination,
      hasOuterOrderBy: hasOuterOrderBy,
      loadPage: noLoader
          ? null
          : (page) {
              requested.add(page);
              return (loadPage ?? (_) async => Success(_page(from: page.offset + 1, count: 2, hasMore: false)))(page);
            },
    );
    // Closed without waiting: Load more is droppable, and that close finishes only on a microtask the finished test's
    // fake clock never runs.
    addTearDown(() => unawaited(bloc.close()));
    await tester.pumpWidget(_app());
    await tester.pump();
  }

  Widget _app({Key? viewKey}) => MaterialApp(
    localizationsDelegates: const [
      S.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: S.delegate.supportedLocales,
    home: ValueListenableBuilder(
      valueListenable: offline,
      builder: (context, isOffline, _) => OfflineStatus(
        isOffline: isOffline,
        child: Scaffold(
          body: MultiBlocProvider(
            providers: [
              BlocProvider.value(value: modes),
              BlocProvider.value(value: bloc),
            ],
            child: ResultView(key: viewKey),
          ),
        ),
      ),
    ),
  );

  /// Builds a new view under the same blocs, as a page that is opened again does.
  Future<void> rebuild() async {
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(_app(viewKey: UniqueKey()));
    await tester.pump();
  }
}

Finder _row(int index) => find.byKey(ValueKey('result-row-$index'));

Finder get _loadMore => find.byKey(const ValueKey('result-load-more'));

void main() {
  group('the table', () {
    testWidgets('shows a header row and a row per result row, the masked column with its mask and a lock', (
      tester,
    ) async {
      await _Harness(tester).pump(_page(from: 1, count: 2, paged: false));

      expect(find.byType(ResultTable), findsOneWidget);
      expect(find.byType(ResultCard), findsNothing);
      final header = find.byKey(const ValueKey('result-table-header'));
      for (final field in ['id', 'name', 'email']) {
        expect(
          find.descendant(of: header, matching: find.text(field)),
          findsOneWidget,
          reason: field,
        );
      }
      expect(find.descendant(of: _row(0), matching: find.text('person 1')), findsOneWidget);
      expect(find.descendant(of: _row(1), matching: find.text('2')), findsOneWidget);
      expect(find.textContaining('@example.com'), findsNothing);
      expect(find.descendant(of: header, matching: find.bySemanticsLabel('Masked value')), findsOneWidget);
    });

    testWidgets('names the declared type under each header that columnTypes names, and nothing under the others', (
      tester,
    ) async {
      await _Harness(tester).pump(_page(from: 1, count: 1, paged: false));
      final header = find.byKey(const ValueKey('result-table-header'));

      expect(find.descendant(of: header, matching: find.text('integer')), findsOneWidget);
      expect(find.descendant(of: header, matching: find.text('text')), findsOneWidget);
      expect(find.byKey(const ValueKey('result-column-type-email')), findsNothing);
    });

    testWidgets('query_types_postgres.json: the declared types show under the headers', (tester) async {
      final result = QueryResultJson.read(File('test/fixtures/studio/query_types_postgres.json').readAsStringSync());
      await _Harness(tester).pump(result);

      for (final field in ['id', 'small_value', 'big_value', 'numeric_value']) {
        expect(
          find.byKey(ValueKey('result-column-type-$field')),
          findsOneWidget,
          reason: '$field: ${result.columnTypes[field]}',
        );
        expect(
          find.descendant(
            of: find.byKey(ValueKey('result-column-type-$field')),
            matching: find.text(result.columnTypes[field]!),
            matchRoot: true,
          ),
          findsOneWidget,
        );
      }
      final table = find.byKey(const ValueKey('result-table-horizontal'));
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('result-column-type-jsonb_value')),
        200,
        scrollable: find.descendant(of: table, matching: find.byType(Scrollable)).first,
      );
      expect(find.text('jsonb'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('column widths fit the header and the first rows, between 80 and 500 px', (tester) async {
      await _Harness(tester).pump(
        QueryResult(
          fields: const ['id', 'note'],
          rows: [
            {'id': 1, 'note': 'x' * 1000},
          ],
          rowCount: 1,
          executionTime: Duration.zero,
        ),
      );

      expect(tester.getSize(find.byKey(const ValueKey('result-header-id'))).width, 80);
      expect(tester.getSize(find.byKey(const ValueKey('result-header-note'))).width, 500);
    });

    testWidgets('500 rows build only the rows on screen, and the header stays pinned as they scroll', (tester) async {
      await _Harness(tester).pump(_page(from: 1, count: 500, limit: 500, hasMore: false));
      final header = find.byKey(const ValueKey('result-table-header'));
      final top = tester.getTopLeft(header).dy;

      expect(find.byType(ResultTableRow).evaluate().length, lessThan(40));
      await tester.scrollUntilVisible(
        find.text('person 500'),
        2000,
        scrollable: find.descendant(of: find.byType(ResultTable), matching: find.byType(Scrollable)).last,
        maxScrolls: 100,
      );

      expect(find.text('person 500'), findsOneWidget);
      expect(find.byType(ResultTableRow).evaluate().length, lessThan(40));
      expect(tester.getTopLeft(header).dy, top);
    });
  });

  group('the card and table toggle', () {
    testWidgets('switches the view and stores the choice', (tester) async {
      final harness = _Harness(tester);
      await harness.pump(_page(from: 1, count: 2, paged: false), mode: ResultViewMode.cards);
      expect(find.byType(ResultCard), findsWidgets);

      await tester.tap(find.byTooltip('Table'));
      await tester.pump();

      expect(find.byType(ResultTable), findsOneWidget);
      expect(find.byType(ResultCard), findsNothing);
      expect(harness.modes.state, ResultViewMode.table);

      await tester.tap(find.byTooltip('Cards'));
      await tester.pump();
      expect(find.byType(ResultCard), findsWidgets);
    });

    testWidgets('is remembered across a rebuild of the view', (tester) async {
      final harness = _Harness(tester);
      await harness.pump(_page(from: 1, count: 2, paged: false), mode: ResultViewMode.cards);
      await tester.tap(find.byTooltip('Table'));
      await tester.pump();

      await harness.rebuild();

      expect(find.byType(ResultTable), findsOneWidget);
    });

    testWidgets('a device that stored the table opens on the table', (tester) async {
      await _Harness(tester).pump(_page(from: 1, count: 2, paged: false));

      expect(find.byType(ResultTable), findsOneWidget);
    });
  });

  group('load more', () {
    testWidgets('names the page size, appends the next page and goes once Studio has no more', (tester) async {
      final harness = _Harness(tester);
      await harness.pump(_page(from: 1, count: 2));

      expect(find.text('Load 2 more'), findsOneWidget);
      await tester.tap(_loadMore);
      await tester.pump();
      await tester.pump();

      expect(harness.requested, [const QueryPage(limit: 2, offset: 2)]);
      expect(find.descendant(of: _row(3), matching: find.text('person 4')), findsOneWidget);
      expect(_loadMore, findsNothing);
    });

    testWidgets('appends in the card view too', (tester) async {
      final harness = _Harness(tester);
      await harness.pump(_page(from: 1, count: 2), mode: ResultViewMode.cards);

      await tester.tap(_loadMore);
      await tester.pump();
      await tester.pump();

      expect(find.text('person 4'), findsOneWidget);
    });

    for (final (name, supports, hasMore, noLoader) in const [
      ('the engine cannot page', false, true, false),
      ('Studio has no more', true, false, false),
      ('the caller gave no loadPage', true, true, true),
    ]) {
      testWidgets('is not offered, nor the order notice, when $name', (tester) async {
        await _Harness(tester).pump(
          _page(from: 1, count: 2, hasMore: hasMore),
          supportsResultPagination: supports,
          noLoader: noLoader,
          hasOuterOrderBy: false,
        );

        expect(_loadMore, findsNothing);
        expect(find.text(_orderNotice), findsNothing);
      });
    }

    testWidgets('the order notice shows with the offer and a statement without an outer ORDER BY', (tester) async {
      await _Harness(tester).pump(_page(from: 1, count: 2), hasOuterOrderBy: false);

      expect(find.text(_orderNotice), findsOneWidget);
    });

    for (final (name, hasOuterOrderBy) in const [('an outer ORDER BY', true), ('a statement it cannot read', null)]) {
      testWidgets('the order notice does not show for $name', (tester) async {
        await _Harness(tester).pump(_page(from: 1, count: 2), hasOuterOrderBy: hasOuterOrderBy);

        expect(_loadMore, findsOneWidget);
        expect(find.text(_orderNotice), findsNothing);
      });
    }

    testWidgets('a failed page keeps the rows and shows the banner, and the retry the user taps loads it', (
      tester,
    ) async {
      final harness = _Harness(tester);
      var calls = 0;
      await harness.pump(
        _page(from: 1, count: 2),
        loadPage: (page) async => ++calls == 1
            ? const Failure(ServerError('relation "ledger" is locked', code: 'studio.query_error'))
            : Success(_page(from: 3, count: 2, hasMore: false)),
      );

      await tester.tap(_loadMore);
      await tester.pump();
      await tester.pump();

      expect(find.byType(StudioErrorBanner), findsOneWidget);
      expect(find.textContaining('ledger'), findsNothing);
      expect(find.descendant(of: _row(1), matching: find.text('person 2')), findsOneWidget);
      expect(harness.requested, hasLength(1));

      await tester.pump(const Duration(seconds: 5));
      expect(harness.requested, hasLength(1));

      await tester.tap(find.descendant(of: find.byType(StudioErrorBanner), matching: find.byType(OutlinedButton)));
      await tester.pump();
      await tester.pump();

      expect(harness.requested, hasLength(2));
      expect(find.byType(StudioErrorBanner), findsNothing);
      expect(find.descendant(of: _row(3), matching: find.text('person 4')), findsOneWidget);
    });

    testWidgets('two quick taps send one request', (tester) async {
      final harness = _Harness(tester);
      final answer = Completer<Result<QueryResult>>();
      await harness.pump(_page(from: 1, count: 2), loadPage: (_) => answer.future);

      await tester.tap(_loadMore);
      await tester.tap(_loadMore, warnIfMissed: false);
      await tester.pump();
      expect(find.text('Loading 2 more…'), findsOneWidget);
      await tester.tap(_loadMore, warnIfMissed: false);
      await tester.pump();

      answer.complete(Success(_page(from: 3, count: 2, hasMore: false)));
      await tester.pump();
      await tester.pump();

      expect(harness.requested, hasLength(1));
      expect(find.text('person 4'), findsOneWidget);
    });

    testWidgets('offline the action is disabled with the reason, and a tap sends nothing', (tester) async {
      final harness = _Harness(tester);
      harness.offline.value = true;
      await harness.pump(_page(from: 1, count: 2));

      expect(find.text('Needs an internet connection'), findsOneWidget);
      final button = tester.widget<ButtonStyleButton>(
        find.descendant(of: _loadMore, matching: find.byWidgetPredicate((w) => w is ButtonStyleButton)),
      );
      expect(button.onPressed, isNull);
      await tester.tap(_loadMore, warnIfMissed: false);
      await tester.pump();
      expect(harness.requested, isEmpty);

      harness.offline.value = false;
      await tester.pump();
      expect(find.text('Needs an internet connection'), findsNothing);
    });

    testWidgets('offline a failed page keeps its banner without a retry, and the reason', (tester) async {
      final harness = _Harness(tester);
      await harness.pump(
        _page(from: 1, count: 2),
        loadPage: (_) async => const Failure(NetworkError('no route', code: 'network.unreachable')),
      );
      await tester.tap(_loadMore);
      await tester.pump();
      await tester.pump();

      harness.offline.value = true;
      await tester.pump();

      expect(find.byType(StudioErrorBanner), findsOneWidget);
      expect(find.descendant(of: find.byType(StudioErrorBanner), matching: find.byType(OutlinedButton)), findsNothing);
      expect(find.text('Needs an internet connection'), findsOneWidget);
    });
  });

  testWidgets('rotating the phone keeps the rows, the view mode and the scroll position, with no new request', (
    tester,
  ) async {
    final harness = _Harness(tester);
    await harness.pump(
      _page(from: 1, count: 100, limit: 100),
      screen: const Size(400, 800),
      loadPage: (page) async => Success(_page(from: 101, count: 100, limit: 100, hasMore: false)),
    );
    await tester.tap(_loadMore);
    await tester.pump();
    await tester.pump();
    expect(harness.requested, hasLength(1));
    final rows = find.descendant(of: find.byType(ResultTable), matching: find.byType(Scrollable)).last;
    await tester.scrollUntilVisible(find.text('person 150'), 500, scrollable: rows, maxScrolls: 50);
    final offset = tester.state<ScrollableState>(rows).position.pixels;

    tester.view.physicalSize = const Size(800, 400);
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(ResultTable), findsOneWidget);
    expect(tester.state<ScrollableState>(rows).position.pixels, offset);
    expect(find.text('person 150'), findsOneWidget);
    expect((harness.bloc.state as ResultViewLoaded).result.rows, hasLength(200));
    expect(harness.requested, hasLength(1));
  });
}

class _MemoryStore implements IResultViewModeStore {
  _MemoryStore(this.mode);

  ResultViewMode? mode;

  @override
  Future<ResultViewMode?> read() async => mode;

  @override
  Future<void> write(ResultViewMode mode) async => this.mode = mode;
}
