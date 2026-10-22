import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/features/auth/application/login_bloc.dart';
import 'package:libredb_mobile/features/auth/domain/entities/sso_sign_in_result.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mock_classes.dart';

void main() {
  late MockSignInWithSsoUseCase signInWithSso;

  setUp(() => signInWithSso = MockSignInWithSsoUseCase());

  group('LoginState', () {
    test('compares by value', () {
      expect(const LoginInitialState(), const LoginInitialState());
      expect(const LoginLoadingState(), const LoginLoadingState());
      expect(
        const LoginErrorState(errorCode: AppErrorCode.authOidcFailed),
        isNot(const LoginErrorState(errorCode: AppErrorCode.authOidcDiscovery)),
      );
    });
  });

  group('LoginBloc', () {
    test('starts blank', () {
      expect(LoginBloc(signInWithSsoUseCase: signInWithSso).state, const LoginInitialState());
    });

    blocTest<LoginBloc, LoginState>(
      'emits the signed-in state with the username and roles the sign-in gives',
      setUp: () => when(() => signInWithSso()).thenAnswer(
        (_) async => const SsoSignInSucceeded(username: 'admin@example.com', roles: ['ROLE_ADMIN', 'ROLE_USER']),
      ),
      build: () => LoginBloc(signInWithSsoUseCase: signInWithSso),
      act: (bloc) => bloc.add(const SsoSignInRequested()),
      expect: () => [
        const LoginLoadingState(),
        const LoginLoadedState(username: 'admin@example.com', roles: ['ROLE_ADMIN', 'ROLE_USER']),
      ],
    );

    blocTest<LoginBloc, LoginState>(
      'returns to the blank sign-in when the user cancels',
      setUp: () => when(() => signInWithSso()).thenAnswer((_) async => const SsoSignInCancelled()),
      build: () => LoginBloc(signInWithSsoUseCase: signInWithSso),
      act: (bloc) => bloc.add(const SsoSignInRequested()),
      expect: () => [const LoginLoadingState(), const LoginInitialState()],
    );

    blocTest<LoginBloc, LoginState>(
      'emits the error code of a rejected sign-in',
      setUp: () =>
          when(() => signInWithSso()).thenAnswer((_) async => const SsoSignInRejected(AppErrorCode.authOidcFailed)),
      build: () => LoginBloc(signInWithSsoUseCase: signInWithSso),
      act: (bloc) => bloc.add(const SsoSignInRequested()),
      expect: () => [const LoginLoadingState(), const LoginErrorState(errorCode: AppErrorCode.authOidcFailed)],
    );

    final pending = <Completer<SsoSignInResult>>[];
    blocTest<LoginBloc, LoginState>(
      'drops a second request while the first sign-in is running',
      setUp: () {
        pending.clear();
        when(() => signInWithSso()).thenAnswer((_) {
          final completer = Completer<SsoSignInResult>();
          pending.add(completer);
          return completer.future;
        });
      },
      build: () => LoginBloc(signInWithSsoUseCase: signInWithSso),
      act: (bloc) async {
        bloc.add(const SsoSignInRequested());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const SsoSignInRequested());
        await Future<void>.delayed(Duration.zero);
        pending.single.complete(const SsoSignInSucceeded(username: 'jdoe', roles: ['ROLE_USER']));
      },
      expect: () => [
        const LoginLoadingState(),
        const LoginLoadedState(username: 'jdoe', roles: ['ROLE_USER']),
      ],
      verify: (_) => verify(() => signInWithSso()).called(1),
    );

    blocTest<LoginBloc, LoginState>(
      'returns to the blank sign-in on a reset',
      seed: () => const LoginErrorState(errorCode: AppErrorCode.authOidcFailed),
      build: () => LoginBloc(signInWithSsoUseCase: signInWithSso),
      act: (bloc) => bloc.add(const LoginReset()),
      expect: () => [const LoginInitialState()],
    );

    blocTest<LoginBloc, LoginState>(
      'throws when the build has no single sign-on, as a misconfigured build has none',
      build: () => LoginBloc(),
      act: (bloc) => bloc.add(const SsoSignInRequested()),
      expect: () => <LoginState>[],
      errors: () => [
        isA<StateError>().having((e) => e.message, 'message', 'single sign-on is not configured in this build'),
      ],
    );
  });
}
