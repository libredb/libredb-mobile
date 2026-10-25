import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/features/auth/application/login_bloc.dart';
import 'package:libredb_mobile/features/auth/domain/entities/sso_sign_in_result.dart';
import 'package:libredb_mobile/shared/models/platform_identity.dart';
import 'package:libredb_mobile/shared/models/session_target.dart';
import 'package:libredb_mobile/shared/models/studio_identity.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mock_classes.dart';

const _admin = StudioIdentity(username: 'admin@example.com', role: StudioAdminRole(), viaBearer: true);

const _platformAdmin = PlatformIdentity(
  id: 'usr_1',
  email: 'admin@example.com',
  roles: ['PLATFORM_ADMIN'],
  permissions: [],
  tenant: PlatformTenant(id: 'tnt_1', name: 'Example', slug: 'example'),
);

const _studio = SessionTarget.studio;
const _platform = SessionTarget.platform;

void main() {
  late MockSignInUseCase signIn;

  setUp(() => signIn = MockSignInUseCase());

  group('LoginState', () {
    test('compares by value', () {
      expect(const LoginInitialState(), const LoginInitialState());
      expect(const LoginLoadingState(target: _studio), const LoginLoadingState(target: _studio));
      expect(const LoginLoadingState(target: _studio), isNot(const LoginLoadingState(target: _platform)));
      expect(const LoginLoadedState(target: _studio), isNot(const LoginLoadedState(target: _platform)));
      expect(const SsoSignInRequested(target: _studio), isNot(const SsoSignInRequested(target: _platform)));
      expect(
        const LoginErrorState(errorCode: AppErrorCode.authOidcFailed),
        isNot(const LoginErrorState(errorCode: AppErrorCode.authOidcDiscovery)),
      );
    });
  });

  group('LoginBloc', () {
    test('starts blank', () {
      expect(LoginBloc(signInUseCase: signIn).state, const LoginInitialState());
    });

    // The state carries no role: the role comes only from Studio's /api/auth/me, which the shell reads.
    blocTest<LoginBloc, LoginState>(
      'emits the signed-in state, without a role, when Studio accepts the account',
      setUp: () => when(() => signIn(_studio)).thenAnswer((_) async => const StudioSignInSucceeded(_admin)),
      build: () => LoginBloc(signInUseCase: signIn),
      act: (bloc) => bloc.add(const SsoSignInRequested(target: _studio)),
      expect: () => [const LoginLoadingState(target: _studio), const LoginLoadedState(target: _studio)],
    );

    blocTest<LoginBloc, LoginState>(
      'emits the error code of an account Studio refuses',
      setUp: () =>
          when(() => signIn(_studio))
              .thenAnswer((_) async => const SsoSignInRejected(AppErrorCode.studioAccountRefused)),
      build: () => LoginBloc(signInUseCase: signIn),
      act: (bloc) => bloc.add(const SsoSignInRequested(target: _studio)),
      expect: () => [
        const LoginLoadingState(target: _studio),
        const LoginErrorState(errorCode: AppErrorCode.studioAccountRefused),
      ],
    );

    blocTest<LoginBloc, LoginState>(
      'returns to the blank sign-in when the user cancels',
      setUp: () => when(() => signIn(_studio)).thenAnswer((_) async => const SsoSignInCancelled()),
      build: () => LoginBloc(signInUseCase: signIn),
      act: (bloc) => bloc.add(const SsoSignInRequested(target: _studio)),
      expect: () => [const LoginLoadingState(target: _studio), const LoginInitialState()],
    );

    blocTest<LoginBloc, LoginState>(
      'emits the error code of a rejected sign-in',
      setUp: () =>
          when(() => signIn(_studio)).thenAnswer((_) async => const SsoSignInRejected(AppErrorCode.authOidcFailed)),
      build: () => LoginBloc(signInUseCase: signIn),
      act: (bloc) => bloc.add(const SsoSignInRequested(target: _studio)),
      expect: () => [
        const LoginLoadingState(target: _studio),
        const LoginErrorState(errorCode: AppErrorCode.authOidcFailed),
      ],
    );

    final pending = <Completer<SsoSignInResult>>[];
    blocTest<LoginBloc, LoginState>(
      'drops a second request while the first sign-in is running',
      setUp: () {
        pending.clear();
        when(() => signIn(_studio)).thenAnswer((_) {
          final completer = Completer<SsoSignInResult>();
          pending.add(completer);
          return completer.future;
        });
      },
      build: () => LoginBloc(signInUseCase: signIn),
      act: (bloc) async {
        bloc.add(const SsoSignInRequested(target: _studio));
        await Future<void>.delayed(Duration.zero);
        bloc.add(const SsoSignInRequested(target: _studio));
        await Future<void>.delayed(Duration.zero);
        pending.single.complete(const StudioSignInSucceeded(_admin));
      },
      expect: () => [const LoginLoadingState(target: _studio), const LoginLoadedState(target: _studio)],
      verify: (_) => verify(() => signIn(any())).called(1),
    );

    blocTest<LoginBloc, LoginState>(
      'signs in to Platform with the target of the event, and emits the Platform target of the answer',
      setUp: () => when(() => signIn(_platform)).thenAnswer((_) async => const PlatformSignInSucceeded(_platformAdmin)),
      build: () => LoginBloc(signInUseCase: signIn),
      act: (bloc) => bloc.add(const SsoSignInRequested(target: _platform)),
      expect: () => [const LoginLoadingState(target: _platform), const LoginLoadedState(target: _platform)],
      verify: (_) {
        verify(() => signIn(_platform)).called(1);
        verifyNever(() => signIn(_studio));
      },
    );

    blocTest<LoginBloc, LoginState>(
      'takes the signed-in target from the answer, not from the event',
      setUp: () => when(() => signIn(_platform)).thenAnswer((_) async => const StudioSignInSucceeded(_admin)),
      build: () => LoginBloc(signInUseCase: signIn),
      act: (bloc) => bloc.add(const SsoSignInRequested(target: _platform)),
      expect: () => [const LoginLoadingState(target: _platform), const LoginLoadedState(target: _studio)],
    );

    blocTest<LoginBloc, LoginState>(
      'emits the error code of a Platform refusal',
      setUp: () =>
          when(() => signIn(_platform))
              .thenAnswer((_) async => const SsoSignInRejected(AppErrorCode.platformAdminRoleRequired)),
      build: () => LoginBloc(signInUseCase: signIn),
      act: (bloc) => bloc.add(const SsoSignInRequested(target: _platform)),
      expect: () => [
        const LoginLoadingState(target: _platform),
        const LoginErrorState(errorCode: AppErrorCode.platformAdminRoleRequired),
      ],
    );

    final pendingPlatform = <Completer<SsoSignInResult>>[];
    blocTest<LoginBloc, LoginState>(
      'drops a Studio request while a Platform sign-in is running',
      setUp: () {
        pendingPlatform.clear();
        when(() => signIn(any())).thenAnswer((_) {
          final completer = Completer<SsoSignInResult>();
          pendingPlatform.add(completer);
          return completer.future;
        });
      },
      build: () => LoginBloc(signInUseCase: signIn),
      act: (bloc) async {
        bloc.add(const SsoSignInRequested(target: _platform));
        await Future<void>.delayed(Duration.zero);
        bloc.add(const SsoSignInRequested(target: _studio));
        await Future<void>.delayed(Duration.zero);
        pendingPlatform.single.complete(const PlatformSignInSucceeded(_platformAdmin));
      },
      expect: () => [const LoginLoadingState(target: _platform), const LoginLoadedState(target: _platform)],
      verify: (_) {
        verify(() => signIn(_platform)).called(1);
        verifyNever(() => signIn(_studio));
      },
    );

    blocTest<LoginBloc, LoginState>(
      'returns to the blank sign-in on a reset',
      seed: () => const LoginErrorState(errorCode: AppErrorCode.authOidcFailed),
      build: () => LoginBloc(signInUseCase: signIn),
      act: (bloc) => bloc.add(const LoginReset()),
      expect: () => [const LoginInitialState()],
    );

    blocTest<LoginBloc, LoginState>(
      'throws when the build has no single sign-on, as a misconfigured build has none',
      build: () => LoginBloc(),
      act: (bloc) => bloc.add(const SsoSignInRequested(target: _studio)),
      expect: () => <LoginState>[],
      errors: () => [
        isA<StateError>().having((e) => e.message, 'message', 'single sign-on is not configured in this build'),
      ],
    );
  });
}
