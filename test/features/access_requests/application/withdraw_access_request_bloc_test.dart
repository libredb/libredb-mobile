import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/access_requests/application/usecases/withdraw_access_request_usecase.dart';
import 'package:libredb_mobile/features/access_requests/application/withdraw_access_request_bloc.dart';
import 'package:libredb_mobile/features/access_requests/domain/entities/my_access_request.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mock_classes.dart';
import '../support/access_request_fixtures.dart';

void main() {
  late MockIAccessRequestRepository repository;

  final withdrawn = fixtureRequest('r1', status: 'withdrawn');

  setUp(() => repository = MockIAccessRequestRepository());

  WithdrawAccessRequestBloc build() =>
      WithdrawAccessRequestBloc(withdrawAccessRequestUseCase: WithdrawAccessRequestUseCase(repository));

  test('starts in Idle', () {
    expect(build().state, const WithdrawAccessRequestIdle());
  });

  test('a withdraw emits InProgress with the id, then Done with the request as Platform holds it', () async {
    when(() => repository.withdraw('r1')).thenAnswer((_) async => Success(withdrawn));
    final bloc = build();
    final states = bloc.stream.take(2).toList();

    bloc.add(const WithdrawAccessRequestRequested('r1'));

    expect(await states, [const WithdrawAccessRequestInProgress('r1'), WithdrawAccessRequestDone(withdrawn)]);
    await bloc.close();
  });

  test('a refused withdraw emits Failed with the id and the code', () async {
    when(
      () => repository.withdraw('r1'),
    ).thenAnswer((_) async => Failure(ValidationError('decided', code: AppErrorCode.platformAccessRequestDecided.key)));
    final bloc = build();
    final states = bloc.stream.take(2).toList();

    bloc.add(const WithdrawAccessRequestRequested('r1'));

    expect(await states, [
      const WithdrawAccessRequestInProgress('r1'),
      const WithdrawAccessRequestFailed('r1', errorCode: AppErrorCode.platformAccessRequestDecided),
    ]);
    await bloc.close();
  });

  test('a failed withdraw never sends the request again', () async {
    when(() => repository.withdraw('r1'))
        .thenAnswer((_) async => Failure(NetworkError('down', code: AppErrorCode.platformUnreachable.key)));
    final bloc = build()..add(const WithdrawAccessRequestRequested('r1'));
    await bloc.stream.firstWhere((state) => state is WithdrawAccessRequestFailed);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    verify(() => repository.withdraw('r1')).called(1);
    await bloc.close();
  });

  test('a second withdraw while one is out is dropped', () async {
    final slow = Completer<Result<MyAccessRequest>>();
    when(() => repository.withdraw(any())).thenAnswer((_) => slow.future);
    final bloc = build()..add(const WithdrawAccessRequestRequested('r1'));
    await Future<void>.delayed(Duration.zero);

    bloc
      ..add(const WithdrawAccessRequestRequested('r1'))
      ..add(const WithdrawAccessRequestRequested('r2'));
    await Future<void>.delayed(Duration.zero);
    slow.complete(Success(withdrawn));
    await bloc.stream.firstWhere((state) => state is WithdrawAccessRequestDone);

    verify(() => repository.withdraw('r1')).called(1);
    verifyNever(() => repository.withdraw('r2'));
    await bloc.close();
  });
}
