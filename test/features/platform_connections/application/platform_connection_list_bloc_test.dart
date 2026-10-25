import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/platform_connections/application/platform_connection_list_bloc.dart';
import 'package:libredb_mobile/features/platform_connections/application/usecases/list_connections_usecase.dart';
import 'package:libredb_mobile/shared/models/platform_connection.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mock_classes.dart';
import '../../../support/printed_lines.dart';

void main() {
  late MockIPlatformConnectionRepository repository;

  const orders = PlatformConnection(
    id: 'c1',
    name: 'Orders',
    engine: 'postgres',
    status: 'active',
    hasWriteCredential: true,
  );
  const cache = PlatformConnection(
    id: 'c2',
    name: 'İstanbul Önbellek',
    engine: 'redis',
    status: 'active',
    hasWriteCredential: true,
  );
  const billing = PlatformConnection(
    id: 'c3',
    name: 'Legacy Billing',
    engine: 'mysql',
    status: 'inactive',
    hasWriteCredential: false,
  );
  const all = [orders, cache, billing];
  final serverError = ServerError('Platform text', code: AppErrorCode.platformInternalError.key);

  setUp(() {
    repository = MockIPlatformConnectionRepository();
  });

  PlatformConnectionListBloc build() =>
      PlatformConnectionListBloc(listPlatformConnectionsUseCase: ListPlatformConnectionsUseCase(repository));

  void answer(Result<List<PlatformConnection>> result) => when(() => repository.list()).thenAnswer((_) async => result);

  Future<PlatformConnectionListBloc> loaded() async {
    answer(const Success(all));
    final bloc = build()..add(const PlatformConnectionListRequested());
    await bloc.stream.firstWhere((state) => state is PlatformConnectionListLoaded);
    return bloc;
  }

  test('starts in PlatformConnectionListInitial', () {
    expect(build().state, const PlatformConnectionListInitial());
  });

  test('emits Loading then Loaded on request', () async {
    answer(const Success(all));
    final bloc = build();
    final states = bloc.stream.take(2).toList();

    bloc.add(const PlatformConnectionListRequested());

    expect(await states, [const PlatformConnectionListLoading(), const PlatformConnectionListLoaded(connections: all)]);
    await bloc.close();
  });

  test('emits Failure with the code of an error', () async {
    answer(Failure(serverError));
    final bloc = build();
    final states = bloc.stream.take(2).toList();

    bloc.add(const PlatformConnectionListRequested());

    expect(await states, [
      const PlatformConnectionListLoading(),
      const PlatformConnectionListFailure(errorCode: AppErrorCode.platformInternalError),
    ]);
    await bloc.close();
  });

  test('a code the app does not know fails with the generic code', () async {
    answer(Failure(ServerError('Platform text')));
    final bloc = build()..add(const PlatformConnectionListRequested());

    expect(
      await bloc.stream.firstWhere((state) => state is PlatformConnectionListFailure),
      const PlatformConnectionListFailure(errorCode: AppErrorCode.generic),
    );
    await bloc.close();
  });

  test('a retry from Failure emits Loading then Loaded', () async {
    answer(Failure(serverError));
    final bloc = build()..add(const PlatformConnectionListRequested());
    await bloc.stream.firstWhere((state) => state is PlatformConnectionListFailure);
    answer(const Success(all));
    final states = bloc.stream.take(2).toList();

    bloc.add(const PlatformConnectionListRefreshed());

    expect(await states, [const PlatformConnectionListLoading(), const PlatformConnectionListLoaded(connections: all)]);
    await bloc.close();
  });

  test('a refresh of a Loaded list keeps it on screen while it runs, never Loading', () async {
    final bloc = await loaded();
    answer(const Success([orders]));
    final states = bloc.stream.take(2).toList();

    bloc.add(const PlatformConnectionListRefreshed());

    expect(await states, [
      const PlatformConnectionListLoaded(connections: all, isRefreshing: true),
      const PlatformConnectionListLoaded(connections: [orders]),
    ]);
    await bloc.close();
  });

  test('a failed refresh keeps the old connections with refreshError, and the next success clears it', () async {
    final bloc = await loaded();
    answer(Failure(serverError));
    final failed = bloc.stream.take(2).toList();

    bloc.add(const PlatformConnectionListRefreshed());

    expect(await failed, [
      const PlatformConnectionListLoaded(connections: all, isRefreshing: true),
      const PlatformConnectionListLoaded(connections: all, refreshError: AppErrorCode.platformInternalError),
    ]);

    answer(const Success(all));
    final recovered = bloc.stream.take(2).toList();
    bloc.add(const PlatformConnectionListRefreshed());

    expect(await recovered, [
      const PlatformConnectionListLoaded(
        connections: all,
        isRefreshing: true,
        refreshError: AppErrorCode.platformInternalError,
      ),
      const PlatformConnectionListLoaded(connections: all),
    ]);
    await bloc.close();
  });

  test('a new load restarts an in-flight one, so a late first answer never overwrites a newer one', () async {
    final first = Completer<Result<List<PlatformConnection>>>();
    final second = Completer<Result<List<PlatformConnection>>>();
    final answers = [first, second];
    when(() => repository.list()).thenAnswer((_) => answers.removeAt(0).future);
    final bloc = build();
    final states = <PlatformConnectionListState>[];
    final subscription = bloc.stream.listen(states.add);

    bloc.add(const PlatformConnectionListRequested());
    await pumpEventQueue();
    bloc.add(const PlatformConnectionListRequested());
    await pumpEventQueue();
    second.complete(const Success([orders]));
    await pumpEventQueue();
    first.complete(const Success(all));
    await pumpEventQueue();

    expect(states.last, const PlatformConnectionListLoaded(connections: [orders]));
    expect(states.whereType<PlatformConnectionListLoaded>().map((s) => s.connections), [
      [orders],
    ]);
    await subscription.cancel();
    await bloc.close();
  });

  group('search', () {
    test('typing istanbul shows the İstanbul connection after the debounce', () {
      fakeAsync((async) {
        answer(const Success(all));
        final bloc = build()..add(const PlatformConnectionListRequested());
        async.flushMicrotasks();

        bloc.add(const PlatformConnectionListSearchChanged('istanbul'));
        async.elapse(PlatformConnectionListBloc.searchDebounce - const Duration(milliseconds: 1));
        expect((bloc.state as PlatformConnectionListLoaded).visible, all);

        async.elapse(const Duration(milliseconds: 1));
        final state = bloc.state as PlatformConnectionListLoaded;
        expect(state.query, 'istanbul');
        expect(state.visible, [cache]);
        bloc.close();
        async.flushMicrotasks();
      });
    });

    test('matches the engine id too', () async {
      final bloc = await loaded();

      bloc.add(const PlatformConnectionListSearchChanged('MYSQL'));
      final state = await bloc.stream.first as PlatformConnectionListLoaded;

      expect(state.visible, [billing]);
      await bloc.close();
    });

    test('a search typed before the first answer applies once it arrives', () async {
      final pending = Completer<Result<List<PlatformConnection>>>();
      when(() => repository.list()).thenAnswer((_) => pending.future);
      final bloc = build()..add(const PlatformConnectionListRequested());
      await pumpEventQueue();

      bloc.add(const PlatformConnectionListSearchChanged('billing'));
      await Future<void>.delayed(PlatformConnectionListBloc.searchDebounce + const Duration(milliseconds: 20));
      pending.complete(const Success(all));
      final state = await bloc.stream.firstWhere((s) => s is PlatformConnectionListLoaded);

      expect(state, const PlatformConnectionListLoaded(connections: all, query: 'billing'));
      expect((state as PlatformConnectionListLoaded).visible, [billing]);
      await bloc.close();
    });

    test('clearing the search shows the full list in server order', () async {
      final bloc = await loaded();
      bloc.add(const PlatformConnectionListSearchChanged('orders'));
      await bloc.stream.first;

      bloc.add(const PlatformConnectionListSearchChanged(''));
      final state = await bloc.stream.first as PlatformConnectionListLoaded;

      expect(state.visible, all);
      await bloc.close();
    });

    test('keeps a running refresh and its error', () async {
      final bloc = await loaded();
      answer(Failure(serverError));
      bloc.add(const PlatformConnectionListRefreshed());
      await bloc.stream.firstWhere((s) => s is PlatformConnectionListLoaded && s.refreshError != null);

      bloc.add(const PlatformConnectionListSearchChanged('orders'));
      final state = await bloc.stream.first as PlatformConnectionListLoaded;

      expect(state.refreshError, AppErrorCode.platformInternalError);
      expect(state.visible, [orders]);
      await bloc.close();
    });
  });

  group('PlatformConnectionReplaced', () {
    const disabledOrders = PlatformConnection(
      id: 'c1',
      name: 'Orders',
      engine: 'postgres',
      status: 'inactive',
      hasWriteCredential: true,
    );

    test('replaces the item with the same id in its position, keeping the query and the refresh error', () async {
      final bloc = await loaded();
      answer(Failure(serverError));
      bloc.add(const PlatformConnectionListRefreshed());
      await bloc.stream.firstWhere((s) => s is PlatformConnectionListLoaded && s.refreshError != null);
      bloc.add(const PlatformConnectionListSearchChanged('orders'));
      await bloc.stream.firstWhere((s) => s is PlatformConnectionListLoaded && s.query == 'orders');

      bloc.add(const PlatformConnectionReplaced(disabledOrders));
      final state = await bloc.stream.first as PlatformConnectionListLoaded;

      expect(state.connections, [disabledOrders, cache, billing]);
      expect(state.query, 'orders');
      expect(state.visible, [disabledOrders]);
      expect(state.refreshError, AppErrorCode.platformInternalError);
      verify(() => repository.list()).called(2);
      await bloc.close();
    });

    test('is ignored for an id the list does not hold', () async {
      final bloc = await loaded();
      final before = bloc.state;

      bloc.add(
        const PlatformConnectionReplaced(
          PlatformConnection(id: 'c9', name: 'Other', engine: 'redis', status: 'inactive', hasWriteCredential: true),
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(bloc.state, before);
      await bloc.close();
    });

    test('wins over the answer of a refresh that was already running', () async {
      final bloc = await loaded();
      final held = Completer<Result<List<PlatformConnection>>>();
      when(() => repository.list()).thenAnswer((_) => held.future);
      bloc.add(const PlatformConnectionListRefreshed());
      await bloc.stream.firstWhere((s) => s is PlatformConnectionListLoaded && s.isRefreshing);

      bloc.add(const PlatformConnectionReplaced(disabledOrders));
      await bloc.stream.firstWhere((s) => s is PlatformConnectionListLoaded && s.connections.first == disabledOrders);
      held.complete(const Success(all));
      final state = await bloc.stream.firstWhere(
        (s) => s is PlatformConnectionListLoaded && !s.isRefreshing,
      ) as PlatformConnectionListLoaded;

      expect(state.connections, [disabledOrders, cache, billing]);
      await bloc.close();
    });

    test('does not change the answer of a refresh that started after it', () async {
      final bloc = await loaded();
      bloc.add(const PlatformConnectionReplaced(disabledOrders));
      await bloc.stream.firstWhere((s) => s is PlatformConnectionListLoaded && s.connections.first == disabledOrders);

      bloc.add(const PlatformConnectionListRefreshed());
      final state = await bloc.stream.firstWhere(
        (s) => s is PlatformConnectionListLoaded && !s.isRefreshing,
      ) as PlatformConnectionListLoaded;

      expect(state.connections, all);
      await bloc.close();
    });

    test('is not added back when the running refresh no longer lists its id', () async {
      final bloc = await loaded();
      final held = Completer<Result<List<PlatformConnection>>>();
      when(() => repository.list()).thenAnswer((_) => held.future);
      bloc.add(const PlatformConnectionListRefreshed());
      await bloc.stream.firstWhere((s) => s is PlatformConnectionListLoaded && s.isRefreshing);

      bloc.add(const PlatformConnectionReplaced(disabledOrders));
      await bloc.stream.firstWhere((s) => s is PlatformConnectionListLoaded && s.connections.first == disabledOrders);
      held.complete(const Success([cache, billing]));
      final state = await bloc.stream.firstWhere(
        (s) => s is PlatformConnectionListLoaded && !s.isRefreshing,
      ) as PlatformConnectionListLoaded;

      expect(state.connections, [cache, billing]);
      await bloc.close();
    });

    test('is ignored outside Loaded', () async {
      answer(Failure(serverError));
      final bloc = build()..add(const PlatformConnectionListRequested());
      await bloc.stream.firstWhere((s) => s is PlatformConnectionListFailure);

      bloc.add(const PlatformConnectionReplaced(disabledOrders));
      await Future<void>.delayed(Duration.zero);

      expect(bloc.state, const PlatformConnectionListFailure(errorCode: AppErrorCode.platformInternalError));
      await bloc.close();
    });
  });

  test('logs no connection name and no Platform message', () async {
    answer(const Success(all));
    final lines = await printedLines(() async {
      final bloc = build()..add(const PlatformConnectionListRequested());
      await bloc.stream.firstWhere((state) => state is PlatformConnectionListLoaded);
      answer(Failure(ServerError('jane.doe cannot see Orders', code: AppErrorCode.platformInternalError.key)));
      bloc.add(const PlatformConnectionListRefreshed());
      await bloc.stream.firstWhere((state) => state is PlatformConnectionListLoaded && state.refreshError != null);
      await bloc.close();
    });

    final text = lines.join('\n');
    expect(text, contains('END: onLoad connections: ${all.length}'));
    expect(text, contains('END: onLoad failed: ${AppErrorCode.platformInternalError.key}'));
    expect(text, isNot(contains('Orders')));
    expect(text, isNot(contains('İstanbul')));
    expect(text, isNot(contains('jane.doe')));
  });
}
