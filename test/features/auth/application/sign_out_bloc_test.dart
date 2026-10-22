import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/auth/application/sign_out_bloc.dart';
import 'package:libredb_mobile/features/auth/application/usecases/logout_usecase.dart';
import 'package:libredb_mobile/features/auth/application/usecases/sso_sign_out_usecase.dart';
import 'package:libredb_mobile/features/auth/domain/repositories/sso_sign_out_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mock_classes.dart';

void main() {
  group('SignOutState', () {
    test('supports value comparisons', () {
      expect(const SignOutInitial(), const SignOutInitial());
      expect(const SignOutInProgress(), const SignOutInProgress());
      expect(const SignedOut(), const SignedOut());
      expect(const SignedOutWithDataLeft(), const SignedOutWithDataLeft());
      expect(const SignedOutWithProviderSessionLeft(), const SignedOutWithProviderSessionLeft());
      expect(const SignedOut(), isNot(const SignedOutWithDataLeft()));
    });
  });

  group('SignOutBloc', () {
    late MockIAuthRepository authRepository;

    setUp(() => authRepository = MockIAuthRepository());

    SignOutBloc build() => SignOutBloc(logoutUseCase: LogoutUseCase(authRepository));

    blocTest<SignOutBloc, SignOutState>(
      'signs out when the logout clears the stored session',
      setUp: () => when(() => authRepository.logout()).thenAnswer((_) async => const Success<void>(null)),
      build: build,
      act: (bloc) => bloc.add(const SignOutRequested()),
      expect: () => const [SignOutInProgress(), SignedOut()],
      verify: (_) => verify(() => authRepository.logout()).called(1),
    );

    // As SessionCubit.endSession does, the logout ends the session even when it cannot clear all that it stored.
    blocTest<SignOutBloc, SignOutState>(
      'signs out with stored data left when the logout cannot clear the stored session',
      setUp: () =>
          when(() => authRepository.logout()).thenAnswer((_) async => const Failure<void>(UnknownError('Error'))),
      build: build,
      act: (bloc) => bloc.add(const SignOutRequested()),
      expect: () => const [SignOutInProgress(), SignedOutWithDataLeft()],
    );

    // The app session has ended, but the provider logout failed.
    blocTest<SignOutBloc, SignOutState>(
      'signs out with the provider session left when the provider logout is incomplete',
      setUp: () => when(() => authRepository.logout()).thenAnswer(
        (_) async =>
            Failure<void>(AuthError('provider logout incomplete', code: AppErrorCode.authOidcLogoutIncomplete.key)),
      ),
      build: build,
      act: (bloc) => bloc.add(const SignOutRequested()),
      expect: () => const [SignOutInProgress(), SignedOutWithProviderSessionLeft()],
    );

    // A second tap while the sign-out waits for Studio's record would post a second record and start a second provider
    // logout.
    blocTest<SignOutBloc, SignOutState>(
      'drops a second request while the first sign-out runs',
      setUp: () {
        final logout = Completer<Result<void>>();
        when(() => authRepository.logout()).thenAnswer((_) => logout.future);
        addTearDown(() => logout.isCompleted ? null : logout.complete(const Success<void>(null)));
      },
      build: build,
      act: (bloc) async {
        bloc.add(const SignOutRequested());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const SignOutRequested());
        await Future<void>.delayed(Duration.zero);
      },
      expect: () => const [SignOutInProgress()],
      verify: (_) => verify(() => authRepository.logout()).called(1),
    );

    blocTest<SignOutBloc, SignOutState>(
      'signs out again after an earlier sign-out',
      setUp: () => when(() => authRepository.logout()).thenAnswer((_) async => const Success<void>(null)),
      build: build,
      seed: () => const SignedOut(),
      act: (bloc) => bloc.add(const SignOutRequested()),
      expect: () => const [SignOutInProgress(), SignedOut()],
    );
  });

  // The provider logout can wait for the browser for minutes, so the sign-out does not wait for it.
  group('SignOutBloc and the provider logout', () {
    late _FakeSsoSignOutRepository signOut;
    late MockIAuthRepository passwordLogout;
    final incomplete = Failure<void>(
      AuthError('provider logout incomplete', code: AppErrorCode.authOidcLogoutIncomplete.key),
    );

    setUp(() {
      signOut = _FakeSsoSignOutRepository();
      passwordLogout = MockIAuthRepository();
    });

    SignOutBloc build() =>
        SignOutBloc(logoutUseCase: LogoutUseCase(passwordLogout), ssoSignOutUseCase: SsoSignOutUseCase(signOut));

    blocTest<SignOutBloc, SignOutState>(
      'signs out once the session on this device is cleared, while the provider logout has not ended',
      build: build,
      act: (bloc) => bloc.add(const SignOutRequested()),
      expect: () => const [SignOutInProgress(), SignedOut()],
      verify: (_) => verifyNever(() => passwordLogout.logout()),
    );

    blocTest<SignOutBloc, SignOutState>(
      'then tells that the provider session is left when the provider logout fails',
      build: build,
      act: (bloc) async {
        bloc.add(const SignOutRequested());
        await Future<void>.delayed(Duration.zero);
        signOut.providerLogout.complete(incomplete);
      },
      expect: () => const [SignOutInProgress(), SignedOut(), SignedOutWithProviderSessionLeft()],
    );

    blocTest<SignOutBloc, SignOutState>(
      'stays signed out when the provider session ends',
      build: build,
      act: (bloc) async {
        bloc.add(const SignOutRequested());
        await Future<void>.delayed(Duration.zero);
        signOut.providerLogout.complete(const Success(null));
      },
      expect: () => const [SignOutInProgress(), SignedOut()],
    );

    // The provider logout waits for the browser, so it must not keep a later sign-out from running.
    blocTest<SignOutBloc, SignOutState>(
      'takes a new request once signed out, while the provider logout is still on its way',
      build: build,
      act: (bloc) async {
        bloc.add(const SignOutRequested());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const SignOutRequested());
        await Future<void>.delayed(Duration.zero);
      },
      expect: () => const [SignOutInProgress(), SignedOut(), SignOutInProgress(), SignedOut()],
      verify: (_) => expect(signOut.calls, 2),
    );

    // The data left on this device is the more serious of the two, and the user can only be told one of them.
    blocTest<SignOutBloc, SignOutState>(
      'keeps the stored data left state of a failed wipe when the provider logout fails too',
      setUp: () => signOut.cleared = const Failure<void>(UnknownError('Session clear failed: jwtToken')),
      build: build,
      act: (bloc) async {
        bloc.add(const SignOutRequested());
        await Future<void>.delayed(Duration.zero);
        signOut.providerLogout.complete(incomplete);
      },
      expect: () => const [SignOutInProgress(), SignedOutWithDataLeft()],
    );
  });
}

/// The logout: the session on this device is cleared with [cleared], and the provider logout ends
/// when the test completes [providerLogout]; [calls] counts the sign-outs.
class _FakeSsoSignOutRepository implements ISsoSignOutRepository {
  Result<void> cleared = const Success(null);
  final providerLogout = Completer<Result<void>>();
  var calls = 0;

  @override
  Future<SsoSignOut> signOut() async {
    calls++;
    return SsoSignOut(cleared: cleared, providerLogout: providerLogout.future);
  }
}
