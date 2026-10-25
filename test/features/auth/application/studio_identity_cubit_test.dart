import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/auth/application/studio_identity_cubit.dart';
import 'package:libredb_mobile/shared/models/studio_identity.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mock_classes.dart';

void main() {
  late MockIStudioIdentityRepository repository;

  const admin = StudioIdentity(username: 'admin@example.com', role: StudioAdminRole(), viaBearer: true);

  setUp(() {
    repository = MockIStudioIdentityRepository();
  });

  StudioIdentityCubit build() => StudioIdentityCubit(repository: repository);

  test('starts in StudioIdentityInitial', () {
    expect(build().state, const StudioIdentityInitial());
  });

  blocTest<StudioIdentityCubit, StudioIdentityState>(
    "loads Studio's answer about the signed-in user",
    setUp: () => when(() => repository.fetch()).thenAnswer((_) async => const Success(admin)),
    build: build,
    act: (cubit) => cubit.load(),
    expect: () => const [StudioIdentityLoading(), StudioIdentityLoaded(admin)],
  );

  for (final (shape, error, code) in <(String, AppError, AppErrorCode)>[
    ('a 401 without a code that survived the refresh', const AuthError('refused'), AppErrorCode.generic),
    (
      'a 503 IDENTITY_PROVIDER_UNAVAILABLE',
      ServerError('unavailable', code: AppErrorCode.studioIdentityProviderUnavailable.key),
      AppErrorCode.studioIdentityProviderUnavailable,
    ),
    (
      'a 403 BEARER_NO_ROLE',
      AuthError('no role', code: AppErrorCode.studioAccountHasNoRole.key),
      AppErrorCode.studioAccountHasNoRole,
    ),
    (
      'a 403 BEARER_NO_IDENTITY',
      AuthError('no identity', code: AppErrorCode.studioAccountHasNoIdentity.key),
      AppErrorCode.studioAccountHasNoIdentity,
    ),
    ('no network', const NetworkError('offline'), AppErrorCode.generic),
  ]) {
    blocTest<StudioIdentityCubit, StudioIdentityState>(
      'keeps $shape as a failure with its code',
      setUp: () => when(() => repository.fetch()).thenAnswer((_) async => Failure(error)),
      build: build,
      act: (cubit) => cubit.load(),
      expect: () => [const StudioIdentityLoading(), StudioIdentityFailure(code)],
      // The cubit only reads: ending the session is the ApiClient's decision, never this cubit's.
      verify: (_) => verify(() => repository.fetch()).called(1),
    );
  }

  blocTest<StudioIdentityCubit, StudioIdentityState>(
    'a retry after a failure loads again',
    setUp: () {
      var calls = 0;
      when(() => repository.fetch()).thenAnswer(
        (_) async => calls++ == 0 ? const Failure<StudioIdentity>(AuthError('refused')) : const Success(admin),
      );
    },
    build: build,
    act: (cubit) async {
      await cubit.load();
      await cubit.load();
    },
    expect: () => const [
      StudioIdentityLoading(),
      StudioIdentityFailure(AppErrorCode.generic),
      StudioIdentityLoading(),
      StudioIdentityLoaded(admin),
    ],
  );

  blocTest<StudioIdentityCubit, StudioIdentityState>(
    'a second load while one is in flight sends no second request',
    setUp: () => when(() => repository.fetch()).thenAnswer((_) async => const Success(admin)),
    build: build,
    act: (cubit) => Future.wait([cubit.load(), cubit.load()]),
    expect: () => const [StudioIdentityLoading(), StudioIdentityLoaded(admin)],
    verify: (_) => verify(() => repository.fetch()).called(1),
  );

  blocTest<StudioIdentityCubit, StudioIdentityState>(
    'clear forgets the signed-out user',
    setUp: () => when(() => repository.fetch()).thenAnswer((_) async => const Success(admin)),
    build: build,
    act: (cubit) async {
      await cubit.load();
      cubit.clear();
    },
    expect: () => const [StudioIdentityLoading(), StudioIdentityLoaded(admin), StudioIdentityInitial()],
  );

  test('an answer that arrives after clear is dropped, since it is about the signed-out user', () async {
    final answer = Completer<Result<StudioIdentity>>();
    when(() => repository.fetch()).thenAnswer((_) => answer.future);
    final cubit = build();
    addTearDown(cubit.close);

    final loading = cubit.load();
    cubit.clear();
    answer.complete(const Success(admin));
    await loading;

    expect(cubit.state, const StudioIdentityInitial());
  });

  test('a load after clear sends a new request even while the dropped one is still in flight', () async {
    final first = Completer<Result<StudioIdentity>>();
    var calls = 0;
    when(() => repository.fetch()).thenAnswer((_) => calls++ == 0 ? first.future : Future.value(const Success(admin)));
    final cubit = build();
    addTearDown(cubit.close);

    final dropped = cubit.load();
    cubit.clear();
    await cubit.load();
    first.complete(const Failure(AuthError('late')));
    await dropped;

    expect(cubit.state, const StudioIdentityLoaded(admin));
    expect(calls, 2);
  });

  blocTest<StudioIdentityCubit, StudioIdentityState>(
    'signedIn emits the loaded state without a request',
    build: build,
    act: (cubit) => cubit.signedIn(admin),
    expect: () => const [StudioIdentityLoaded(admin)],
    verify: (_) => verifyNever(() => repository.fetch()),
  );

  test('an answer still on its way when signedIn runs is dropped', () async {
    final answer = Completer<Result<StudioIdentity>>();
    when(() => repository.fetch()).thenAnswer((_) => answer.future);
    final cubit = build();
    addTearDown(cubit.close);

    final loading = cubit.load();
    cubit.signedIn(admin);
    answer.complete(const Failure(AuthError('late')));
    await loading;

    expect(cubit.state, const StudioIdentityLoaded(admin));
  });
}
