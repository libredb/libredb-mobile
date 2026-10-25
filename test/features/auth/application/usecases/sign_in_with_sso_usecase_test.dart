import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/auth/application/usecases/sign_in_with_sso_usecase.dart';
import 'package:libredb_mobile/features/auth/domain/entities/sso_sign_in_result.dart';
import 'package:libredb_mobile/shared/models/studio_identity.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/shared/models/session_target.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mock_classes.dart';

const _user = StudioIdentity(username: 'user@example.com', role: StudioUserRole(), viaBearer: true);

void main() {
  late MockISsoAuthRepository ssoRepository;
  late MockIStudioIdentityRepository identityRepository;
  late MockIAuthSessionRepository sessionRepository;
  late SignInWithSsoUseCase signIn;

  setUp(() {
    ssoRepository = MockISsoAuthRepository();
    identityRepository = MockIStudioIdentityRepository();
    sessionRepository = MockIAuthSessionRepository();
    signIn = SignInWithSsoUseCase(ssoRepository, identityRepository, sessionRepository);
    when(() => ssoRepository.signIn(target: SessionTarget.studio)).thenAnswer((_) async => const SsoProviderSignedIn());
    when(() => sessionRepository.clear()).thenAnswer((_) async => const Success(null));
  });

  void studioAnswers(Result<StudioIdentity> answer) =>
      when(() => identityRepository.fetch()).thenAnswer((_) async => answer);

  group('SignInWithSsoUseCase', () {
    test('a stored sign-in that Studio accepts succeeds with the identity Studio answered', () async {
      studioAnswers(const Success(_user));

      final result = await signIn();

      expect(result, isA<SsoSignInSucceeded>().having((r) => r.identity, 'identity', _user));
      verify(() => ssoRepository.signIn(target: SessionTarget.studio)).called(1);
      verify(() => identityRepository.fetch()).called(1);
      verifyNever(() => sessionRepository.clear());
    });

    // Studio main answers a refused account at /api/auth/me with 401 {"authenticated":false}, no code.
    test('a stored sign-in that Studio refuses with 401 clears the session and rejects as refused', () async {
      studioAnswers(const Failure(AuthError('Unauthorized')));

      final result = await signIn();

      expect(
        result,
        isA<SsoSignInRejected>().having((r) => r.errorCode, 'errorCode', AppErrorCode.studioAccountRefused),
      );
      verify(() => sessionRepository.clear()).called(1);
    });

    // libredb-studio#1922 answers 401 AUTH_REQUIRED for a token Studio refuses itself, after the refresh.
    test('a 401 AUTH_REQUIRED at sign-in also rejects as refused', () async {
      studioAnswers(Failure(AuthError('Invalid access token', code: AppErrorCode.authInvalidAccessToken.key)));

      final result = await signIn();

      expect(
        result,
        isA<SsoSignInRejected>().having((r) => r.errorCode, 'errorCode', AppErrorCode.studioAccountRefused),
      );
      verify(() => sessionRepository.clear()).called(1);
    });

    for (final code in [AppErrorCode.studioAccountHasNoRole, AppErrorCode.studioAccountHasNoIdentity]) {
      test('a 403 that refuses the account rejects with ${code.key} and clears once', () async {
        studioAnswers(Failure(AuthError('refused', code: code.key)));

        final result = await signIn();

        expect(result, isA<SsoSignInRejected>().having((r) => r.errorCode, 'errorCode', code));
        verify(() => sessionRepository.clear()).called(1);
      });
    }

    for (final (failure, code) in [
      (
        ServerError('provider down', code: AppErrorCode.studioIdentityProviderUnavailable.key),
        AppErrorCode.studioIdentityProviderUnavailable,
      ),
      (NetworkError('blocked', code: AppErrorCode.networkCertInvalid.key), AppErrorCode.networkCertInvalid),
      (const NetworkError('no route to host'), AppErrorCode.generic),
      (ServerError('unreadable', code: AppErrorCode.studioUnreadableAnswer.key), AppErrorCode.studioUnreadableAnswer),
    ]) {
      test(
        'any other failure of /auth/me (${failure.runtimeType} ${failure.code}) clears and rejects with its code',
        () async {
          studioAnswers(Failure(failure));

          final result = await signIn();

          expect(result, isA<SsoSignInRejected>().having((r) => r.errorCode, 'errorCode', code));
          verify(() => sessionRepository.clear()).called(1);
        },
      );
    }

    test('a clear that fails still rejects', () async {
      studioAnswers(const Failure(AuthError('Unauthorized')));
      when(() => sessionRepository.clear()).thenAnswer((_) async => const Failure(UnknownError('disk full')));

      final result = await signIn();

      expect(
        result,
        isA<SsoSignInRejected>().having((r) => r.errorCode, 'errorCode', AppErrorCode.studioAccountRefused),
      );
      verify(() => sessionRepository.clear()).called(1);
    });

    test('a sign-in the user cancels at the provider asks Studio nothing and clears nothing', () async {
      when(() => ssoRepository.signIn(target: SessionTarget.studio))
          .thenAnswer((_) async => const SsoProviderCancelled());

      expect(await signIn(), isA<SsoSignInCancelled>());
      verifyNever(() => identityRepository.fetch());
      verifyNever(() => sessionRepository.clear());
    });

    test('a sign-in the provider refuses rejects with its code, asks Studio nothing and clears nothing', () async {
      when(() => ssoRepository.signIn(target: SessionTarget.studio))
          .thenAnswer((_) async => const SsoProviderRejected(AppErrorCode.authOidcFailed));

      expect(
        await signIn(),
        isA<SsoSignInRejected>().having((r) => r.errorCode, 'errorCode', AppErrorCode.authOidcFailed),
      );
      verifyNever(() => identityRepository.fetch());
      verifyNever(() => sessionRepository.clear());
    });
  });
}
