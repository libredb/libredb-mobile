import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/platform_grants/application/grant_list_bloc.dart';
import 'package:libredb_mobile/features/platform_grants/application/usecases/list_connection_grants_usecase.dart';
import 'package:libredb_mobile/features/platform_grants/domain/entities/platform_grant.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mock_classes.dart';

PlatformGrant _grant(String id) => PlatformGrant(
  id: id,
  subject: 'kc-$id',
  subjectUsername: 'user-$id',
  subjectEmail: null,
  level: 'read',
  expiresAt: null,
  grantedBy: const PlatformGrantGranter(id: 'u1', name: null, email: 'admin@example.org'),
  grantedAt: DateTime.utc(2027),
);

void main() {
  late MockIPlatformGrantRepository repository;

  final first = [_grant('g1'), _grant('g2')];
  final second = [_grant('g2')];
  final serverError = ServerError('Platform text', code: AppErrorCode.platformInternalError.key);
  final notFound = NotFoundError('404 NOT_FOUND', code: AppErrorCode.platformNotFound.key);

  setUp(() => repository = MockIPlatformGrantRepository());

  GrantListBloc build() => GrantListBloc(listConnectionGrantsUseCase: ListConnectionGrantsUseCase(repository));

  void answer(Result<List<PlatformGrant>> result) => when(() => repository.list(any())).thenAnswer((_) async => result);

  Future<GrantListBloc> loaded() async {
    answer(Success(first));
    final bloc = build()..add(const GrantListLoadRequested('c1'));
    await bloc.stream.firstWhere((state) => state is GrantListLoaded);
    return bloc;
  }

  test('starts in GrantListInitial', () {
    expect(build().state, const GrantListInitial());
  });

  test('loads the grants of the connection it is given', () async {
    answer(Success(first));
    final bloc = build();
    final states = bloc.stream.take(2).toList();

    bloc.add(const GrantListLoadRequested('c1'));

    expect(await states, [const GrantListLoading(), GrantListLoaded(grants: first)]);
    verify(() => repository.list('c1')).called(1);
    await bloc.close();
  });

  test('a failed load emits GrantListFailure with the code', () async {
    answer(Failure(serverError));
    final bloc = build();
    final states = bloc.stream.take(2).toList();

    bloc.add(const GrantListLoadRequested('c1'));

    expect(await states, [
      const GrantListLoading(),
      const GrantListFailure(errorCode: AppErrorCode.platformInternalError),
    ]);
    await bloc.close();
  });

  test('a load request after a failure loads again, as the retry does', () async {
    answer(Failure(serverError));
    final bloc = build()..add(const GrantListLoadRequested('c1'));
    await bloc.stream.firstWhere((state) => state is GrantListFailure);
    answer(Success(first));
    final states = bloc.stream.take(2).toList();

    bloc.add(const GrantListLoadRequested('c1'));

    expect(await states, [const GrantListLoading(), GrantListLoaded(grants: first)]);
    await bloc.close();
  });

  test('a refresh before any load is ignored', () async {
    final bloc = build()..add(const GrantListRefreshRequested());
    await Future<void>.delayed(Duration.zero);

    expect(bloc.state, const GrantListInitial());
    verifyNever(() => repository.list(any()));
    await bloc.close();
  });

  test('a refresh keeps the list on screen and replaces it with the answer', () async {
    final bloc = await loaded();
    answer(Success(second));
    final states = bloc.stream.take(2).toList();

    bloc.add(const GrantListRefreshRequested());

    expect(await states, [GrantListLoaded(grants: first, isRefreshing: true), GrantListLoaded(grants: second)]);
    verify(() => repository.list('c1')).called(2);
    await bloc.close();
  });

  test('a failed refresh keeps the loaded grants with the error', () async {
    final bloc = await loaded();
    answer(Failure(serverError));
    final states = bloc.stream.take(2).toList();

    bloc.add(const GrantListRefreshRequested());

    expect(await states, [
      GrantListLoaded(grants: first, isRefreshing: true),
      GrantListLoaded(grants: first, refreshError: AppErrorCode.platformInternalError),
    ]);
    await bloc.close();
  });

  test('a refresh that succeeds after a failed one clears the error', () async {
    final bloc = await loaded();
    answer(Failure(serverError));
    bloc.add(const GrantListRefreshRequested());
    await bloc.stream.firstWhere((state) => state is GrantListLoaded && state.refreshError != null);
    answer(Success(second));

    bloc.add(const GrantListRefreshRequested());

    expect(
      await bloc.stream.firstWhere((state) => state is GrantListLoaded && !state.isRefreshing),
      GrantListLoaded(grants: second),
    );
    await bloc.close();
  });

  test('a refresh answered platformNotFound says the connection is gone', () async {
    final bloc = await loaded();
    answer(Failure(notFound));

    bloc.add(const GrantListRefreshRequested());

    expect(
      await bloc.stream.firstWhere((state) => state is GrantListFailure),
      const GrantListFailure(errorCode: AppErrorCode.platformNotFound),
    );
    await bloc.close();
  });

  test('a newer load replaces one still running, so a late answer never wins', () async {
    final late = Completer<Result<List<PlatformGrant>>>();
    when(() => repository.list('c1')).thenAnswer((_) => late.future);
    final bloc = build()..add(const GrantListLoadRequested('c1'));
    await bloc.stream.firstWhere((state) => state is GrantListLoading);
    when(() => repository.list('c1')).thenAnswer((_) async => Success(second));

    bloc.add(const GrantListLoadRequested('c1'));
    await bloc.stream.firstWhere((state) => state is GrantListLoaded);
    late.complete(Success(first));
    await Future<void>.delayed(Duration.zero);

    expect(bloc.state, GrantListLoaded(grants: second));
    await bloc.close();
  });

  test('prints no username or e-mail address in a state', () async {
    final bloc = await loaded();

    expect('${bloc.state}', isNot(contains('user-g1')));
    expect('${bloc.state}', isNot(contains('admin@example.org')));
    await bloc.close();
  });
}
