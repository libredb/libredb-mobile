import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/core/errors/app_api_exception.dart';
import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/auth/application/usecases/switch_session_target_usecase.dart';
import 'package:libredb_mobile/features/auth/domain/entities/session_target_switch_result.dart';
import 'package:libredb_mobile/infrastructure/platform/platform_errors.dart';
import 'package:libredb_mobile/infrastructure/storage/session_generation.dart';
import 'package:libredb_mobile/shared/models/platform_identity.dart';
import 'package:libredb_mobile/shared/models/session_target.dart';
import 'package:libredb_mobile/shared/models/studio_identity.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mock_classes.dart';
import '../../../../support/printed_lines.dart';

const _user = StudioIdentity(username: 'user@example.com', role: StudioAdminRole(), viaBearer: true);

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
  late MockIStudioIdentityRepository studioIdentity;
  late MockPlatformIdentityRepository platformIdentity;
  late MockIAuthSessionRepository sessionRepository;
  late SwitchSessionTargetUseCase switchTarget;

  setUp(() {
    studioIdentity = MockIStudioIdentityRepository();
    platformIdentity = MockPlatformIdentityRepository();
    sessionRepository = MockIAuthSessionRepository();
    switchTarget = SwitchSessionTargetUseCase(studioIdentity, platformIdentity, sessionRepository);
    when(() => sessionRepository.persistTarget(any(), generation: any(named: 'generation')))
        .thenAnswer((_) async => const Success(null));
  });

  void studioAnswers(Result<StudioIdentity> answer) =>
      when(() => studioIdentity.fetch()).thenAnswer((_) async => answer);

  void platformAnswers(Result<PlatformIdentity> answer) =>
      when(() => platformIdentity.fetch()).thenAnswer((_) async => answer);

  group('SwitchSessionTargetUseCase to Platform', () {
    test('a 200 from Platform stores the target under the current generation and answers the identity', () async {
      platformAnswers(const Success(_admin));
      final generation = SessionGeneration.current;

      final result = await switchTarget(SessionTarget.platform);

      expect(result, isA<SwitchedToPlatform>().having((r) => r.identity, 'identity', _admin));
      verify(() => platformIdentity.fetch()).called(1);
      verifyNever(() => studioIdentity.fetch());
      verify(() => sessionRepository.persistTarget(SessionTarget.platform, generation: generation)).called(1);
      verifyNoMoreInteractions(sessionRepository);
    });

    final refusals = <(String, Object, AppErrorCode)>[
      ('403 ADMIN_ROLE_REQUIRED', _platformAnswer(403, 'ADMIN_ROLE_REQUIRED'), AppErrorCode.platformAdminRoleRequired),
      ('403 LICENSE_ADMIN_SEATS', _platformAnswer(403, 'LICENSE_ADMIN_SEATS'), AppErrorCode.platformLicenseAdminSeats),
      (
        '401 BEARER_INVALID after the refresh',
        _platformAnswer(401, 'BEARER_INVALID'),
        AppErrorCode.platformAccountRefused,
      ),
      (
        '503 IDENTITY_PROVIDER_UNAVAILABLE',
        _platformAnswer(503, 'IDENTITY_PROVIDER_UNAVAILABLE'),
        AppErrorCode.platformIdentityProviderUnavailable,
      ),
      ('a 503 without a code', _platformAnswer(503, null), AppErrorCode.platformInternalError),
      ('no network', OfflineException(), AppErrorCode.networkOffline),
    ];
    for (final (name, thrown, code) in refusals) {
      test('$name refuses with ${code.key}, stores nothing and clears nothing', () async {
        platformAnswers(Failure(platformError(thrown)));

        final result = await switchTarget(SessionTarget.platform);

        expect(result, isA<SessionTargetSwitchRefused>().having((r) => r.errorCode, 'errorCode', code));
        verifyZeroInteractions(sessionRepository);
        verifyNever(() => studioIdentity.fetch());
      });
    }

    test('a target that cannot be stored refuses with the generic code', () async {
      platformAnswers(const Success(_admin));
      when(() => sessionRepository.persistTarget(any(), generation: any(named: 'generation')))
          .thenAnswer((_) async => const Failure(UnknownError('write failed')));

      final result = await switchTarget(SessionTarget.platform);

      expect(result, isA<SessionTargetSwitchRefused>().having((r) => r.errorCode, 'errorCode', AppErrorCode.generic));
      verifyNever(() => sessionRepository.clear());
    });

    test('a build without a Platform target throws', () async {
      final studioOnly = SwitchSessionTargetUseCase(studioIdentity, null, sessionRepository);

      await expectLater(studioOnly(SessionTarget.platform), throwsStateError);
      verifyZeroInteractions(sessionRepository);
    });
  });

  group('SwitchSessionTargetUseCase to Studio', () {
    test('a 200 from Studio stores the target and answers the identity', () async {
      studioAnswers(const Success(_user));
      final generation = SessionGeneration.current;

      final result = await switchTarget(SessionTarget.studio);

      expect(result, isA<SwitchedToStudio>().having((r) => r.identity, 'identity', _user));
      verifyNever(() => platformIdentity.fetch());
      verify(() => sessionRepository.persistTarget(SessionTarget.studio, generation: generation)).called(1);
      verifyNoMoreInteractions(sessionRepository);
    });

    final refusals = <(AppError, AppErrorCode)>[
      (const AuthError('Unauthorized'), AppErrorCode.studioAccountRefused),
      (AuthError('expired', code: AppErrorCode.authInvalidAccessToken.key), AppErrorCode.studioAccountRefused),
      (AuthError('no role', code: AppErrorCode.studioAccountHasNoRole.key), AppErrorCode.studioAccountHasNoRole),
      (
        AuthError('no identity', code: AppErrorCode.studioAccountHasNoIdentity.key),
        AppErrorCode.studioAccountHasNoIdentity,
      ),
      (
        ServerError('provider down', code: AppErrorCode.studioIdentityProviderUnavailable.key),
        AppErrorCode.studioIdentityProviderUnavailable,
      ),
      (const NetworkError('no route to host'), AppErrorCode.generic),
    ];
    for (final (error, code) in refusals) {
      test('${error.runtimeType} ${error.code} refuses with ${code.key} and stores nothing', () async {
        studioAnswers(Failure(error));

        final result = await switchTarget(SessionTarget.studio);

        expect(result, isA<SessionTargetSwitchRefused>().having((r) => r.errorCode, 'errorCode', code));
        verifyZeroInteractions(sessionRepository);
        verifyNever(() => platformIdentity.fetch());
      });
    }

    test('a Studio switch works in a build without a Platform target', () async {
      studioAnswers(const Success(_user));
      final studioOnly = SwitchSessionTargetUseCase(studioIdentity, null, sessionRepository);

      expect(await studioOnly(SessionTarget.studio), isA<SwitchedToStudio>());
    });
  });

  // A sign-out or an idle timeout while the gate is asked ends the session the switch started under: its answer then
  // belongs to no session, so it is dropped, whichever session is open by the time it arrives.
  group('SwitchSessionTargetUseCase after its session ended', () {
    /// The [answer] of a gate that arrives only after a wipe has ended the session.
    Future<Result<T>> afterWipe<T>(Result<T> answer) async {
      await SessionGeneration.wipe(() async {});
      return answer;
    }

    /// Expects the lines of an abandoned switch: one info line of the use case and nothing at warn or error.
    void expectAbandonedLines(List<String> lines) {
      expect(lines.where((line) => line.contains('[W]') || line.contains('[E]')), isEmpty);
      expect(lines.where((line) => line.contains('SwitchSessionTargetUseCase') && line.contains('[I]')), hasLength(1));
    }

    test('a 200 from Platform is abandoned and stores nothing', () async {
      when(() => platformIdentity.fetch()).thenAnswer((_) => afterWipe(const Success(_admin)));

      late SessionTargetSwitchResult result;
      final lines = await printedLines(() async => result = await switchTarget(SessionTarget.platform));

      expect(result, const SessionTargetSwitchAbandoned());
      verifyZeroInteractions(sessionRepository);
      expectAbandonedLines(lines);
    });

    test('a 200 from Studio is abandoned and stores nothing', () async {
      when(() => studioIdentity.fetch()).thenAnswer((_) => afterWipe(const Success(_user)));

      late SessionTargetSwitchResult result;
      final lines = await printedLines(() async => result = await switchTarget(SessionTarget.studio));

      expect(result, const SessionTargetSwitchAbandoned());
      verifyZeroInteractions(sessionRepository);
      expectAbandonedLines(lines);
    });

    test('a Platform refusal is abandoned', () async {
      when(() => platformIdentity.fetch())
          .thenAnswer((_) => afterWipe(Failure(platformError(_platformAnswer(401, 'BEARER_INVALID')))));

      late SessionTargetSwitchResult result;
      final lines = await printedLines(() async => result = await switchTarget(SessionTarget.platform));

      expect(result, const SessionTargetSwitchAbandoned());
      verifyZeroInteractions(sessionRepository);
      expectAbandonedLines(lines);
    });

    test('a Studio refusal is abandoned', () async {
      when(() => studioIdentity.fetch()).thenAnswer((_) => afterWipe<StudioIdentity>(const Failure(AuthError('no'))));

      late SessionTargetSwitchResult result;
      final lines = await printedLines(() async => result = await switchTarget(SessionTarget.studio));

      expect(result, const SessionTargetSwitchAbandoned());
      verifyZeroInteractions(sessionRepository);
      expectAbandonedLines(lines);
    });

    test('a target that cannot be stored because a wipe started during the write is abandoned', () async {
      platformAnswers(const Success(_admin));
      when(() => sessionRepository.persistTarget(any(), generation: any(named: 'generation'))).thenAnswer(
        (_) => afterWipe<void>(const Failure(UnknownError('The session ended while its target was written'))),
      );

      late SessionTargetSwitchResult result;
      final lines = await printedLines(() async => result = await switchTarget(SessionTarget.platform));

      expect(result, const SessionTargetSwitchAbandoned());
      expectAbandonedLines(lines);
    });

    test('a target that cannot be stored under a live session is still refused with an error line', () async {
      platformAnswers(const Success(_admin));
      when(() => sessionRepository.persistTarget(any(), generation: any(named: 'generation')))
          .thenAnswer((_) async => const Failure(UnknownError('write failed')));

      late SessionTargetSwitchResult result;
      final lines = await printedLines(() async => result = await switchTarget(SessionTarget.platform));

      expect(result, const SessionTargetSwitchRefused(AppErrorCode.generic));
      expect(lines.where((line) => line.contains('SwitchSessionTargetUseCase') && line.contains('[E]')), hasLength(1));
    });
  });

  test('a refusal writes no warn line', () async {
    platformAnswers(Failure(platformError(_platformAnswer(403, 'ADMIN_ROLE_REQUIRED'))));

    final lines = await printedLines(() => switchTarget(SessionTarget.platform));

    expect(lines.where((line) => line.contains('[W]')), isEmpty);
    expect(lines.where((line) => line.contains('SwitchSessionTargetUseCase')), isNotEmpty);
  });
}
