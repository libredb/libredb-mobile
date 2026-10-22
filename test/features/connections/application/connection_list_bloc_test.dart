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
}
