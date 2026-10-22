import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:clock/clock.dart';
import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/connections/application/connection_list_bloc.dart';
import 'package:libredb_mobile/features/connections/application/usecases/list_managed_connections_usecase.dart';
import 'package:libredb_mobile/features/connections/domain/entities/managed_connections.dart';
import 'package:libredb_mobile/shared/models/studio_connection.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mock_classes.dart';

void main() {
  late MockIConnectionRepository repository;

  const connections = [StudioConnection(id: 'seed:a', name: 'A', type: 'postgres')];
  const managed = ManagedConnections(connections: connections, cacheHint: Duration(seconds: 10));
  final loadedAt = DateTime(2026, 10, 22, 14, 5);

  setUp(() {
    repository = MockIConnectionRepository();
  });

  ConnectionListBloc build() =>
      ConnectionListBloc(listManagedConnectionsUseCase: ListManagedConnectionsUseCase(repository));

  test('starts in ConnectionListInitial', () {
    expect(build().state, const ConnectionListInitial());
  });

  test('loads the connections and the cache hint, with the time they were loaded', () async {
    when(() => repository.listManaged()).thenAnswer((_) async => const Success(managed));

    await withClock(Clock.fixed(loadedAt), () async {
      final bloc = build();
      final states = bloc.stream.take(2).toList();
      bloc.add(const ConnectionListRequested());

      expect(await states, [
        const ConnectionListLoading(),
        ConnectionListLoaded(connections: connections, cacheHint: const Duration(seconds: 10), loadedAt: loadedAt),
      ]);
      await bloc.close();
    });
  });

  // A refresh sent while the device is offline, such as a pull or a timer, never reaches Studio: the rows stay on
  // screen with the time they were loaded, and the screen marks them stale.
  test('keeps the loaded connections when a refresh fails because the device is offline', () async {
    when(() => repository.listManaged()).thenAnswer((_) async => const Success(managed));
    await withClock(Clock.fixed(loadedAt), () async {
      final bloc = build();
      bloc.add(const ConnectionListRequested());
      await bloc.stream.firstWhere((state) => state is ConnectionListLoaded);
      when(
        () => repository.listManaged(),
      ).thenAnswer((_) async => Failure(NetworkError('No Internet connection', code: AppErrorCode.networkOffline.key)));

      await withClock(Clock.fixed(loadedAt.add(const Duration(minutes: 3))), () async {
        final states = bloc.stream.take(2).toList();
        bloc.add(const ConnectionListRequested());

        expect(await states, [
          const ConnectionListLoading(),
          ConnectionListLoaded(connections: connections, cacheHint: const Duration(seconds: 10), loadedAt: loadedAt),
        ]);
      });
      await bloc.close();
    });
  });

  // The second refresh restarts the first while it shows the spinner, so the rows must not depend on the state it saw.
  test('keeps the loaded connections when two refreshes overlap while the device is offline', () async {
    when(() => repository.listManaged()).thenAnswer((_) async => const Success(managed));
    await withClock(Clock.fixed(loadedAt), () async {
      final bloc = build();
      bloc.add(const ConnectionListRequested());
      await bloc.stream.firstWhere((state) => state is ConnectionListLoaded);
      const offline = Failure<ManagedConnections>(NetworkError('No Internet connection', code: 'network.offline'));
      final firstAnswer = Completer<Result<ManagedConnections>>();
      var calls = 0;
      when(() => repository.listManaged()).thenAnswer((_) => ++calls == 1 ? firstAnswer.future : Future.value(offline));

      final settled = bloc.stream.firstWhere((state) => state is! ConnectionListLoading);
      bloc.add(const ConnectionListRequested());
      await bloc.stream.firstWhere((state) => state is ConnectionListLoading);
      bloc.add(const ConnectionListRequested());

      expect(
        await settled,
        ConnectionListLoaded(connections: connections, cacheHint: const Duration(seconds: 10), loadedAt: loadedAt),
      );
      await bloc.close();
    });
  });

  test('does not bring back connections that a failed refresh took off the screen', () async {
    when(() => repository.listManaged()).thenAnswer((_) async => const Success(managed));
    final bloc = build();
    bloc.add(const ConnectionListRequested());
    await bloc.stream.firstWhere((state) => state is ConnectionListLoaded);
    when(() => repository.listManaged()).thenAnswer((_) async => const Failure(NetworkError('reset')));
    bloc.add(const ConnectionListRequested());
    await bloc.stream.firstWhere((state) => state is ConnectionListFailure);
    when(
      () => repository.listManaged(),
    ).thenAnswer((_) async => Failure(NetworkError('No Internet connection', code: AppErrorCode.networkOffline.key)));

    final states = bloc.stream.take(2).toList();
    bloc.add(const ConnectionListRequested());

    expect(await states, const [
      ConnectionListLoading(),
      ConnectionListFailure(errorCode: AppErrorCode.networkOffline),
    ]);
    await bloc.close();
  });

  test('fails a refresh for any other reason even with connections loaded', () async {
    when(() => repository.listManaged()).thenAnswer((_) async => const Success(managed));
    final bloc = build();
    bloc.add(const ConnectionListRequested());
    await bloc.stream.firstWhere((state) => state is ConnectionListLoaded);
    when(() => repository.listManaged()).thenAnswer((_) async => const Failure(NetworkError('reset')));

    final states = bloc.stream.take(2).toList();
    bloc.add(const ConnectionListRequested());

    expect(await states, const [ConnectionListLoading(), ConnectionListFailure(errorCode: AppErrorCode.generic)]);
    await bloc.close();
  });

  blocTest<ConnectionListBloc, ConnectionListState>(
    'says the device is offline when nothing was loaded yet',
    setUp: () => when(
      () => repository.listManaged(),
    ).thenAnswer((_) async => Failure(NetworkError('No Internet connection', code: AppErrorCode.networkOffline.key))),
    build: build,
    act: (bloc) => bloc.add(const ConnectionListRequested()),
    expect: () => const [ConnectionListLoading(), ConnectionListFailure(errorCode: AppErrorCode.networkOffline)],
  );

  blocTest<ConnectionListBloc, ConnectionListState>(
    'carries the error code of a failed load',
    setUp: () =>
        when(() => repository.listManaged())
            .thenAnswer((_) async => Failure(NetworkError('down', code: AppErrorCode.networkCertInvalid.key))),
    build: build,
    act: (bloc) => bloc.add(const ConnectionListRequested()),
    expect: () => const [ConnectionListLoading(), ConnectionListFailure(errorCode: AppErrorCode.networkCertInvalid)],
  );

  blocTest<ConnectionListBloc, ConnectionListState>(
    'falls back to the generic code for an error without a known code',
    setUp: () => when(() => repository.listManaged()).thenAnswer((_) async => const Failure(UnknownError('boom'))),
    build: build,
    act: (bloc) => bloc.add(const ConnectionListRequested()),
    expect: () => const [ConnectionListLoading(), ConnectionListFailure(errorCode: AppErrorCode.generic)],
  );

  group('refresh', () {
    const fresh = [
      StudioConnection(id: 'seed:a', name: 'A', type: 'postgres'),
      StudioConnection(id: 'seed:b', name: 'B', type: 'mysql'),
    ];

    blocTest<ConnectionListBloc, ConnectionListState>(
      'keeps the list on screen while it asks again, then shows the new answer',
      setUp: () =>
          when(() => repository.listManaged())
              .thenAnswer((_) async => const Success(ManagedConnections(connections: fresh))),
      build: build,
      seed: () => const ConnectionListLoaded(connections: connections, cacheHint: Duration(seconds: 10)),
      act: (bloc) => bloc.add(const ConnectionListRefreshed()),
      expect: () => const [
        ConnectionListLoaded(connections: connections, cacheHint: Duration(seconds: 10), isRefreshing: true),
        ConnectionListLoaded(connections: fresh),
      ],
    );

    blocTest<ConnectionListBloc, ConnectionListState>(
      'keeps the previous list and carries the error code when the refresh fails',
      setUp: () =>
          when(() => repository.listManaged())
              .thenAnswer((_) async => Failure(NetworkError('down', code: AppErrorCode.networkCertInvalid.key))),
      build: build,
      seed: () => const ConnectionListLoaded(connections: connections),
      act: (bloc) => bloc.add(const ConnectionListRefreshed()),
      expect: () => const [
        ConnectionListLoaded(connections: connections, isRefreshing: true),
        ConnectionListLoaded(connections: connections, refreshErrorCode: AppErrorCode.networkCertInvalid),
      ],
    );

    blocTest<ConnectionListBloc, ConnectionListState>(
      'loads from scratch when there is no list to keep',
      setUp: () => when(() => repository.listManaged()).thenAnswer((_) async => const Success(managed)),
      build: build,
      act: (bloc) => bloc.add(const ConnectionListRefreshed()),
      expect: () => const [
        ConnectionListLoading(),
        ConnectionListLoaded(connections: connections, cacheHint: Duration(seconds: 10)),
      ],
    );

    blocTest<ConnectionListBloc, ConnectionListState>(
      'keeps the search and the environment filter across a refresh',
      setUp: () =>
          when(() => repository.listManaged())
              .thenAnswer((_) async => const Success(ManagedConnections(connections: fresh))),
      build: build,
      act: (bloc) async {
        bloc.add(const ConnectionListRequested());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const ConnectionListSearchChanged('b'));
        await Future<void>.delayed(const Duration(milliseconds: 250));
        bloc.add(const ConnectionListEnvironmentFilterChanged('production'));
        await Future<void>.delayed(Duration.zero);
        bloc.add(const ConnectionListRefreshed());
      },
      skip: 4,
      expect: () => const [
        ConnectionListLoaded(connections: fresh, query: 'b', environment: 'production', isRefreshing: true),
        ConnectionListLoaded(connections: fresh, query: 'b', environment: 'production'),
      ],
    );
  });

  group('search', () {
    const rows = [
      StudioConnection(id: 'seed:a', name: 'Orders', type: 'postgres', group: 'Sales', environment: 'production'),
      StudioConnection(id: 'seed:b', name: 'Ledger', type: 'mysql', group: 'Finance', environment: 'staging'),
    ];

    blocTest<ConnectionListBloc, ConnectionListState>(
      'applies only the last query typed within 200 ms',
      build: build,
      seed: () => const ConnectionListLoaded(connections: rows),
      act: (bloc) async {
        bloc.add(const ConnectionListSearchChanged('o'));
        await Future<void>.delayed(const Duration(milliseconds: 50));
        bloc.add(const ConnectionListSearchChanged('or'));
        await Future<void>.delayed(const Duration(milliseconds: 50));
        bloc.add(const ConnectionListSearchChanged('ord'));
      },
      wait: const Duration(milliseconds: 300),
      expect: () => const [ConnectionListLoaded(connections: rows, query: 'ord')],
      verify: (bloc) {
        final state = bloc.state as ConnectionListLoaded;
        expect(state.sections.single.group, 'Sales');
        expect(state.sections.single.connections.map((c) => c.id), ['seed:a']);
      },
    );

    blocTest<ConnectionListBloc, ConnectionListState>(
      'does not apply a query before 200 ms have passed',
      build: build,
      seed: () => const ConnectionListLoaded(connections: rows),
      act: (bloc) => bloc.add(const ConnectionListSearchChanged('ord')),
      wait: const Duration(milliseconds: 150),
      expect: () => const <ConnectionListState>[],
    );

    blocTest<ConnectionListBloc, ConnectionListState>(
      'applies a query typed before the list arrived once it arrives',
      setUp: () {
        final answer = Completer<Success<ManagedConnections>>();
        when(() => repository.listManaged()).thenAnswer((_) => answer.future);
        Future<void>.delayed(
          const Duration(milliseconds: 300),
          () => answer.complete(const Success(ManagedConnections(connections: rows))),
        );
      },
      build: build,
      act: (bloc) {
        bloc.add(const ConnectionListRequested());
        bloc.add(const ConnectionListSearchChanged('ledger'));
      },
      wait: const Duration(milliseconds: 400),
      expect: () => const [ConnectionListLoading(), ConnectionListLoaded(connections: rows, query: 'ledger')],
    );

    blocTest<ConnectionListBloc, ConnectionListState>(
      'filters by environment at once, and clears the filter with null',
      build: build,
      seed: () => const ConnectionListLoaded(connections: rows),
      act: (bloc) async {
        bloc.add(const ConnectionListEnvironmentFilterChanged('staging'));
        await Future<void>.delayed(Duration.zero);
        bloc.add(const ConnectionListEnvironmentFilterChanged(null));
      },
      expect: () => const [
        ConnectionListLoaded(connections: rows, environment: 'staging'),
        ConnectionListLoaded(connections: rows),
      ],
    );
  });

  test('a loaded state offers the environments of every row, the filtered ones included', () {
    const state = ConnectionListLoaded(
      connections: [
        StudioConnection(id: 'seed:a', name: 'A', type: 'postgres', environment: 'staging'),
        StudioConnection(id: 'seed:b', name: 'B', type: 'postgres', environment: 'production'),
      ],
      environment: 'staging',
    );

    expect(state.environments, ['production', 'staging']);
    expect(state.sections.single.connections.map((c) => c.id), ['seed:a']);
  });
}
