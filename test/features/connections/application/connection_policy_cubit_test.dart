import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/connections/application/connection_policy_cubit.dart';
import 'package:libredb_mobile/features/connections/domain/entities/connection_policy.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mock_classes.dart';

void main() {
  late MockIConnectionRepository repository;

  const governed = ConnectionPolicy(customConnections: false, governance: true, statementCapture: 'full');

  setUp(() {
    repository = MockIConnectionRepository();
  });

  ConnectionPolicyCubit build() => ConnectionPolicyCubit(repository: repository);

  test('starts in ConnectionPolicyInitial', () {
    expect(build().state, const ConnectionPolicyInitial());
  });

  blocTest<ConnectionPolicyCubit, ConnectionPolicyState>(
    "loads Studio's connection policy",
    setUp: () => when(() => repository.fetchPolicy()).thenAnswer((_) async => const Success(governed)),
    build: build,
    act: (cubit) => cubit.load(),
    expect: () => const [ConnectionPolicyLoading(), ConnectionPolicyLoaded(governed)],
  );

  blocTest<ConnectionPolicyCubit, ConnectionPolicyState>(
    'keeps a failed policy request as a failure with its code',
    setUp: () => when(() => repository.fetchPolicy())
        .thenAnswer((_) async => Failure(ServerError('x', code: AppErrorCode.studioIdentityProviderUnavailable.key))),
    build: build,
    act: (cubit) => cubit.load(),
    expect: () => const [
      ConnectionPolicyLoading(),
      ConnectionPolicyFailure(AppErrorCode.studioIdentityProviderUnavailable),
    ],
  );

  blocTest<ConnectionPolicyCubit, ConnectionPolicyState>(
    'clear forgets the policy of the signed-out user',
    setUp: () => when(() => repository.fetchPolicy()).thenAnswer((_) async => const Success(governed)),
    build: build,
    act: (cubit) async {
      await cubit.load();
      cubit.clear();
    },
    expect: () => const [ConnectionPolicyLoading(), ConnectionPolicyLoaded(governed), ConnectionPolicyInitial()],
  );

  test('an answer that arrives after clear is dropped', () async {
    final answer = Completer<Result<ConnectionPolicy>>();
    when(() => repository.fetchPolicy()).thenAnswer((_) => answer.future);
    final cubit = build();
    addTearDown(cubit.close);

    final loading = cubit.load();
    cubit.clear();
    answer.complete(const Success(governed));
    await loading;

    expect(cubit.state, const ConnectionPolicyInitial());
  });

  blocTest<ConnectionPolicyCubit, ConnectionPolicyState>(
    'a second load while one is in flight sends no second request',
    setUp: () => when(() => repository.fetchPolicy()).thenAnswer((_) async => const Success(governed)),
    build: build,
    act: (cubit) => Future.wait([cubit.load(), cubit.load()]),
    expect: () => const [ConnectionPolicyLoading(), ConnectionPolicyLoaded(governed)],
    verify: (_) => verify(() => repository.fetchPolicy()).called(1),
  );

  group('refresh', () {
    const redacted = ConnectionPolicy(customConnections: false, governance: true, statementCapture: 'redacted');

    blocTest<ConnectionPolicyCubit, ConnectionPolicyState>(
      'replaces a loaded policy without showing a load in between',
      setUp: () => when(() => repository.fetchPolicy()).thenAnswer((_) async => const Success(redacted)),
      build: build,
      seed: () => const ConnectionPolicyLoaded(governed),
      act: (cubit) => cubit.refresh(),
      expect: () => const [ConnectionPolicyLoaded(redacted)],
    );

    blocTest<ConnectionPolicyCubit, ConnectionPolicyState>(
      'keeps the loaded policy when the refresh fails',
      setUp: () =>
          when(() => repository.fetchPolicy())
              .thenAnswer((_) async => Failure(ServerError('x', code: AppErrorCode.studioGovernanceUnavailable.key))),
      build: build,
      seed: () => const ConnectionPolicyLoaded(governed),
      act: (cubit) => cubit.refresh(),
      expect: () => const <ConnectionPolicyState>[],
    );

    blocTest<ConnectionPolicyCubit, ConnectionPolicyState>(
      'loads a policy that failed before',
      setUp: () => when(() => repository.fetchPolicy()).thenAnswer((_) async => const Success(governed)),
      build: build,
      seed: () => const ConnectionPolicyFailure(AppErrorCode.generic),
      act: (cubit) => cubit.refresh(),
      expect: () => const [ConnectionPolicyLoading(), ConnectionPolicyLoaded(governed)],
    );

    blocTest<ConnectionPolicyCubit, ConnectionPolicyState>(
      'a second refresh while one is in flight sends no second request',
      setUp: () => when(() => repository.fetchPolicy()).thenAnswer((_) async => const Success(redacted)),
      build: build,
      seed: () => const ConnectionPolicyLoaded(governed),
      act: (cubit) => Future.wait([cubit.refresh(), cubit.refresh()]),
      expect: () => const [ConnectionPolicyLoaded(redacted)],
      verify: (_) => verify(() => repository.fetchPolicy()).called(1),
    );

    test('an answer that arrives after clear is dropped', () async {
      final answer = Completer<Result<ConnectionPolicy>>();
      when(() => repository.fetchPolicy()).thenAnswer((_) => answer.future);
      final cubit = build()..emit(const ConnectionPolicyLoaded(governed));
      addTearDown(cubit.close);

      final refreshing = cubit.refresh();
      cubit.clear();
      answer.complete(const Success(redacted));
      await refreshing;

      expect(cubit.state, const ConnectionPolicyInitial());
    });
  });
}
