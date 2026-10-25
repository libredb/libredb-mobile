import 'package:libredb_mobile/core/errors/app_api_exception.dart';
import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/auth/application/usecases/sign_in_usecase.dart';
import 'package:libredb_mobile/features/auth/domain/entities/sso_sign_in_result.dart';
import 'package:libredb_mobile/infrastructure/platform/platform_errors.dart';
import 'package:libredb_mobile/shared/models/platform_identity.dart';
import 'package:libredb_mobile/shared/models/studio_identity.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/shared/models/session_target.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mock_classes.dart';
import '../../../../support/printed_lines.dart';

const _user = StudioIdentity(username: 'user@example.com', role: StudioUserRole(), viaBearer: true);

const _admin = PlatformIdentity(
  id: 'usr_1',
  email: 'admin@example.com',
  name: 'Ada Admin',
  roles: ['PLATFORM_ADMIN'],
  permissions: ['connections:read'],
  tenant: PlatformTenant(id: 'tnt_1', name: 'Example', slug: 'example'),
);

/// What `PlatformApiClient` throws for a Platform answer of [status] with the error code [code].
AppException _platformAnswer(int status, String? code) => switch (status) {
  401 || 403 => UnauthorizedException('Platform answered $status $code', statusCode: status, errorCode: code),
  _ => FetchDataException('Platform answered $status $code', statusCode: status, errorCode: code),
};

void main() {
  late MockISsoAuthRepository ssoRepository;
  late MockIStudioIdentityRepository studioIdentity;
  late MockPlatformIdentityRepository platformIdentity;
  late MockIAuthSessionRepository sessionRepository;
  late SignInUseCase signIn;

  setUp(() {
    ssoRepository = MockISsoAuthRepository();
    studioIdentity = MockIStudioIdentityRepository();
    platformIdentity = MockPlatformIdentityRepository();
    sessionRepository = MockIAuthSessionRepository();
    signIn = SignInUseCase(ssoRepository, studioIdentity, platformIdentity, sessionRepository);
    for (final target in SessionTarget.values) {
      when(() => ssoRepository.signIn(target: target)).thenAnswer((_) async => const SsoProviderSignedIn());
    }
    when(() => sessionRepository.clear()).thenAnswer((_) async => const Success(null));
  });

  void studioAnswers(Result<StudioIdentity> answer) =>
      when(() => studioIdentity.fetch()).thenAnswer((_) async => answer);

  void platformAnswers(Result<PlatformIdentity> answer) =>
      when(() => platformIdentity.fetch()).thenAnswer((_) async => answer);

  group('SignInUseCase for Studio', () {
    test('a stored sign-in that Studio accepts succeeds with the identity Studio answered', () async {
      studioAnswers(const Success(_user));

      final result = await signIn(SessionTarget.studio);

      expect(result, isA<StudioSignInSucceeded>().having((r) => r.identity, 'identity', _user));
      verify(() => ssoRepository.signIn(target: SessionTarget.studio)).called(1);
      verify(() => studioIdentity.fetch()).called(1);
      verifyNever(() => platformIdentity.fetch());
      verifyNever(() => sessionRepository.clear());
    });

    // Studio main answers a refused account at /api/auth/me with 401 {"authenticated":false}, no code.
    test('a stored sign-in that Studio refuses with 401 clears the session and rejects as refused', () async {
      studioAnswers(const Failure(AuthError('Unauthorized')));

      final result = await signIn(SessionTarget.studio);

      expect(
        result,
        isA<SsoSignInRejected>().having((r) => r.errorCode, 'errorCode', AppErrorCode.studioAccountRefused),
      );
      verify(() => sessionRepository.clear()).called(1);
      verifyNever(() => platformIdentity.fetch());
    });

    // libredb-studio#1922 answers 401 AUTH_REQUIRED for a token Studio refuses itself, after the refresh.
    test('a 401 AUTH_REQUIRED at sign-in also rejects as refused', () async {
      studioAnswers(Failure(AuthError('Invalid access token', code: AppErrorCode.authInvalidAccessToken.key)));

      final result = await signIn(SessionTarget.studio);

      expect(
        result,
        isA<SsoSignInRejected>().having((r) => r.errorCode, 'errorCode', AppErrorCode.studioAccountRefused),
      );
      verify(() => sessionRepository.clear()).called(1);
    });

    for (final code in [AppErrorCode.studioAccountHasNoRole, AppErrorCode.studioAccountHasNoIdentity]) {
      test('a 403 that refuses the account rejects with ${code.key} and clears once', () async {
        studioAnswers(Failure(AuthError('refused', code: code.key)));

        final result = await signIn(SessionTarget.studio);

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

          final result = await signIn(SessionTarget.studio);

          expect(result, isA<SsoSignInRejected>().having((r) => r.errorCode, 'errorCode', code));
          verify(() => sessionRepository.clear()).called(1);
        },
      );
    }

    test('a clear that fails still rejects', () async {
      studioAnswers(const Failure(AuthError('Unauthorized')));
      when(() => sessionRepository.clear()).thenAnswer((_) async => const Failure(UnknownError('disk full')));

      final result = await signIn(SessionTarget.studio);

      expect(
        result,
        isA<SsoSignInRejected>().having((r) => r.errorCode, 'errorCode', AppErrorCode.studioAccountRefused),
      );
      verify(() => sessionRepository.clear()).called(1);
    });

    test('a Studio sign-in works in a build without a Platform target', () async {
      studioAnswers(const Success(_user));
      final studioOnly = SignInUseCase(ssoRepository, studioIdentity, null, sessionRepository);

      expect(await studioOnly(SessionTarget.studio), isA<StudioSignInSucceeded>());
    });
  });

  group('SignInUseCase for Platform', () {
    test('a stored sign-in that Platform accepts succeeds with the identity Platform answered', () async {
      platformAnswers(const Success(_admin));

      final result = await signIn(SessionTarget.platform);

      expect(result, isA<PlatformSignInSucceeded>().having((r) => r.identity, 'identity', _admin));
      verify(() => ssoRepository.signIn(target: SessionTarget.platform)).called(1);
      verify(() => platformIdentity.fetch()).called(1);
      verifyNever(() => studioIdentity.fetch());
      verifyNever(() => sessionRepository.clear());
    });

    // Each refusal of GET /api/v1/me in the order libredb-platform checks it (src/shared/lib/bearer/with-bearer.ts),
    // through the mapping the Platform identity repository applies.
    final refusals = <(String, Object, AppErrorCode)>[
      ('404 API_DISABLED', _platformAnswer(404, 'API_DISABLED'), AppErrorCode.platformApiDisabled),
      (
        '401 BEARER_INVALID after the refresh',
        _platformAnswer(401, 'BEARER_INVALID'),
        AppErrorCode.platformAccountRefused,
      ),
      ('401 without an envelope', _platformAnswer(401, null), AppErrorCode.platformAccountRefused),
      (
        '503 IDENTITY_PROVIDER_UNAVAILABLE',
        _platformAnswer(503, 'IDENTITY_PROVIDER_UNAVAILABLE'),
        AppErrorCode.platformIdentityProviderUnavailable,
      ),
      ('403 ADMIN_ROLE_REQUIRED', _platformAnswer(403, 'ADMIN_ROLE_REQUIRED'), AppErrorCode.platformAdminRoleRequired),
      (
        '503 KEYCLOAK_UNAVAILABLE',
        _platformAnswer(503, 'KEYCLOAK_UNAVAILABLE'),
        AppErrorCode.platformKeycloakUnavailable,
      ),
      (
        '502 KEYCLOAK_AUTH_ERROR',
        _platformAnswer(502, 'KEYCLOAK_AUTH_ERROR'),
        AppErrorCode.platformKeycloakUnavailable,
      ),
      (
        '502 KEYCLOAK_PERMISSION_ERROR',
        _platformAnswer(502, 'KEYCLOAK_PERMISSION_ERROR'),
        AppErrorCode.platformKeycloakUnavailable,
      ),
      ('404 KEYCLOAK_NOT_FOUND', _platformAnswer(404, 'KEYCLOAK_NOT_FOUND'), AppErrorCode.platformKeycloakUnavailable),
      ('403 LICENSE_INVALID', _platformAnswer(403, 'LICENSE_INVALID'), AppErrorCode.platformLicenseInvalid),
      ('403 LICENSE_EXPIRED', _platformAnswer(403, 'LICENSE_EXPIRED'), AppErrorCode.platformLicenseExpired),
      ('403 LICENSE_ADMIN_SEATS', _platformAnswer(403, 'LICENSE_ADMIN_SEATS'), AppErrorCode.platformLicenseAdminSeats),
      ('500 INTERNAL_ERROR', _platformAnswer(500, 'INTERNAL_ERROR'), AppErrorCode.platformInternalError),
      ('an unreadable answer', const FormatException('missing id'), AppErrorCode.platformUnreadableAnswer),
      ('no network', OfflineException(), AppErrorCode.networkOffline),
    ];
    for (final (name, thrown, code) in refusals) {
      test('$name clears the session once, rejects with ${code.key} and starts no provider logout', () async {
        platformAnswers(Failure(platformError(thrown)));

        final result = await signIn(SessionTarget.platform);

        expect(result, isA<SsoSignInRejected>().having((r) => r.errorCode, 'errorCode', code));
        verify(() => sessionRepository.clear()).called(1);
        verifyNoMoreInteractions(sessionRepository);
        verify(() => ssoRepository.signIn(target: SessionTarget.platform)).called(1);
        verifyNoMoreInteractions(ssoRepository);
        verifyNever(() => studioIdentity.fetch());
      });
    }

    test('a 401 never maps to a Studio code or to the access token code', () async {
      platformAnswers(Failure(AuthError('Unauthorized', code: AppErrorCode.authInvalidAccessToken.key)));

      final result = await signIn(SessionTarget.platform);

      expect(
        result,
        isA<SsoSignInRejected>()
            .having((r) => r.errorCode, 'errorCode', AppErrorCode.platformAccountRefused)
            .having((r) => r.errorCode, 'errorCode', isNot(AppErrorCode.studioAccountRefused)),
      );
    });

    test('a platform code carried by any error type is shown as it is', () async {
      for (final error in <AppError>[
        AuthError('refused', code: AppErrorCode.platformLicenseAdminSeats.key),
        ServerError('down', code: AppErrorCode.platformLicenseAdminSeats.key),
        NotFoundError('gone', code: AppErrorCode.platformLicenseAdminSeats.key),
      ]) {
        platformAnswers(Failure(error));

        final result = await signIn(SessionTarget.platform);

        expect(
          result,
          isA<SsoSignInRejected>().having((r) => r.errorCode, 'errorCode', AppErrorCode.platformLicenseAdminSeats),
        );
      }
    });

    test('a timeout without a code shows the generic text', () async {
      platformAnswers(Failure(platformError(TimeoutBeforeSentException())));

      final result = await signIn(SessionTarget.platform);

      expect(result, isA<SsoSignInRejected>().having((r) => r.errorCode, 'errorCode', AppErrorCode.generic));
    });

    test('a refusal logs one warn with the target and the code key only', () async {
      platformAnswers(Failure(platformError(_platformAnswer(403, 'ADMIN_ROLE_REQUIRED'))));

      final lines = await printedLines(() => signIn(SessionTarget.platform));

      expect(lines.where((line) => line.contains('[W]')), [
        contains(
          'The platform gate refused the sign-in, so the stored session is cleared: platform.admin_role_required',
        ),
      ]);
      final printed = lines.join('\n');
      expect(printed, isNot(contains('admin@example.com')));
      expect(printed, isNot(contains('Platform answered')));
      expect(printed, isNot(contains('Bearer')));
    });

    test('a clear that fails still rejects', () async {
      platformAnswers(Failure(platformError(_platformAnswer(403, 'ADMIN_ROLE_REQUIRED'))));
      when(() => sessionRepository.clear()).thenAnswer((_) async => const Failure(UnknownError('disk full')));

      final result = await signIn(SessionTarget.platform);

      expect(
        result,
        isA<SsoSignInRejected>().having((r) => r.errorCode, 'errorCode', AppErrorCode.platformAdminRoleRequired),
      );
      verify(() => sessionRepository.clear()).called(1);
    });

    test('a Platform request without a Platform identity repository throws', () async {
      final studioOnly = SignInUseCase(ssoRepository, studioIdentity, null, sessionRepository);

      await expectLater(studioOnly(SessionTarget.platform), throwsStateError);
      verifyNever(() => ssoRepository.signIn(target: SessionTarget.platform));
    });
  });

  group('SignInUseCase at the provider', () {
    for (final target in SessionTarget.values) {
      test('a ${target.name} sign-in the user cancels asks no gate and clears nothing', () async {
        when(() => ssoRepository.signIn(target: target)).thenAnswer((_) async => const SsoProviderCancelled());

        expect(await signIn(target), isA<SsoSignInCancelled>());
        verifyNever(() => studioIdentity.fetch());
        verifyNever(() => platformIdentity.fetch());
        verifyNever(() => sessionRepository.clear());
      });

      test('a ${target.name} sign-in the provider refuses rejects with its code and clears nothing', () async {
        when(() => ssoRepository.signIn(target: target))
            .thenAnswer((_) async => const SsoProviderRejected(AppErrorCode.authOidcFailed));

        expect(
          await signIn(target),
          isA<SsoSignInRejected>().having((r) => r.errorCode, 'errorCode', AppErrorCode.authOidcFailed),
        );
        verifyNever(() => studioIdentity.fetch());
        verifyNever(() => platformIdentity.fetch());
        verifyNever(() => sessionRepository.clear());
      });
    }
  });
}
