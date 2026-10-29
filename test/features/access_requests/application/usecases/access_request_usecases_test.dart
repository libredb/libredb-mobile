import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/access_requests/application/usecases/create_access_request_usecase.dart';
import 'package:libredb_mobile/features/access_requests/application/usecases/list_my_access_requests_usecase.dart';
import 'package:libredb_mobile/features/access_requests/application/usecases/list_requestable_connections_usecase.dart';
import 'package:libredb_mobile/features/access_requests/application/usecases/withdraw_access_request_usecase.dart';
import 'package:libredb_mobile/features/access_requests/domain/entities/my_access_request.dart';
import 'package:libredb_mobile/features/access_requests/domain/entities/requestable_connection.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mock_classes.dart';

final _connection = RequestableConnection(
  id: 'c1',
  name: 'Analytics warehouse',
  engine: 'postgres',
  hasWriteCredential: true,
  access: null,
  pendingRequestId: null,
);

final _request = MyAccessRequest(
  id: 'r1',
  connectionId: 'c1',
  connectionName: 'Analytics warehouse',
  connectionEngine: 'postgres',
  connectionStatus: 'active',
  level: 'read',
  reason: 'The October report',
  status: AccessRequestStatus.pending,
  rawStatus: 'pending',
  createdAt: DateTime.utc(2026, 10, 29),
  decidedAt: null,
  decisionReason: null,
  grantId: null,
);

void main() {
  late MockIAccessRequestRepository repository;

  setUp(() => repository = MockIAccessRequestRepository());

  test('ListRequestableConnectionsUseCase answers what the repository answers', () async {
    when(repository.requestableConnections).thenAnswer((_) async => Success([_connection]));

    final result = await ListRequestableConnectionsUseCase(repository)();

    expect((result as Success<List<RequestableConnection>>).data, [_connection]);
    verify(repository.requestableConnections).called(1);
  });

  test('ListMyAccessRequestsUseCase answers what the repository answers', () async {
    when(repository.mine).thenAnswer((_) async => Success([_request]));

    final result = await ListMyAccessRequestsUseCase(repository)();

    expect((result as Success<List<MyAccessRequest>>).data, [_request]);
    verify(repository.mine).called(1);
  });

  test('CreateAccessRequestUseCase passes the connection, the level and the reason through once', () async {
    when(() => repository.create(connectionId: 'c1', level: 'write', reason: '  The October report  '))
        .thenAnswer((_) async => Success(_request));

    final result = await CreateAccessRequestUseCase(repository)(
      connectionId: 'c1',
      level: 'write',
      reason: '  The October report  ',
    );

    expect((result as Success<MyAccessRequest>).data, _request);
    verify(() => repository.create(connectionId: 'c1', level: 'write', reason: '  The October report  ')).called(1);
  });

  test('WithdrawAccessRequestUseCase passes the request id through once', () async {
    when(() => repository.withdraw('r1')).thenAnswer((_) async => Success(_request));

    final result = await WithdrawAccessRequestUseCase(repository)('r1');

    expect((result as Success<MyAccessRequest>).data, _request);
    verify(() => repository.withdraw('r1')).called(1);
  });

  test('a failure reaches the caller unchanged', () async {
    const error = AuthError('refused', code: 'platform.studio_role_required');
    when(repository.mine).thenAnswer((_) async => const Failure(error));

    final result = await ListMyAccessRequestsUseCase(repository)();

    expect((result as Failure<List<MyAccessRequest>>).error, error);
  });
}
