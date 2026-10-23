import 'package:clock/clock.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/connections/application/connection_list_bloc.dart';
import 'package:libredb_mobile/features/connections/application/usecases/list_managed_connections_usecase.dart';
import 'package:libredb_mobile/features/connections/domain/entities/managed_connections.dart';
import 'package:libredb_mobile/shared/models/studio_connection.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mock_classes.dart';

/// The live refresh of the connection list and the states of a governance outage, driven on a fake clock.
void main() {
  late MockIConnectionRepository repository;

  const connections = [StudioConnection(id: 'seed:a', name: 'A', type: 'postgres')];
  const fresh = [
    StudioConnection(id: 'seed:a', name: 'A', type: 'postgres'),
    StudioConnection(id: 'seed:b', name: 'B', type: 'mysql'),
  ];

  final governanceUnavailable = Failure<ManagedConnections>(
    ServerError('Governance unavailable', code: AppErrorCode.studioGovernanceUnavailable.key),
  );
  final identityProviderUnavailable = Failure<ManagedConnections>(
    ServerError('Identity provider unavailable', code: AppErrorCode.studioIdentityProviderUnavailable.key),
  );
  final accountHasNoRole = Failure<ManagedConnections>(
    AuthError('No role', code: AppErrorCode.studioAccountHasNoRole.key),
  );

  setUp(() {
    repository = MockIConnectionRepository();
  });

  void answer(Result<ManagedConnections> result) =>
      when(() => repository.listManaged()).thenAnswer((_) async => result);

  ManagedConnections managed(List<StudioConnection> rows, {Duration? cacheHint}) =>
      ManagedConnections(connections: rows, cacheHint: cacheHint);

  /// Runs [body] on a fake clock with a bloc that the page shows in the foreground, and closes the bloc after it.
  void run(void Function(FakeAsync async, ConnectionListBloc bloc, List<ConnectionListState> states) body) {
    fakeAsync((async) {
      withClock(async.getClock(DateTime(2026, 10, 23, 9)), () {
        final bloc = ConnectionListBloc(listManagedConnectionsUseCase: ListManagedConnectionsUseCase(repository));
        final states = <ConnectionListState>[];
        final subscription = bloc.stream.listen(states.add);
        body(async, bloc, states);
        subscription.cancel();
        bloc.close();
        async.flushMicrotasks();
      });
    });
  }

  /// Opens the list in the foreground and lets the first answer arrive.
  void open(FakeAsync async, ConnectionListBloc bloc) {
    bloc
      ..add(const ConnectionListRequested())
      ..add(const ConnectionListAutoRefreshChanged(active: true));
    async.flushMicrotasks();
  }

  group('live refresh', () {
    test('asks again every cacheHint while the list is shown in the foreground', () {
      answer(Success(managed(connections, cacheHint: const Duration(seconds: 10))));
      run((async, bloc, states) {
        open(async, bloc);
        verify(() => repository.listManaged()).called(1);

        async.elapse(const Duration(seconds: 9));
        verifyNever(() => repository.listManaged());

        async.elapse(const Duration(seconds: 1));
        verify(() => repository.listManaged()).called(1);

        async.elapse(const Duration(seconds: 10));
        verify(() => repository.listManaged()).called(1);
      });
    });

    for (final (hint, interval) in [
      (null, const Duration(seconds: 5)),
      (const Duration(seconds: 2), const Duration(seconds: 5)),
      (const Duration(seconds: 30), const Duration(seconds: 30)),
      (const Duration(minutes: 5), const Duration(seconds: 60)),
    ]) {
      test('a cacheHint of $hint asks again after $interval', () {
        answer(Success(managed(connections, cacheHint: hint)));
        run((async, bloc, states) {
          open(async, bloc);
          verify(() => repository.listManaged()).called(1);

          async.elapse(interval - const Duration(milliseconds: 1));
          verifyNever(() => repository.listManaged());
          async.elapse(const Duration(milliseconds: 1));
          verify(() => repository.listManaged()).called(1);
        });
      });
    }

    test('a timed refresh shows no refreshing state, only the new answer', () {
      answer(Success(managed(connections, cacheHint: const Duration(seconds: 10))));
      run((async, bloc, states) {
        open(async, bloc);
        answer(Success(managed(fresh, cacheHint: const Duration(seconds: 10))));
        states.clear();

        async.elapse(const Duration(seconds: 10));

        expect(states, hasLength(1));
        expect(states.single, isA<ConnectionListLoaded>().having((s) => s.connections, 'connections', fresh));
      });
    });

    test('a return without askNow, such as from a page that covered the list, waits the usual interval', () {
      answer(Success(managed(connections, cacheHint: const Duration(seconds: 10))));
      run((async, bloc, states) {
        open(async, bloc);
        bloc.add(const ConnectionListAutoRefreshChanged(active: false));
        async.flushMicrotasks();
        clearInteractions(repository);

        bloc.add(const ConnectionListAutoRefreshChanged(active: true));
        async.elapse(const Duration(seconds: 9));
        verifyNever(() => repository.listManaged());

        async.elapse(const Duration(seconds: 1));
        verify(() => repository.listManaged()).called(1);
      });
    });

    test('asks nothing while the list is not shown in the foreground', () {
      answer(Success(managed(connections, cacheHint: const Duration(seconds: 10))));
      run((async, bloc, states) {
        bloc.add(const ConnectionListRequested());
        async.flushMicrotasks();
        verify(() => repository.listManaged()).called(1);

        async.elapse(const Duration(minutes: 5));

        verifyNever(() => repository.listManaged());
      });
    });

    test('stops when the app goes to the background and asks at once when it comes back', () {
      answer(Success(managed(connections, cacheHint: const Duration(seconds: 10))));
      run((async, bloc, states) {
        open(async, bloc);
        verify(() => repository.listManaged()).called(1);

        bloc.add(const ConnectionListAutoRefreshChanged(active: false));
        async.flushMicrotasks();
        async.elapse(const Duration(minutes: 5));
        verifyNever(() => repository.listManaged());

        bloc.add(const ConnectionListAutoRefreshChanged(active: true, askNow: true));
        async.elapse(Duration.zero);
        verify(() => repository.listManaged()).called(1);

        async.elapse(const Duration(seconds: 10));
        verify(() => repository.listManaged()).called(1);
      });
    });

    test('a refresh sent with the return to the foreground replaces the ask of the return', () {
      answer(Success(managed(connections, cacheHint: const Duration(seconds: 10))));
      run((async, bloc, states) {
        open(async, bloc);
        bloc.add(const ConnectionListAutoRefreshChanged(active: false));
        async.flushMicrotasks();
        clearInteractions(repository);

        bloc
          ..add(const ConnectionListAutoRefreshChanged(active: true, askNow: true))
          ..add(const ConnectionListRefreshed());
        async.elapse(Duration.zero);

        verify(() => repository.listManaged()).called(1);
      });
    });

    test('a return to the foreground while the first answer is awaited sends no second request', () {
      answer(Success(managed(connections, cacheHint: const Duration(seconds: 10))));
      run((async, bloc, states) {
        bloc
          ..add(const ConnectionListRequested())
          ..add(const ConnectionListAutoRefreshChanged(active: false))
          ..add(const ConnectionListAutoRefreshChanged(active: true, askNow: true));
        async.flushMicrotasks();

        verify(() => repository.listManaged()).called(1);
      });
    });
  });

  group('governance unavailable', () {
    test('after a loaded list keeps the rows, retries every 10 s and recovers by itself', () {
      answer(Success(managed(connections, cacheHint: const Duration(minutes: 1))));
      run((async, bloc, states) {
        open(async, bloc);
        final loaded = bloc.state as ConnectionListLoaded;
        answer(governanceUnavailable);

        async.elapse(const Duration(minutes: 1));
        expect(
          bloc.state,
          ConnectionListUnavailable(errorCode: AppErrorCode.studioGovernanceUnavailable, previous: loaded),
        );
        clearInteractions(repository);

        async.elapse(const Duration(seconds: 10));
        verify(() => repository.listManaged()).called(1);
        expect(bloc.state, isA<ConnectionListUnavailable>());

        answer(Success(managed(fresh, cacheHint: const Duration(minutes: 1))));
        async.elapse(const Duration(seconds: 10));
        expect(bloc.state, isA<ConnectionListLoaded>().having((s) => s.connections, 'connections', fresh));
      });
    });

    test('on a cold start is unavailable without rows, never an empty list, and recovers by itself', () {
      answer(governanceUnavailable);
      run((async, bloc, states) {
        open(async, bloc);
        expect(states, const [
          ConnectionListLoading(),
          ConnectionListUnavailable(errorCode: AppErrorCode.studioGovernanceUnavailable),
        ]);

        answer(Success(managed(connections)));
        async.elapse(const Duration(seconds: 10));
        expect(bloc.state, isA<ConnectionListLoaded>().having((s) => s.connections, 'connections', connections));
      });
    });

    test('a pull while unavailable keeps the rows and says the retry is running', () {
      answer(Success(managed(connections, cacheHint: const Duration(minutes: 1))));
      run((async, bloc, states) {
        open(async, bloc);
        final loaded = bloc.state as ConnectionListLoaded;
        answer(governanceUnavailable);
        async.elapse(const Duration(minutes: 1));
        states.clear();

        bloc.add(const ConnectionListRefreshed());
        async.flushMicrotasks();

        expect(states, [
          ConnectionListUnavailable(
            errorCode: AppErrorCode.studioGovernanceUnavailable,
            previous: loaded,
            isRetrying: true,
          ),
          ConnectionListUnavailable(errorCode: AppErrorCode.studioGovernanceUnavailable, previous: loaded),
        ]);
      });
    });

    test('a search while unavailable narrows the kept rows', () {
      answer(Success(managed(connections, cacheHint: const Duration(minutes: 1))));
      run((async, bloc, states) {
        open(async, bloc);
        answer(governanceUnavailable);
        async.elapse(const Duration(minutes: 1));

        bloc.add(const ConnectionListSearchChanged('b'));
        async.elapse(ConnectionListBloc.searchDebounce);

        expect(bloc.state, isA<ConnectionListUnavailable>().having((s) => s.previous?.query, 'previous query', 'b'));
      });
    });

    test('an offline retry while unavailable stays unavailable', () {
      answer(Success(managed(connections, cacheHint: const Duration(minutes: 1))));
      run((async, bloc, states) {
        open(async, bloc);
        final loaded = bloc.state as ConnectionListLoaded;
        answer(governanceUnavailable);
        async.elapse(const Duration(minutes: 1));
        answer(Failure(NetworkError('No Internet connection', code: AppErrorCode.networkOffline.key)));

        async.elapse(const Duration(seconds: 10));

        expect(
          bloc.state,
          ConnectionListUnavailable(errorCode: AppErrorCode.studioGovernanceUnavailable, previous: loaded),
        );
      });
    });

    for (final (reason, failure) in [
      ('an identity provider outage', identityProviderUnavailable),
      ('a 500 without a code', const Failure<ManagedConnections>(ServerError('Internal error'))),
    ]) {
      test('a retry failed by $reason never reached governance, so the rows stay greyed and it retries in 10 s', () {
        answer(Success(managed(connections, cacheHint: const Duration(minutes: 1))));
        run((async, bloc, states) {
          open(async, bloc);
          final loaded = bloc.state as ConnectionListLoaded;
          answer(governanceUnavailable);
          async.elapse(const Duration(minutes: 1));
          answer(failure);

          async.elapse(const Duration(seconds: 10));
          expect(
            bloc.state,
            ConnectionListUnavailable(
              errorCode: AppErrorCode.studioGovernanceUnavailable,
              previous: loaded,
              retryError: failure.error,
            ),
          );
          clearInteractions(repository);

          answer(Success(managed(fresh, cacheHint: const Duration(minutes: 1))));
          async.elapse(const Duration(seconds: 10));
          verify(() => repository.listManaged()).called(1);
          expect(bloc.state, isA<ConnectionListLoaded>().having((s) => s.connections, 'connections', fresh));
        });
      });
    }

    test('a 429 on a retry keeps the rows greyed and waits as long as Studio asked', () {
      answer(Success(managed(connections, cacheHint: const Duration(minutes: 1))));
      run((async, bloc, states) {
        open(async, bloc);
        final loaded = bloc.state as ConnectionListLoaded;
        answer(governanceUnavailable);
        async.elapse(const Duration(minutes: 1));
        const limited = RateLimitedError(
          'Too many requests',
          code: 'studio.rate_limited',
          retryAfter: Duration(seconds: 30),
        );
        answer(const Failure(limited));

        async.elapse(const Duration(seconds: 10));
        expect(
          bloc.state,
          ConnectionListUnavailable(
            errorCode: AppErrorCode.studioGovernanceUnavailable,
            previous: loaded,
            retryError: limited,
          ),
        );
        clearInteractions(repository);

        async.elapse(const Duration(seconds: 29));
        verifyNever(() => repository.listManaged());
        async.elapse(const Duration(seconds: 1));
        verify(() => repository.listManaged()).called(1);
      });
    });
  });

  group('identity provider unavailable', () {
    test('on a refresh keeps the rows with the error and keeps refreshing', () {
      answer(Success(managed(connections, cacheHint: const Duration(seconds: 10))));
      run((async, bloc, states) {
        open(async, bloc);
        answer(identityProviderUnavailable);

        async.elapse(const Duration(seconds: 10));
        expect(
          bloc.state,
          isA<ConnectionListLoaded>()
              .having((s) => s.connections, 'connections', connections)
              .having((s) => s.refreshError, 'refreshError', identityProviderUnavailable.error),
        );
        clearInteractions(repository);

        answer(Success(managed(fresh, cacheHint: const Duration(seconds: 10))));
        async.elapse(const Duration(seconds: 10));
        verify(() => repository.listManaged()).called(1);
        expect(
          bloc.state,
          isA<ConnectionListLoaded>()
              .having((s) => s.connections, 'connections', fresh)
              .having((s) => s.refreshError, 'refreshError', isNull),
        );
      });
    });

    test('on a cold start is a failure with a retry and asks nothing by itself', () {
      answer(identityProviderUnavailable);
      run((async, bloc, states) {
        open(async, bloc);
        expect(bloc.state, const ConnectionListFailure(errorCode: AppErrorCode.studioIdentityProviderUnavailable));
        clearInteractions(repository);

        async.elapse(const Duration(minutes: 5));

        verifyNever(() => repository.listManaged());
      });
    });
  });

  group('a refused account', () {
    test('on a refresh drops the rows, stops the timer and waits for the user to retry', () {
      answer(Success(managed(connections, cacheHint: const Duration(seconds: 10))));
      run((async, bloc, states) {
        open(async, bloc);
        answer(accountHasNoRole);

        async.elapse(const Duration(seconds: 10));
        expect(bloc.state, const ConnectionListFailure(errorCode: AppErrorCode.studioAccountHasNoRole));
        clearInteractions(repository);

        async.elapse(const Duration(minutes: 5));
        bloc.add(const ConnectionListAutoRefreshChanged(active: false));
        bloc.add(const ConnectionListAutoRefreshChanged(active: true, askNow: true));
        async.flushMicrotasks();
        verifyNever(() => repository.listManaged());

        answer(Success(managed(connections, cacheHint: const Duration(seconds: 10))));
        bloc.add(const ConnectionListRequested());
        async.flushMicrotasks();
        verify(() => repository.listManaged()).called(1);
        expect(bloc.state, isA<ConnectionListLoaded>());

        async.elapse(const Duration(seconds: 10));
        verify(() => repository.listManaged()).called(1);
      });
    });

    test('while governance is unavailable drops the kept rows and stops the timer', () {
      answer(Success(managed(connections, cacheHint: const Duration(minutes: 1))));
      run((async, bloc, states) {
        open(async, bloc);
        answer(governanceUnavailable);
        async.elapse(const Duration(minutes: 1));
        answer(accountHasNoRole);

        async.elapse(const Duration(seconds: 10));
        expect(bloc.state, const ConnectionListFailure(errorCode: AppErrorCode.studioAccountHasNoRole));
        clearInteractions(repository);

        async.elapse(const Duration(minutes: 5));
        verifyNever(() => repository.listManaged());
      });
    });
  });

  group('rate limited', () {
    test('a 429 on a refresh keeps the rows with the error and waits as long as Studio asked', () {
      answer(Success(managed(connections, cacheHint: const Duration(seconds: 10))));
      run((async, bloc, states) {
        open(async, bloc);
        const limited = RateLimitedError(
          'Too many requests',
          code: 'studio.rate_limited',
          retryAfter: Duration(seconds: 30),
        );
        answer(const Failure(limited));

        async.elapse(const Duration(seconds: 10));
        expect(
          bloc.state,
          isA<ConnectionListLoaded>()
              .having((s) => s.connections, 'connections', connections)
              .having((s) => s.refreshError, 'refreshError', limited),
        );
        clearInteractions(repository);

        async.elapse(const Duration(seconds: 29));
        verifyNever(() => repository.listManaged());
        async.elapse(const Duration(seconds: 1));
        verify(() => repository.listManaged()).called(1);
      });
    });

    test('a second 429 with a new Retry-After is shown and waits as long as the new one asks', () {
      answer(Success(managed(connections, cacheHint: const Duration(seconds: 10))));
      run((async, bloc, states) {
        open(async, bloc);
        answer(
          const Failure(
            RateLimitedError('Too many requests', code: 'studio.rate_limited', retryAfter: Duration(seconds: 12)),
          ),
        );
        async.elapse(const Duration(seconds: 10));
        const longer = RateLimitedError(
          'Too many requests',
          code: 'studio.rate_limited',
          retryAfter: Duration(seconds: 45),
        );
        answer(const Failure(longer));
        states.clear();

        async.elapse(const Duration(seconds: 12));
        expect(states, [isA<ConnectionListLoaded>().having((s) => s.refreshError, 'refreshError', longer)]);
        clearInteractions(repository);

        async.elapse(const Duration(seconds: 44));
        verifyNever(() => repository.listManaged());
        async.elapse(const Duration(seconds: 1));
        verify(() => repository.listManaged()).called(1);
      });
    });
  });
}
