import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/platform_audit/application/audit_log_bloc.dart';
import 'package:libredb_mobile/features/platform_audit/application/usecases/list_audit_events_usecase.dart';
import 'package:libredb_mobile/features/platform_audit/domain/entities/audit_event.dart';
import 'package:libredb_mobile/features/platform_audit/domain/entities/audit_filter.dart';
import 'package:libredb_mobile/features/platform_audit/domain/entities/audit_page.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mock_classes.dart';
import '../audit_event_fixture.dart';

List<AuditEvent> _events(int from, int count) => [for (var i = from; i < from + count; i++) auditEvent('e$i')];

AuditPage _page(List<AuditEvent> events, {required int total, int offset = 0}) =>
    AuditPage(events: events, total: total, offset: offset);

void main() {
  late MockIPlatformAuditRepository repository;

  final serverError = ServerError('Platform text', code: AppErrorCode.platformInternalError.key);
  final planRefused = AuthError('403 PLAN_FEATURE_REQUIRED', code: AppErrorCode.platformPlanFeatureRequired.key);
  final permissionRefused = AuthError('403 PERMISSION_DENIED', code: AppErrorCode.platformPermissionDenied.key);

  setUp(() {
    repository = MockIPlatformAuditRepository();
    registerFallbackValue(const AuditFilter());
  });

  AuditLogBloc build() => AuditLogBloc(listAuditEventsUseCase: ListAuditEventsUseCase(repository));

  /// Answers every request with [answer] of its filter and offset.
  void answerWith(FutureOr<Result<AuditPage>> Function(AuditFilter filter, int offset) answer) {
    when(
      () => repository.list(
        filter: any(named: 'filter'),
        offset: any(named: 'offset'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer(
      (invocation) async =>
          answer(invocation.namedArguments[#filter] as AuditFilter, invocation.namedArguments[#offset] as int),
    );
  }

  /// The filters and offsets sent since the last call, as `filter@offset`.
  List<String> sent() {
    final captured = verify(
      () => repository.list(
        filter: captureAny(named: 'filter'),
        offset: captureAny(named: 'offset'),
        limit: any(named: 'limit'),
      ),
    ).captured;
    return [for (var i = 0; i < captured.length; i += 2) '${captured[i]}@${captured[i + 1]}'];
  }

  Future<AuditLogBloc> loaded({int count = 3, int total = 10}) async {
    answerWith((filter, offset) => Success(_page(_events(offset, count), total: total, offset: offset)));
    final bloc = build()..add(const AuditLogRefreshed());
    await bloc.stream.firstWhere((state) => state is AuditLogLoaded);
    return bloc;
  }

  test('starts in AuditLogInitial without filters', () {
    expect(build().state, const AuditLogInitial(filter: AuditFilter()));
  });

  test('the first load asks for the newest events from offset 0', () async {
    answerWith((filter, offset) => Success(_page(_events(0, 3), total: 10)));
    final bloc = build();
    final states = bloc.stream.take(2).toList();

    bloc.add(const AuditLogRefreshed());

    expect(await states, [
      const AuditLogLoading(filter: AuditFilter()),
      AuditLogLoaded(filter: const AuditFilter(), events: _events(0, 3), total: 10, nextOffset: 3),
    ]);
    expect(sent(), ['AuditFilter()@0']);
    expect(bloc.state, isA<AuditLogLoaded>().having((state) => state.hasMore, 'hasMore', isTrue));
    await bloc.close();
  });

  test('a failed first load is AuditLogFailure with the code', () async {
    answerWith((filter, offset) => Failure(serverError));
    final bloc = build()..add(const AuditLogRefreshed());

    expect(
      await bloc.stream.firstWhere((state) => state is! AuditLogLoading),
      const AuditLogFailure(filter: AuditFilter(), errorCode: AppErrorCode.platformInternalError),
    );
    await bloc.close();
  });

  test('a filter change asks again from offset 0 and keeps the list on screen while it runs', () async {
    final next = await loaded();
    next.add(const AuditLogLoadMoreRequested());
    await next.stream.firstWhere((state) => state is AuditLogLoaded && !state.isLoadingMore);
    sent();
    final filter = AuditFilter(status: 'error');
    final states = next.stream.take(2).toList();

    next.add(AuditLogFilterChanged(filter));

    final [running, done] = await states;
    expect(running, isA<AuditLogLoaded>().having((state) => state.isRefreshing, 'isRefreshing', isTrue));
    expect(running.filter, filter);
    expect(done, AuditLogLoaded(filter: filter, events: _events(0, 3), total: 10, nextOffset: 3));
    expect(sent(), ['AuditFilter(status)@0']);
    await next.close();
  });

  test('a newer filter change replaces one still running, so only its answer is shown', () async {
    final slow = Completer<Result<AuditPage>>();
    answerWith((filter, offset) => filter.status == 'error' ? slow.future : Success(_page(_events(100, 1), total: 1)));
    final bloc = build()
      ..add(AuditLogFilterChanged(AuditFilter(status: 'error')))
      ..add(AuditLogFilterChanged(AuditFilter(status: 'success')));
    await bloc.stream.firstWhere((state) => state is AuditLogLoaded);
    slow.complete(Success(_page(_events(0, 3), total: 3)));
    await pumpEventQueue();

    expect(
      bloc.state,
      AuditLogLoaded(
        filter: AuditFilter(status: 'success'),
        events: _events(100, 1),
        total: 1,
      ),
    );
    await bloc.close();
  });

  test('typed search text is sent once the typing pauses for 400 ms, trimmed', () {
    fakeAsync((async) {
      answerWith((filter, offset) => Success(_page(_events(0, 1), total: 1)));
      final bloc = build()..add(const AuditLogRefreshed());
      async.flushMicrotasks();
      expect(sent(), ['AuditFilter()@0']);

      for (final text in ['o', 'or', 'ord', 'orders ']) {
        bloc.add(AuditLogSearchChanged(text));
        async.elapse(const Duration(milliseconds: 300));
      }
      async.elapse(const Duration(milliseconds: 99));
      expect(() => sent(), throwsA(isA<TestFailure>()), reason: 'nothing is sent within 400 ms of the last key');

      async.elapse(const Duration(milliseconds: 1));
      expect(sent(), ['AuditFilter(search)@0']);
      expect(bloc.state.filter.search, 'orders');
      bloc.close();
    });
  });

  test('an unchanged trimmed text sends nothing, and typing away and back within 400 ms sends nothing', () {
    fakeAsync((async) {
      answerWith((filter, offset) => Success(_page(_events(0, 1), total: 1)));
      final bloc = build()..add(AuditLogFilterChanged(AuditFilter(search: 'orders')));
      async.flushMicrotasks();
      sent();

      bloc.add(const AuditLogSearchChanged(' orders  '));
      async.elapse(const Duration(seconds: 1));
      bloc
        ..add(const AuditLogSearchChanged('order'))
        ..add(const AuditLogSearchChanged('orders'));
      async.elapse(const Duration(seconds: 1));

      expect(() => sent(), throwsA(isA<TestFailure>()));
      bloc.close();
    });
  });

  test('clearing the search text unsets the search filter', () {
    fakeAsync((async) {
      answerWith((filter, offset) => Success(_page(_events(0, 1), total: 1)));
      final bloc = build()..add(AuditLogFilterChanged(AuditFilter(search: 'orders', status: 'error')));
      async.flushMicrotasks();
      sent();

      bloc.add(const AuditLogSearchChanged('  '));
      async.elapse(const Duration(milliseconds: 400));

      expect(sent(), ['AuditFilter(status)@0']);
      bloc.close();
    });
  });

  test('a filter change drops a search still waiting for its pause', () {
    fakeAsync((async) {
      answerWith((filter, offset) => Success(_page(_events(0, 1), total: 1)));
      final bloc = build()..add(const AuditLogRefreshed());
      async.flushMicrotasks();
      sent();

      bloc
        ..add(const AuditLogSearchChanged('orders'))
        ..add(AuditLogFilterChanged(AuditFilter(status: 'error')));
      async.elapse(const Duration(seconds: 1));

      expect(sent(), ['AuditFilter(status)@0']);
      bloc.close();
    });
  });

  test('Load more asks from the end of the rows read so far and appends the page', () async {
    final bloc = await loaded();
    sent();

    bloc.add(const AuditLogLoadMoreRequested());
    final state = await bloc.stream.firstWhere((state) => state is AuditLogLoaded && !state.isLoadingMore);

    expect(state, AuditLogLoaded(filter: const AuditFilter(), events: _events(0, 6), total: 10, nextOffset: 6));
    expect(sent(), ['AuditFilter()@3']);
    await bloc.close();
  });

  test('a second Load more while one runs is dropped', () async {
    final bloc = await loaded();
    sent();
    final page = Completer<Result<AuditPage>>();
    answerWith((filter, offset) => page.future);

    bloc
      ..add(const AuditLogLoadMoreRequested())
      ..add(const AuditLogLoadMoreRequested());
    await pumpEventQueue();
    expect(bloc.state, isA<AuditLogLoaded>().having((state) => state.isLoadingMore, 'isLoadingMore', isTrue));
    page.complete(Success(_page(_events(3, 3), total: 10, offset: 3)));
    await pumpEventQueue();

    expect(sent(), ['AuditFilter()@3']);
    expect((bloc.state as AuditLogLoaded).events, _events(0, 6));
    await bloc.close();
  });

  test('a Load more answer that arrives after a filter change is dropped', () async {
    final bloc = await loaded();
    final oldPage = Completer<Result<AuditPage>>();
    answerWith(
      (filter, offset) => filter.status == 'error' ? Success(_page([auditEvent('x1')], total: 1)) : oldPage.future,
    );

    bloc.add(const AuditLogLoadMoreRequested());
    await pumpEventQueue();
    bloc.add(AuditLogFilterChanged(AuditFilter(status: 'error')));
    await bloc.stream.firstWhere((state) => state is AuditLogLoaded && !state.isRefreshing);
    oldPage.complete(Success(_page(_events(3, 3), total: 10, offset: 3)));
    await pumpEventQueue();

    expect(
      bloc.state,
      AuditLogLoaded(
        filter: AuditFilter(status: 'error'),
        events: [auditEvent('x1')],
        total: 1,
      ),
    );
    await bloc.close();
  });

  test('a Load more answer that arrives after a refresh of the same filter is dropped', () async {
    final bloc = await loaded();
    final oldPage = Completer<Result<AuditPage>>();
    answerWith((filter, offset) => offset == 0 ? Success(_page(_events(50, 3), total: 10)) : oldPage.future);

    bloc.add(const AuditLogLoadMoreRequested());
    await pumpEventQueue();
    bloc.add(const AuditLogRefreshed());
    await bloc.stream.firstWhere((state) => state is AuditLogLoaded && !state.isRefreshing);
    oldPage.complete(Success(_page(_events(3, 3), total: 10, offset: 3)));
    await pumpEventQueue();

    expect((bloc.state as AuditLogLoaded).events, _events(50, 3));
    await bloc.close();
  });

  test('an event already listed is not listed again when the next page repeats it', () async {
    answerWith(
      (filter, offset) => Success(
        offset == 0
            ? _page(_events(0, 3), total: 7)
            // A new event moved every older one down a place, so this page starts with e2 again.
            : _page(_events(2, 3), total: 7, offset: 3),
      ),
    );
    final bloc = build()..add(const AuditLogRefreshed());
    await bloc.stream.firstWhere((state) => state is AuditLogLoaded);

    bloc.add(const AuditLogLoadMoreRequested());
    final state = await bloc.stream.firstWhere((state) => state is AuditLogLoaded && !state.isLoadingMore);

    expect((state as AuditLogLoaded).events.map((event) => event.eventId), ['e0', 'e1', 'e2', 'e3', 'e4']);
    await bloc.close();
  });

  test('hasMore turns false once the rows read reach the total, and Load more then sends nothing', () async {
    final bloc = await loaded(count: 3, total: 6);
    sent();

    bloc.add(const AuditLogLoadMoreRequested());
    final state = await bloc.stream.firstWhere((state) => state is AuditLogLoaded && !state.isLoadingMore);
    expect((state as AuditLogLoaded).hasMore, isFalse);
    expect(sent(), ['AuditFilter()@3']);

    bloc.add(const AuditLogLoadMoreRequested());
    await pumpEventQueue();
    expect(() => sent(), throwsA(isA<TestFailure>()));
    await bloc.close();
  });

  test('a first page that holds every event has no more', () async {
    final bloc = await loaded(count: 3, total: 3);

    expect((bloc.state as AuditLogLoaded).hasMore, isFalse);
    await bloc.close();
  });

  test('an empty page ends the paging even when the total says more', () async {
    final bloc = await loaded(count: 3, total: 10);
    answerWith((filter, offset) => Success(_page(const [], total: 10, offset: offset)));

    bloc.add(const AuditLogLoadMoreRequested());
    final state = await bloc.stream.firstWhere((state) => state is AuditLogLoaded && !state.isLoadingMore);

    expect((state as AuditLogLoaded).hasMore, isFalse);
    expect(state.events, _events(0, 3));
    await bloc.close();
  });

  test('a failed Load more keeps the list with loadMoreError, and the next Load more clears it', () async {
    final bloc = await loaded();
    answerWith((filter, offset) => Failure(serverError));

    bloc.add(const AuditLogLoadMoreRequested());
    final failed = await bloc.stream.firstWhere((state) => state is AuditLogLoaded && !state.isLoadingMore);

    expect(
      failed,
      AuditLogLoaded(
        filter: const AuditFilter(),
        events: _events(0, 3),
        total: 10,
        nextOffset: 3,
        loadMoreError: AppErrorCode.platformInternalError,
      ),
    );

    answerWith((filter, offset) => Success(_page(_events(3, 3), total: 10, offset: 3)));
    bloc.add(const AuditLogLoadMoreRequested());
    final running = await bloc.stream.first;
    expect((running as AuditLogLoaded).loadMoreError, isNull);
    await bloc.close();
  });

  test('a failed refresh keeps the list with refreshError', () async {
    final bloc = await loaded();
    answerWith((filter, offset) => Failure(serverError));

    bloc.add(const AuditLogRefreshed());
    final state = await bloc.stream.firstWhere((state) => state is AuditLogLoaded && !state.isRefreshing);

    expect(
      state,
      AuditLogLoaded(
        filter: const AuditFilter(),
        events: _events(0, 3),
        total: 10,
        nextOffset: 3,
        refreshError: AppErrorCode.platformInternalError,
      ),
    );
    await bloc.close();
  });

  test('a failed filter change keeps the filter of the listed rows, so Load more goes on with that filter', () async {
    final bloc = await loaded();
    sent();
    answerWith(
      (filter, offset) => filter.status == 'error'
          ? Failure(serverError)
          : Success(_page(_events(offset, 3), total: 10, offset: offset)),
    );

    bloc.add(AuditLogFilterChanged(AuditFilter(status: 'error')));
    final failed = await bloc.stream.firstWhere((state) => state is AuditLogLoaded && !state.isRefreshing);

    expect(
      failed,
      AuditLogLoaded(
        filter: const AuditFilter(),
        events: _events(0, 3),
        total: 10,
        nextOffset: 3,
        refreshError: AppErrorCode.platformInternalError,
      ),
    );

    bloc.add(const AuditLogLoadMoreRequested());
    final more = await bloc.stream.firstWhere((state) => state is AuditLogLoaded && !state.isLoadingMore);

    expect(sent(), ['AuditFilter(status)@0', 'AuditFilter()@3']);
    expect(more, AuditLogLoaded(filter: const AuditFilter(), events: _events(0, 6), total: 10, nextOffset: 6));
    await bloc.close();
  });

  test('a failed filter change that replaced another still running keeps the filter of the listed rows', () async {
    final bloc = await loaded();
    final slow = Completer<Result<AuditPage>>();
    answerWith(
      (filter, offset) => switch (filter.status) {
        'error' => slow.future,
        _ => Failure(serverError),
      },
    );

    bloc
      ..add(AuditLogFilterChanged(AuditFilter(status: 'error')))
      ..add(AuditLogFilterChanged(AuditFilter(status: 'success')));
    final failed = await bloc.stream.firstWhere((state) => state is AuditLogLoaded && state.refreshError != null);
    slow.complete(Success(_page(_events(50, 3), total: 3)));
    await pumpEventQueue();

    expect(failed.filter, const AuditFilter());
    expect(bloc.state, failed);
    expect((bloc.state as AuditLogLoaded).events, _events(0, 3));
    await bloc.close();
  });

  test('a failed refresh of an empty list stays a loaded empty list with refreshError', () async {
    final bloc = await loaded(count: 0, total: 0);
    answerWith((filter, offset) => Failure(serverError));

    bloc.add(const AuditLogRefreshed());
    final state = await bloc.stream.firstWhere((state) => state is AuditLogLoaded && !state.isRefreshing);

    expect(
      state,
      isA<AuditLogLoaded>().having((s) => s.refreshError, 'refreshError', AppErrorCode.platformInternalError),
    );
    await bloc.close();
  });

  test('a refresh after a failure loads again, as the retry does', () async {
    answerWith((filter, offset) => Failure(serverError));
    final bloc = build()..add(const AuditLogRefreshed());
    await bloc.stream.firstWhere((state) => state is AuditLogFailure);
    answerWith((filter, offset) => Success(_page(_events(0, 1), total: 1)));
    final states = bloc.stream.take(2).toList();

    bloc.add(const AuditLogRefreshed());

    expect(await states, [
      const AuditLogLoading(filter: AuditFilter()),
      AuditLogLoaded(filter: const AuditFilter(), events: _events(0, 1), total: 1),
    ]);
    await bloc.close();
  });

  group('refusals', () {
    for (final (name, error, matcher) in [
      ('PLAN_FEATURE_REQUIRED', planRefused, isA<AuditLogPlanRefused>()),
      ('PERMISSION_DENIED', permissionRefused, isA<AuditLogPermissionRefused>()),
    ]) {
      test('$name on the first load gets its own state', () async {
        answerWith((filter, offset) => Failure(error));
        final bloc = build()..add(const AuditLogRefreshed());

        expect(await bloc.stream.firstWhere((state) => state is! AuditLogLoading), matcher);
        await bloc.close();
      });

      test('$name on a refresh replaces the loaded list', () async {
        final bloc = await loaded();
        answerWith((filter, offset) => Failure(error));

        bloc.add(const AuditLogRefreshed());

        expect(await bloc.stream.firstWhere((state) => state is! AuditLogLoaded), matcher);
        await bloc.close();
      });

      test('$name on a filter change replaces the loaded list and carries the filter', () async {
        final bloc = await loaded();
        answerWith((filter, offset) => Failure(error));

        bloc.add(AuditLogFilterChanged(AuditFilter(status: 'error')));
        final state = await bloc.stream.firstWhere((state) => state is! AuditLogLoaded);

        expect(state, matcher);
        expect(state.filter, AuditFilter(status: 'error'));
        await bloc.close();
      });

      test('$name on Load more replaces the loaded list', () async {
        final bloc = await loaded();
        answerWith((filter, offset) => Failure(error));

        bloc.add(const AuditLogLoadMoreRequested());

        expect(await bloc.stream.firstWhere((state) => state is! AuditLogLoaded), matcher);
        await bloc.close();
      });
    }
  });

  test('the text of an event names no search text', () {
    expect(const AuditLogSearchChanged('secret orders').toString(), isNot(contains('secret')));
    expect(AuditLogFilterChanged(AuditFilter(search: 'secret')).toString(), isNot(contains('secret')));
  });
}
