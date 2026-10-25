import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/auth/application/platform_identity_cubit.dart';
import 'package:libredb_mobile/shared/models/platform_identity.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mock_classes.dart';

void main() {
  late MockPlatformIdentityRepository repository;

  const admin = PlatformIdentity(
    id: 'u1',
    email: 'admin@example.org',
    roles: ['PLATFORM_ADMIN'],
    permissions: [],
    tenant: PlatformTenant(id: 't1', name: 'Example Org', slug: 'example-org'),
  );

  setUp(() {
    repository = MockPlatformIdentityRepository();
  });

  PlatformIdentityCubit build() => PlatformIdentityCubit(repository: repository);

  test('starts in PlatformIdentityInitial', () {
    expect(build().state, const PlatformIdentityInitial());
  });

  blocTest<PlatformIdentityCubit, PlatformIdentityState>(
    "loads Platform's answer about the signed-in admin",
    setUp: () => when(() => repository.fetch()).thenAnswer((_) async => const Success(admin)),
    build: build,
    act: (cubit) => cubit.load(),
    expect: () => const [PlatformIdentityLoading(), PlatformIdentityLoaded(admin)],
  );

  blocTest<PlatformIdentityCubit, PlatformIdentityState>(
    'keeps a failure with its code, and an unknown code as generic',
    setUp: () {
      var call = 0;
      when(() => repository.fetch()).thenAnswer(
        (_) async => call++ == 0
            ? Failure(ServerError('x', code: AppErrorCode.platformDirectoryUnavailable.key))
            : const Failure(NetworkError('offline')),
      );
    },
    build: build,
    act: (cubit) async {
      await cubit.load();
      await cubit.load();
    },
    expect: () => const [
      PlatformIdentityLoading(),
      PlatformIdentityFailure(AppErrorCode.platformDirectoryUnavailable),
      PlatformIdentityLoading(),
      PlatformIdentityFailure(AppErrorCode.generic),
    ],
  );

  blocTest<PlatformIdentityCubit, PlatformIdentityState>(
    'sends no second request while an answer is awaited',
    setUp: () => when(() => repository.fetch()).thenAnswer((_) async => const Success(admin)),
    build: build,
    act: (cubit) => Future.wait([cubit.load(), cubit.load()]),
    verify: (_) => verify(() => repository.fetch()).called(1),
  );

  test('drops an answer that arrives after clear()', () async {
    final answer = Completer<Result<PlatformIdentity>>();
    when(() => repository.fetch()).thenAnswer((_) => answer.future);
    final cubit = build();
    final states = <PlatformIdentityState>[];
    final subscription = cubit.stream.listen(states.add);

    final load = cubit.load();
    cubit.clear();
    answer.complete(const Success(admin));
    await load;
    await Future<void>.delayed(Duration.zero);
    await subscription.cancel();

    expect(states, const [PlatformIdentityLoading(), PlatformIdentityInitial()]);
    expect(cubit.state, const PlatformIdentityInitial());
  });

  blocTest<PlatformIdentityCubit, PlatformIdentityState>(
    'signedIn emits the loaded state without a request',
    build: build,
    act: (cubit) => cubit.signedIn(admin),
    expect: () => const [PlatformIdentityLoaded(admin)],
    verify: (_) => verifyNever(() => repository.fetch()),
  );
}
