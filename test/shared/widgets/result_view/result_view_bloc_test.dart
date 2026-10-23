import 'dart:async';
import 'dart:io';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/infrastructure/studio/query_result_json.dart';
import 'package:libredb_mobile/shared/models/query_page.dart';
import 'package:libredb_mobile/shared/models/query_result.dart';
import 'package:libredb_mobile/shared/models/studio_identity.dart';
import 'package:libredb_mobile/shared/security/result_masking/mask_result.dart';
import 'package:libredb_mobile/shared/security/result_masking/masking_policy.dart';
import 'package:libredb_mobile/shared/widgets/result_view/result_view_bloc.dart';

QueryResult _result(List<Map<String, Object?>> rows) => QueryResult(
  fields: const ['id', 'email'],
  rows: rows,
  rowCount: rows.length,
  executionTime: const Duration(milliseconds: 3),
);

QueryResult _page(
  List<Map<String, Object?>> rows, {
  List<String> fields = const ['id', 'email'],
  int offset = 0,
  int limit = 2,
  bool hasMore = true,
}) => QueryResult(
  fields: fields,
  rows: rows,
  rowCount: rows.length,
  executionTime: const Duration(milliseconds: 3),
  pagination: QueryPagination(
    limit: limit,
    offset: offset,
    hasMore: hasMore,
    totalReturned: rows.length,
    wasLimited: hasMore,
  ),
);

QueryResult _fixture(String name) => QueryResultJson.read(File('test/fixtures/studio/$name.json').readAsStringSync());

void main() {
  final policy = MaskingPolicy.forRole(const StudioUserRole());
  final first = maskResult(
    _result(const [
      {'id': 1, 'email': 'alice@example.com'},
    ]),
    policy,
  );
  final second = maskResult(
    _result(const [
      {'id': 2, 'email': 'bob@example.com'},
    ]),
    policy,
  );

  test('starts with the masked result and its masked columns, and keeps the policy it was masked with', () {
    final bloc = ResultViewBloc(masked: first, policy: policy);
    addTearDown(bloc.close);

    expect(bloc.state, ResultViewLoaded(result: first.result, maskedColumns: first.maskedColumns));
    expect(bloc.policy, policy);
    expect(first.maskedColumns, {'email'});
    expect(bloc.state.toString(), isNot(contains('alice@example.com')));
  });

  blocTest<ResultViewBloc, ResultViewState>(
    'a result the caller ran again replaces the one shown',
    build: () => ResultViewBloc(masked: first, policy: policy),
    act: (bloc) => bloc.add(ResultViewReplaced(second)),
    expect: () => [ResultViewLoaded(result: second.result, maskedColumns: second.maskedColumns)],
  );

  blocTest<ResultViewBloc, ResultViewState>(
    'the same result again changes nothing',
    build: () => ResultViewBloc(masked: first, policy: policy),
    act: (bloc) => bloc.add(ResultViewReplaced(first)),
    expect: () => const <ResultViewState>[],
  );

  group('page offer', () {
    final paged = maskResult(
      _page(const [
        {'id': 1, 'email': 'a@example.com'},
        {'id': 2, 'email': null},
      ]),
      policy,
    );
    Future<Result<QueryResult>> load(QueryPage page) async => Success(_page(const []));

    test('offers the page size on screen when the engine pages, Studio has more and the caller can fetch', () {
      final bloc = ResultViewBloc(masked: paged, policy: policy, loadPage: load, supportsResultPagination: true);
      addTearDown(bloc.close);

      expect(bloc.pageOffer(paged.result), 2);
    });

    test('offers nothing when the engine cannot page', () {
      final bloc = ResultViewBloc(masked: paged, policy: policy, loadPage: load, supportsResultPagination: false);
      addTearDown(bloc.close);

      expect(bloc.pageOffer(paged.result), isNull);
    });

    test('offers nothing without a loadPage', () {
      final bloc = ResultViewBloc(masked: paged, policy: policy, supportsResultPagination: true);
      addTearDown(bloc.close);

      expect(bloc.pageOffer(paged.result), isNull);
    });

    test('offers nothing when Studio has no more, or sent no pagination', () {
      final last = maskResult(
        _page(const [
          {'id': 1, 'email': null},
        ], hasMore: false),
        policy,
      );
      final bloc = ResultViewBloc(masked: last, policy: policy, loadPage: load, supportsResultPagination: true);
      addTearDown(bloc.close);

      expect(bloc.pageOffer(last.result), isNull);
      expect(bloc.pageOffer(first.result), isNull);
    });

    test('the order notice shows only with the offer and a statement known to have no outer ORDER BY', () {
      ResultViewBloc build({bool supports = true, bool? hasOuterOrderBy}) {
        final bloc = ResultViewBloc(
          masked: paged,
          policy: policy,
          loadPage: load,
          supportsResultPagination: supports,
          hasOuterOrderBy: hasOuterOrderBy,
        );
        addTearDown(bloc.close);
        return bloc;
      }

      expect(build(hasOuterOrderBy: false).showsOrderNotice(paged.result), isTrue);
      expect(build(hasOuterOrderBy: true).showsOrderNotice(paged.result), isFalse);
      expect(build().showsOrderNotice(paged.result), isFalse);
      expect(build(supports: false, hasOuterOrderBy: false).showsOrderNotice(paged.result), isFalse);
    });
  });

  group('load more', () {
    final page1 = _page(const [
      {'id': 1, 'email': 'alice@example.com'},
      {'id': 2, 'email': 'bob@example.com'},
    ]);
    final page2 = _page(
      const [
        {'id': 3, 'email': 'carol@example.com'},
      ],
      offset: 2,
      hasMore: false,
    );
    final masked1 = maskResult(page1, policy);
    final requested = <QueryPage>[];

    setUp(requested.clear);

    ResultViewBloc build(Future<Result<QueryResult>> Function(QueryPage page) loadPage) => ResultViewBloc(
      masked: masked1,
      policy: policy,
      supportsResultPagination: true,
      loadPage: (page) {
        requested.add(page);
        return loadPage(page);
      },
    );

    blocTest<ResultViewBloc, ResultViewState>(
      'fetches the next page with the same size, masks it with the policy and appends it',
      build: () => build((_) async => Success(page2)),
      act: (bloc) => bloc.add(const ResultViewLoadMoreRequested()),
      expect: () {
        final appended = appendResultPage(masked1.result, maskResult(page2, policy).result);
        return [
          ResultViewLoaded(result: masked1.result, maskedColumns: const {'email'}, loadingMore: true),
          ResultViewLoaded(result: appended, maskedColumns: const {'email'}),
        ];
      },
      verify: (bloc) {
        expect(requested, [const QueryPage(limit: 2, offset: 2)]);
        final state = bloc.state as ResultViewLoaded;
        expect(state.result.rows.map((row) => row['id']), [1, 2, 3]);
        expect(state.result.rows.map((row) => row['email']), everyElement(isNot(contains('@example.com'))));
        expect(state.result.pagination!.hasMore, isFalse);
        expect(bloc.pageOffer(state.result), isNull);
      },
    );

    blocTest<ResultViewBloc, ResultViewState>(
      'a page with fields: [] keeps the columns on screen',
      build: () => build((_) async => Success(_page(const [], fields: const [], offset: 2, hasMore: false))),
      act: (bloc) => bloc.add(const ResultViewLoadMoreRequested()),
      skip: 1,
      verify: (bloc) {
        final state = bloc.state as ResultViewLoaded;
        expect(state.result.fields, ['id', 'email']);
        expect(state.result.rows, masked1.result.rows);
        expect(state.maskedColumns, {'email'});
        expect(state.loadingMore, isFalse);
      },
    );

    blocTest<ResultViewBloc, ResultViewState>(
      'a failed page keeps the rows and holds the error itself, for the banner and its retry delay',
      build: () => build(
        (_) async =>
            const Failure(RateLimitedError('slow down', code: 'studio.rate_limited', retryAfter: Duration(seconds: 3))),
      ),
      act: (bloc) => bloc.add(const ResultViewLoadMoreRequested()),
      expect: () => [
        ResultViewLoaded(result: masked1.result, maskedColumns: const {'email'}, loadingMore: true),
        ResultViewLoadMoreFailed(
          result: masked1.result,
          maskedColumns: const {'email'},
          error: const RateLimitedError('slow down', code: 'studio.rate_limited', retryAfter: Duration(seconds: 3)),
        ),
      ],
      verify: (bloc) {
        final state = bloc.state as ResultViewLoadMoreFailed;
        expect((state.error as RateLimitedError).retryAfter, const Duration(seconds: 3));
        expect(requested, hasLength(1));
      },
    );

    blocTest<ResultViewBloc, ResultViewState>(
      'a failed page is not retried by the app; the user retries it from the failure',
      build: () {
        var calls = 0;
        return build(
          (_) async => ++calls == 1 ? const Failure(ServerError('down', code: 'studio.server')) : Success(page2),
        );
      },
      act: (bloc) async {
        bloc.add(const ResultViewLoadMoreRequested());
        await Future<void>.delayed(Duration.zero);
        expect(requested, hasLength(1));
        bloc.add(const ResultViewLoadMoreRequested());
      },
      skip: 3,
      expect: () => [
        ResultViewLoaded(
          result: appendResultPage(masked1.result, maskResult(page2, policy).result),
          maskedColumns: const {'email'},
        ),
      ],
      verify: (_) => expect(requested, [const QueryPage(limit: 2, offset: 2), const QueryPage(limit: 2, offset: 2)]),
    );

    blocTest<ResultViewBloc, ResultViewState>(
      'a second tap while a page is in flight sends nothing',
      build: () {
        final answer = Completer<Result<QueryResult>>();
        Timer(const Duration(milliseconds: 10), () => answer.complete(Success(page2)));
        return build((_) => answer.future);
      },
      act: (bloc) {
        bloc
          ..add(const ResultViewLoadMoreRequested())
          ..add(const ResultViewLoadMoreRequested());
      },
      wait: const Duration(milliseconds: 50),
      expect: () => [
        ResultViewLoaded(result: masked1.result, maskedColumns: const {'email'}, loadingMore: true),
        ResultViewLoaded(
          result: appendResultPage(masked1.result, maskResult(page2, policy).result),
          maskedColumns: const {'email'},
        ),
      ],
      verify: (_) => expect(requested, hasLength(1)),
    );

    blocTest<ResultViewBloc, ResultViewState>(
      'without an offer a request sends nothing',
      build: () => ResultViewBloc(
        masked: masked1,
        policy: policy,
        supportsResultPagination: false,
        loadPage: (page) async {
          requested.add(page);
          return Success(page2);
        },
      ),
      act: (bloc) => bloc.add(const ResultViewLoadMoreRequested()),
      expect: () => const <ResultViewState>[],
      verify: (_) => expect(requested, isEmpty),
    );

    blocTest<ResultViewBloc, ResultViewState>(
      'a page that arrives after the caller replaced the result is dropped',
      build: () {
        final answer = Completer<Result<QueryResult>>();
        Timer(const Duration(milliseconds: 10), () => answer.complete(Success(page2)));
        return build((_) => answer.future);
      },
      act: (bloc) async {
        bloc.add(const ResultViewLoadMoreRequested());
        await Future<void>.delayed(Duration.zero);
        bloc.add(ResultViewReplaced(second));
      },
      wait: const Duration(milliseconds: 50),
      expect: () => [
        ResultViewLoaded(result: masked1.result, maskedColumns: const {'email'}, loadingMore: true),
        ResultViewLoaded(result: second.result, maskedColumns: second.maskedColumns),
      ],
    );

    test(
      'the recorded sales.ledger pages append to 100 rows, offered after the first page and gone after the second',
      () async {
        final pages = {50: _fixture('query_page_postgres_second'), 100: _fixture('query_page_postgres_third')};
        final bloc = ResultViewBloc(
          masked: maskResult(_fixture('query_page_postgres_first'), policy),
          policy: policy,
          supportsResultPagination: true,
          loadPage: (page) async {
            requested.add(page);
            return Success(pages[page.offset]!);
          },
        );
        addTearDown(bloc.close);

        expect(bloc.pageOffer((bloc.state as ResultViewLoaded).result), 50);
        bloc.add(const ResultViewLoadMoreRequested());
        await bloc.stream.firstWhere((state) => state is ResultViewLoaded && !state.loadingMore);

        final state = bloc.state as ResultViewLoaded;
        expect(requested, [const QueryPage(limit: 50, offset: 50)]);
        expect(state.result.rows, hasLength(100));
        expect(state.result.rows.last['entry'], 'entry 100');
        expect(state.maskedColumns, isEmpty);
        expect(bloc.pageOffer(state.result), isNull);
      },
    );
  });
}
