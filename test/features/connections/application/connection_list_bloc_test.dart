import 'package:bloc_test/bloc_test.dart';
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

  setUp(() {
    repository = MockIConnectionRepository();
  });

  ConnectionListBloc build() =>
      ConnectionListBloc(listManagedConnectionsUseCase: ListManagedConnectionsUseCase(repository));

  test('starts in ConnectionListInitial', () {
    expect(build().state, const ConnectionListInitial());
  });

  blocTest<ConnectionListBloc, ConnectionListState>(
    'loads the connections and the cache hint',
    setUp: () => when(() => repository.listManaged()).thenAnswer((_) async => const Success(managed)),
    build: build,
    act: (bloc) => bloc.add(const ConnectionListRequested()),
    expect: () => const [
      ConnectionListLoading(),
      ConnectionListLoaded(connections: connections, cacheHint: Duration(seconds: 10)),
    ],
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
