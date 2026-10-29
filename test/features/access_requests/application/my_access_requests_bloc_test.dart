import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/access_requests/application/my_access_requests_bloc.dart';
import 'package:libredb_mobile/features/access_requests/application/usecases/list_my_access_requests_usecase.dart';
import 'package:libredb_mobile/features/access_requests/domain/entities/my_access_request.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mock_classes.dart';
import '../support/access_request_fixtures.dart';

void main() {
  late MockIAccessRequestRepository repository;

  final first = [fixtureRequest('r1'), fixtureRequest('r2', status: 'approved')];
  final unreachable = NetworkError('down', code: AppErrorCode.platformUnreachable.key);

  setUp(() => repository = MockIAccessRequestRepository());

  MyAccessRequestsBloc build() =>
      MyAccessRequestsBloc(listMyAccessRequestsUseCase: ListMyAccessRequestsUseCase(repository));

  void answer(Result<List<MyAccessRequest>> result) => when(repository.mine).thenAnswer((_) async => result);

  Future<MyAccessRequestsBloc> loaded() async {
    answer(Success(first));
    final bloc = build()..add(const MyAccessRequestsLoadRequested());
    await bloc.stream.firstWhere((state) => state is MyAccessRequestsLoaded);
    return bloc;
  }

  test('starts in MyAccessRequestsInitial', () {
    expect(build().state, const MyAccessRequestsInitial());
  });

  test('a load emits Loading, then Loaded with the requests in Platform order', () async {
    answer(Success(first));
    final bloc = build();
    final states = bloc.stream.take(2).toList();

    bloc.add(const MyAccessRequestsLoadRequested());

    expect(await states, [const MyAccessRequestsLoading(), MyAccessRequestsLoaded(requests: first)]);
    await bloc.close();
  });

  test('a failed load emits Failure with the code', () async {
    answer(Failure(unreachable));
    final bloc = build();
    final states = bloc.stream.take(2).toList();

    bloc.add(const MyAccessRequestsLoadRequested());

    expect(await states, [
      const MyAccessRequestsLoading(),
      const MyAccessRequestsFailure(errorCode: AppErrorCode.platformUnreachable),
    ]);
    await bloc.close();
  });

  test('a load after a failure loads again, as Retry does', () async {
    answer(Failure(unreachable));
    final bloc = build()..add(const MyAccessRequestsLoadRequested());
    await bloc.stream.firstWhere((state) => state is MyAccessRequestsFailure);
    answer(Success(first));

    bloc.add(const MyAccessRequestsLoadRequested());

    expect(
      await bloc.stream.firstWhere((state) => state is MyAccessRequestsLoaded),
      MyAccessRequestsLoaded(requests: first),
    );
    await bloc.close();
  });

  test('a refresh while loaded keeps the list on screen and then shows the new answer', () async {
    final bloc = await loaded();
    final second = [fixtureRequest('r3')];
    answer(Success(second));
    final states = bloc.stream.take(2).toList();

    bloc.add(const MyAccessRequestsRefreshRequested());

    expect(await states, [
      MyAccessRequestsLoaded(requests: first, isRefreshing: true),
      MyAccessRequestsLoaded(requests: second),
    ]);
    await bloc.close();
  });

  test('a failed refresh while loaded keeps the list and carries the code', () async {
    final bloc = await loaded();
    answer(Failure(unreachable));
    final states = bloc.stream.take(2).toList();

    bloc.add(const MyAccessRequestsRefreshRequested());

    expect(await states, [
      MyAccessRequestsLoaded(requests: first, isRefreshing: true),
      MyAccessRequestsLoaded(requests: first, refreshError: AppErrorCode.platformUnreachable),
    ]);
    await bloc.close();
  });

  test('a refresh before any load loads, since there is no list to keep', () async {
    answer(Success(first));
    final bloc = build();
    final states = bloc.stream.take(2).toList();

    bloc.add(const MyAccessRequestsRefreshRequested());

    expect(await states, [const MyAccessRequestsLoading(), MyAccessRequestsLoaded(requests: first)]);
    await bloc.close();
  });

  test('a refresh restarts the running load: only the newer answer lands', () async {
    final slow = Completer<Result<List<MyAccessRequest>>>();
    final newer = [fixtureRequest('r9')];
    var calls = 0;
    when(repository.mine).thenAnswer((_) => ++calls == 1 ? slow.future : Future.value(Success(newer)));
    final bloc = build()..add(const MyAccessRequestsLoadRequested());
    await Future<void>.delayed(Duration.zero);

    bloc.add(const MyAccessRequestsRefreshRequested());
    await bloc.stream.firstWhere((state) => state is MyAccessRequestsLoaded);
    slow.complete(Success(first));
    await Future<void>.delayed(Duration.zero);

    expect(bloc.state, MyAccessRequestsLoaded(requests: newer));
    await bloc.close();
  });

  test('MyAccessRequestReplaced replaces only the row with that id, in place', () async {
    final bloc = await loaded();
    final withdrawn = fixtureRequest('r1', status: 'withdrawn');

    bloc.add(MyAccessRequestReplaced(withdrawn));
    await bloc.stream.firstWhere((state) => state is MyAccessRequestsLoaded && state.requests.first == withdrawn);

    expect(bloc.state, MyAccessRequestsLoaded(requests: [withdrawn, first[1]]));
    verify(repository.mine).called(1);
    await bloc.close();
  });

  test('MyAccessRequestReplaced outside a loaded list does nothing', () async {
    final bloc = build();

    bloc.add(MyAccessRequestReplaced(fixtureRequest('r1')));
    await Future<void>.delayed(Duration.zero);

    expect(bloc.state, const MyAccessRequestsInitial());
    await bloc.close();
  });
}
