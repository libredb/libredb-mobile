import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/platform_grants/application/directory_picker_bloc.dart';
import 'package:libredb_mobile/features/platform_grants/application/usecases/search_directory_usecase.dart';
import 'package:libredb_mobile/features/platform_grants/domain/entities/directory_page.dart';
import 'package:libredb_mobile/features/platform_grants/domain/entities/directory_user.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mock_classes.dart';

DirectoryUser _user(String id) => DirectoryUser(
  id: id,
  username: 'user-$id',
  email: null,
  firstName: null,
  lastName: null,
  enabled: true,
  studioRole: 'user',
  needsSeat: false,
);

List<DirectoryUser> _users(int from, int count) => [for (var i = from; i < from + count; i++) _user('u$i')];

DirectoryPage _page(int page, List<DirectoryUser> users, {required int total}) =>
    DirectoryPage(users: users, page: page, total: total);

const _down = Failure<DirectoryPage>(ServerError('503', code: 'platform.directory_unavailable'));

void main() {
  late MockPlatformDirectoryRepository repository;

  setUp(() => repository = MockPlatformDirectoryRepository());

  DirectoryPickerBloc build() => DirectoryPickerBloc(searchDirectoryUseCase: SearchDirectoryUseCase(repository));

  void answer(Result<DirectoryPage> Function(String query, int page) answer) => when(
    () => repository.search(
      query: any(named: 'query'),
      page: any(named: 'page'),
    ),
  ).thenAnswer((call) async => answer(call.namedArguments[#query] as String, call.namedArguments[#page] as int));

  /// Every request sent so far as `query@page`, in order; the calls are cleared, so the next read starts afresh.
  List<String> sent() {
    final calls = verify(
      () => repository.search(
        query: captureAny(named: 'query'),
        page: captureAny(named: 'page'),
      ),
    ).captured;
    clearInteractions(repository);
    return [for (var i = 0; i < calls.length; i += 2) '${calls[i]}@${calls[i + 1]}'];
  }

  List<String> sentOrNone() {
    try {
      return sent();
    } on TestFailure {
      return const [];
    }
  }

  void typeKeys(FakeAsync async, DirectoryPickerBloc bloc, List<String> texts, {Duration gap = Duration.zero}) {
    for (final text in texts) {
      bloc.add(DirectoryPickerQueryChanged(text));
      async.flushMicrotasks();
      async.elapse(gap);
    }
  }

  test('opening sends exactly one request at once: page 1 with an empty query', () {
    fakeAsync((async) {
      answer((_, page) => Success(_page(page, _users(0, 20), total: 43)));
      final bloc = build()..add(const DirectoryPickerOpened());
      async.flushMicrotasks();

      expect(sent(), ['@1']);
      expect(bloc.state.status, DirectoryPickerStatus.loaded);
      expect(bloc.state.users, hasLength(20));
      expect(bloc.state.total, 43);

      async.elapse(const Duration(seconds: 2));
      expect(sentOrNone(), isEmpty);
      bloc.close();
    });
  });

  test('typing a, l, i, c, e with less than 400 ms between keys sends one more request, for alice', () {
    fakeAsync((async) {
      answer((query, page) => Success(_page(page, _users(0, 3), total: 3)));
      final bloc = build()..add(const DirectoryPickerOpened());
      async.flushMicrotasks();
      expect(sent(), ['@1']);

      typeKeys(async, bloc, ['a', 'al', 'ali', 'alic', 'alice'], gap: const Duration(milliseconds: 300));
      async.elapse(const Duration(milliseconds: 399 - 300));
      expect(sentOrNone(), isEmpty);

      async.elapse(const Duration(milliseconds: 1));
      expect(sent(), ['alice@1']);
      expect(bloc.state.query, 'alice');

      async.elapse(const Duration(seconds: 2));
      expect(sentOrNone(), isEmpty);
      bloc.close();
    });
  });

  test('"alice " after alice sends nothing, and typing away and back within 400 ms sends nothing', () {
    fakeAsync((async) {
      answer((query, page) => Success(_page(page, _users(0, 3), total: 3)));
      final bloc = build()..add(const DirectoryPickerOpened());
      async.flushMicrotasks();
      typeKeys(async, bloc, ['alice']);
      async.elapse(DirectoryPickerBloc.debounce);
      expect(sent(), ['@1', 'alice@1']);

      typeKeys(async, bloc, ['alice ', '  alice']);
      async.elapse(DirectoryPickerBloc.debounce * 2);
      expect(sentOrNone(), isEmpty);

      typeKeys(async, bloc, ['alic', 'alice'], gap: const Duration(milliseconds: 200));
      async.elapse(DirectoryPickerBloc.debounce * 2);
      expect(sentOrNone(), isEmpty);
      bloc.close();
    });
  });

  test('a query typed while it is in flight is not sent again', () {
    fakeAsync((async) {
      final pending = Completer<Result<DirectoryPage>>();
      when(
        () => repository.search(
          query: any(named: 'query'),
          page: any(named: 'page'),
        ),
      ).thenAnswer(
        (call) => call.namedArguments[#query] == 'bob' ? pending.future : Future.value(Success(_page(1, [], total: 0))),
      );
      final bloc = build()..add(const DirectoryPickerOpened());
      async.flushMicrotasks();
      typeKeys(async, bloc, ['bob']);
      async.elapse(DirectoryPickerBloc.debounce);
      expect(sent(), ['@1', 'bob@1']);

      typeKeys(async, bloc, ['bo', 'bob '], gap: const Duration(milliseconds: 100));
      async.elapse(DirectoryPickerBloc.debounce * 2);
      expect(sentOrNone(), isEmpty);
      pending.complete(Success(_page(1, _users(0, 1), total: 1)));
      async.flushMicrotasks();
      expect(bloc.state.users, hasLength(1));
      bloc.close();
    });
  });

  test('after a failure, Retry sends the same query again and shows its answer', () {
    fakeAsync((async) {
      var fail = true;
      answer((query, page) => fail ? _down : Success(_page(page, _users(0, 2), total: 2)));
      final bloc = build()..add(const DirectoryPickerOpened());
      async.flushMicrotasks();
      expect(bloc.state.status, DirectoryPickerStatus.failure);
      expect(bloc.state.error, AppErrorCode.platformDirectoryUnavailable);
      typeKeys(async, bloc, ['carol']);
      async.elapse(DirectoryPickerBloc.debounce);
      expect(sent(), ['@1', 'carol@1']);
      expect(bloc.state.status, DirectoryPickerStatus.failure);

      fail = false;
      bloc.add(const DirectoryPickerRetryRequested());
      async.flushMicrotasks();

      expect(sent(), ['carol@1']);
      expect(bloc.state.status, DirectoryPickerStatus.loaded);
      expect(bloc.state.users, hasLength(2));
      bloc.close();
    });
  });

  test('a trimmed query of 256 code units is not sent and shows the hint; one of 255 is sent', () {
    fakeAsync((async) {
      answer((query, page) => Success(_page(page, [], total: 0)));
      final bloc = build()..add(const DirectoryPickerOpened());
      async.flushMicrotasks();
      sent();

      typeKeys(async, bloc, ['  ${'x' * 256} ']);
      async.elapse(DirectoryPickerBloc.debounce * 2);
      expect(sentOrNone(), isEmpty);
      expect(bloc.state.queryTooLong, isTrue);

      // An emoji is two UTF-16 code units, as JavaScript counts them on Platform.
      typeKeys(async, bloc, ['${'x' * 254}\u{1F600}']);
      async.elapse(DirectoryPickerBloc.debounce * 2);
      expect(sentOrNone(), isEmpty);
      expect(bloc.state.queryTooLong, isTrue);

      typeKeys(async, bloc, ['x' * 255]);
      expect(bloc.state.queryTooLong, isFalse);
      async.elapse(DirectoryPickerBloc.debounce);
      expect(sent(), ['${'x' * 255}@1']);
      bloc.close();
    });
  });

  test('a newer query wins: the answer to an older query is never shown', () {
    fakeAsync((async) {
      final slow = Completer<Result<DirectoryPage>>();
      when(
        () => repository.search(
          query: any(named: 'query'),
          page: any(named: 'page'),
        ),
      ).thenAnswer((call) {
        return switch (call.namedArguments[#query]) {
          'old' => slow.future,
          'new' => Future.value(Success(_page(1, [_user('new')], total: 1))),
          _ => Future.value(Success(_page(1, [], total: 0))),
        };
      });
      final bloc = build()..add(const DirectoryPickerOpened());
      async.flushMicrotasks();
      typeKeys(async, bloc, ['old']);
      async.elapse(DirectoryPickerBloc.debounce);
      typeKeys(async, bloc, ['new']);
      async.elapse(DirectoryPickerBloc.debounce);
      expect(bloc.state.users.single.id, 'new');

      slow.complete(Success(_page(1, [_user('old')], total: 1)));
      async.flushMicrotasks();

      expect(bloc.state.query, 'new');
      expect(bloc.state.users.single.id, 'new');
      bloc.close();
    });
  });

  test('a load more answer that arrives after a new query is never shown', () {
    fakeAsync((async) {
      final page2 = Completer<Result<DirectoryPage>>();
      when(
        () => repository.search(
          query: any(named: 'query'),
          page: any(named: 'page'),
        ),
      ).thenAnswer((call) {
        if (call.namedArguments[#page] == 2) return page2.future;
        final query = call.namedArguments[#query] as String;
        return Future.value(Success(_page(1, query.isEmpty ? _users(0, 20) : [_user('dan')], total: 43)));
      });
      final bloc = build()..add(const DirectoryPickerOpened());
      async.flushMicrotasks();
      bloc.add(const DirectoryPickerLoadMoreRequested());
      async.flushMicrotasks();
      typeKeys(async, bloc, ['dan']);
      async.elapse(DirectoryPickerBloc.debounce);

      page2.complete(Success(_page(2, _users(20, 20), total: 43)));
      async.flushMicrotasks();

      expect(bloc.state.query, 'dan');
      expect(bloc.state.users.map((user) => user.id), ['dan']);
      expect(bloc.state.page, 1);
      bloc.close();
    });
  });

  test('load more on a new query is sent while a page of the older query still waits', () {
    fakeAsync((async) {
      final stalePage2 = Completer<Result<DirectoryPage>>();
      final xPage2 = Completer<Result<DirectoryPage>>();
      when(
        () => repository.search(
          query: any(named: 'query'),
          page: any(named: 'page'),
        ),
      ).thenAnswer((call) {
        final query = call.namedArguments[#query] as String;
        if (call.namedArguments[#page] == 2) return query.isEmpty ? stalePage2.future : xPage2.future;
        return Future.value(Success(_page(1, query.isEmpty ? _users(0, 20) : _users(100, 20), total: 43)));
      });
      final bloc = build()..add(const DirectoryPickerOpened());
      async.flushMicrotasks();
      bloc.add(const DirectoryPickerLoadMoreRequested());
      async.flushMicrotasks();
      typeKeys(async, bloc, ['x']);
      async.elapse(DirectoryPickerBloc.debounce);
      expect(bloc.state.query, 'x');
      expect(bloc.state.canLoadMore, isTrue);

      bloc.add(const DirectoryPickerLoadMoreRequested());
      async.flushMicrotasks();

      expect(sent(), ['@1', '@2', 'x@1', 'x@2']);
      expect(bloc.state.loadingMore, isTrue);

      stalePage2.complete(Success(_page(2, _users(20, 20), total: 43)));
      async.flushMicrotasks();
      expect(bloc.state.loadingMore, isTrue);
      expect(bloc.state.page, 1);

      xPage2.complete(Success(_page(2, _users(120, 20), total: 43)));
      async.flushMicrotasks();
      expect(bloc.state.loadingMore, isFalse);
      expect(bloc.state.page, 2);
      expect(bloc.state.users.map((user) => user.id), [for (var i = 100; i < 140; i++) 'u$i']);
      bloc.close();
    });
  });

  group('load more', () {
    test('sends page 2 with the same query, and a double tap sends one request', () {
      fakeAsync((async) {
        final page2 = Completer<Result<DirectoryPage>>();
        when(
          () => repository.search(
            query: any(named: 'query'),
            page: any(named: 'page'),
          ),
        ).thenAnswer(
          (call) => call.namedArguments[#page] == 2
              ? page2.future
              : Future.value(Success(_page(1, _users(0, 20), total: 43))),
        );
        final bloc = build()..add(const DirectoryPickerOpened());
        async.flushMicrotasks();
        typeKeys(async, bloc, ['e']);
        async.elapse(DirectoryPickerBloc.debounce);
        expect(sent(), ['@1', 'e@1']);

        bloc.add(const DirectoryPickerLoadMoreRequested());
        async.flushMicrotasks();
        expect(bloc.state.loadingMore, isTrue);
        bloc.add(const DirectoryPickerLoadMoreRequested());
        async.flushMicrotasks();
        page2.complete(Success(_page(2, _users(20, 20), total: 43)));
        async.flushMicrotasks();

        expect(sent(), ['e@2']);
        expect(bloc.state.users, hasLength(40));
        expect(bloc.state.page, 2);
        expect(bloc.state.query, 'e');
        expect(bloc.state.canLoadMore, isTrue);
        bloc.close();
      });
    });

    test('is not offered at total', () {
      fakeAsync((async) {
        answer((query, page) => Success(_page(page, _users((page - 1) * 20, 20), total: 40)));
        final bloc = build()..add(const DirectoryPickerOpened());
        async.flushMicrotasks();
        expect(bloc.state.canLoadMore, isTrue);
        bloc.add(const DirectoryPickerLoadMoreRequested());
        async.flushMicrotasks();
        expect(bloc.state.page, 2);
        expect(bloc.state.canLoadMore, isFalse);
        sent();

        bloc.add(const DirectoryPickerLoadMoreRequested());
        async.flushMicrotasks();
        expect(sentOrNone(), isEmpty);
        bloc.close();
      });
    });

    test('is not offered after a page of fewer than 20 users, whatever the total says', () {
      fakeAsync((async) {
        answer((query, page) => Success(_page(page, _users(0, 19), total: 500)));
        final bloc = build()..add(const DirectoryPickerOpened());
        async.flushMicrotasks();
        expect(bloc.state.canLoadMore, isFalse);
        sent();

        bloc.add(const DirectoryPickerLoadMoreRequested());
        async.flushMicrotasks();
        expect(sentOrNone(), isEmpty);
        bloc.close();
      });
    });

    test('is not offered at page 100000', () {
      expect(
        DirectoryPickerState(
          status: DirectoryPickerStatus.loaded,
          query: '',
          users: _users(0, 20),
          page: DirectoryPage.maxPage,
          total: DirectoryPage.maxPage * 40,
          lastPageSize: 20,
        ).canLoadMore,
        isFalse,
      );
      expect(
        DirectoryPickerState(
          status: DirectoryPickerStatus.loaded,
          query: '',
          users: _users(0, 20),
          page: DirectoryPage.maxPage - 1,
          total: DirectoryPage.maxPage * 40,
          lastPageSize: 20,
        ).canLoadMore,
        isTrue,
      );
    });

    test('does not add a user whose id is already listed', () {
      fakeAsync((async) {
        answer(
          (query, page) =>
              Success(_page(page, page == 1 ? _users(0, 20) : [..._users(15, 5), ..._users(20, 15)], total: 43)),
        );
        final bloc = build()..add(const DirectoryPickerOpened());
        async.flushMicrotasks();

        bloc.add(const DirectoryPickerLoadMoreRequested());
        async.flushMicrotasks();

        expect(bloc.state.users.map((user) => user.id), [for (var i = 0; i < 35; i++) 'u$i']);
        bloc.close();
      });
    });

    test('a failure keeps the loaded users and shows an inline retry, which asks for the same page', () {
      fakeAsync((async) {
        var failPage2 = true;
        answer(
          (query, page) =>
              page == 2 && failPage2 ? _down : Success(_page(page, _users((page - 1) * 20, 20), total: 43)),
        );
        final bloc = build()..add(const DirectoryPickerOpened());
        async.flushMicrotasks();
        bloc.add(const DirectoryPickerLoadMoreRequested());
        async.flushMicrotasks();

        expect(bloc.state.status, DirectoryPickerStatus.loaded);
        expect(bloc.state.users, hasLength(20));
        expect(bloc.state.loadMoreError, AppErrorCode.platformDirectoryUnavailable);
        expect(sent(), ['@1', '@2']);

        failPage2 = false;
        bloc.add(const DirectoryPickerLoadMoreRequested());
        async.flushMicrotasks();
        expect(sent(), ['@2']);
        expect(bloc.state.users, hasLength(40));
        expect(bloc.state.loadMoreError, isNull);
        bloc.close();
      });
    });
  });

  test('a failed first page shows the error state', () {
    fakeAsync((async) {
      answer((_, _) => _down);
      final bloc = build()..add(const DirectoryPickerOpened());
      async.flushMicrotasks();

      expect(bloc.state.status, DirectoryPickerStatus.failure);
      expect(bloc.state.users, isEmpty);
      bloc.close();
    });
  });
}
