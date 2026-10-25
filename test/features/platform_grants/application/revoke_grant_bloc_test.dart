import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/platform_grants/application/revoke_grant_bloc.dart';
import 'package:libredb_mobile/features/platform_grants/application/usecases/revoke_grant_usecase.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mock_classes.dart';

void main() {
  late MockIPlatformGrantRepository repository;

  setUp(() => repository = MockIPlatformGrantRepository());

  RevokeGrantBloc build() => RevokeGrantBloc(revokeGrantUseCase: RevokeGrantUseCase(repository));

  void answer(Result<void> result) => when(() => repository.revoke(any(), any())).thenAnswer((_) async => result);

  test('starts idle', () {
    expect(build().state, const RevokeGrantIdle());
  });

  test('revokes the grant by its id and succeeds', () async {
    answer(const Success(null));
    final bloc = build();
    final states = bloc.stream.take(2).toList();

    bloc.add(const RevokeGrantConfirmed(connectionId: 'c1', grantId: 'g1'));

    expect(await states, [const RevokeGrantInProgress('g1'), const RevokeGrantSucceeded('g1')]);
    verify(() => repository.revoke('c1', 'g1')).called(1);
    await bloc.close();
  });

  test('a 404 says the grant was already removed', () async {
    answer(Failure(NotFoundError('404 NOT_FOUND', code: AppErrorCode.platformNotFound.key)));
    final bloc = build();
    final states = bloc.stream.take(2).toList();

    bloc.add(const RevokeGrantConfirmed(connectionId: 'c1', grantId: 'g1'));

    expect(await states, [const RevokeGrantInProgress('g1'), const RevokeGrantAlreadyRemoved('g1')]);
    await bloc.close();
  });

  test('any other error fails with its code', () async {
    answer(Failure(ServerError('503', code: AppErrorCode.platformIdentityProviderUnavailable.key)));
    final bloc = build();
    final states = bloc.stream.take(2).toList();

    bloc.add(const RevokeGrantConfirmed(connectionId: 'c1', grantId: 'g1'));

    expect(await states, [
      const RevokeGrantInProgress('g1'),
      const RevokeGrantFailed('g1', errorCode: AppErrorCode.platformIdentityProviderUnavailable),
    ]);
    await bloc.close();
  });

  test('an error without a known code fails with the generic code', () async {
    answer(const Failure(UnknownError('boom')));
    final bloc = build();

    bloc.add(const RevokeGrantConfirmed(connectionId: 'c1', grantId: 'g1'));

    expect(
      await bloc.stream.firstWhere((state) => state is RevokeGrantFailed),
      const RevokeGrantFailed('g1', errorCode: AppErrorCode.generic),
    );
    await bloc.close();
  });

  test('a revoke confirmed while one runs is dropped, so one DELETE is sent', () async {
    final pending = Completer<Result<void>>();
    when(() => repository.revoke(any(), any())).thenAnswer((_) => pending.future);
    final bloc = build();

    bloc
      ..add(const RevokeGrantConfirmed(connectionId: 'c1', grantId: 'g1'))
      ..add(const RevokeGrantConfirmed(connectionId: 'c1', grantId: 'g1'))
      ..add(const RevokeGrantConfirmed(connectionId: 'c1', grantId: 'g2'));
    // A timer runs after every microtask, so all three events have reached the bloc while the first one runs.
    await Future<void>.delayed(Duration.zero);
    expect(bloc.state, const RevokeGrantInProgress('g1'));
    pending.complete(const Success(null));
    await bloc.stream.firstWhere((state) => state is RevokeGrantSucceeded);
    await Future<void>.delayed(Duration.zero);

    verify(() => repository.revoke('c1', 'g1')).called(1);
    verifyNever(() => repository.revoke('c1', 'g2'));
    expect(bloc.state, const RevokeGrantSucceeded('g1'));
    await bloc.close();
  });

  test('a revoke after one ended runs', () async {
    answer(const Success(null));
    final bloc = build()..add(const RevokeGrantConfirmed(connectionId: 'c1', grantId: 'g1'));
    await bloc.stream.firstWhere((state) => state is RevokeGrantSucceeded);

    bloc.add(const RevokeGrantConfirmed(connectionId: 'c1', grantId: 'g2'));

    expect(await bloc.stream.firstWhere((state) => state is RevokeGrantSucceeded), const RevokeGrantSucceeded('g2'));
    await bloc.close();
  });
}
