import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/features/auth/application/session_target_switch_bloc.dart';
import 'package:libredb_mobile/features/auth/domain/entities/session_target_switch_result.dart';
import 'package:libredb_mobile/shared/models/platform_identity.dart';
import 'package:libredb_mobile/shared/models/session_target.dart';
import 'package:libredb_mobile/shared/models/studio_identity.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mock_classes.dart';

const _user = StudioIdentity(username: 'user', role: StudioAdminRole(), viaBearer: true);

const _admin = PlatformIdentity(
  id: 'usr_1',
  email: 'admin@example.com',
  roles: ['PLATFORM_ADMIN'],
  permissions: [],
  tenant: PlatformTenant(id: 'tnt_1', name: 'Example', slug: 'example'),
);

void main() {
  late MockSwitchSessionTargetUseCase switchTarget;

  setUp(() => switchTarget = MockSwitchSessionTargetUseCase());

  SessionTargetSwitchBloc build() => SessionTargetSwitchBloc(switchTarget: switchTarget);

  test('starts idle', () => expect(build().state, const SessionTargetSwitchIdle()));

  blocTest<SessionTargetSwitchBloc, SessionTargetSwitchState>(
    'a switch to Platform that Platform accepts runs, then succeeds with the identity',
    setUp: () =>
        when(() => switchTarget(SessionTarget.platform)).thenAnswer((_) async => const SwitchedToPlatform(_admin)),
    build: build,
    act: (bloc) => bloc.add(const SessionTargetSwitchRequested(SessionTarget.platform)),
    expect: () => const [
      SessionTargetSwitchInProgress(SessionTarget.platform),
      SessionTargetSwitchSucceeded(SwitchedToPlatform(_admin)),
    ],
  );

  blocTest<SessionTargetSwitchBloc, SessionTargetSwitchState>(
    'a switch to Studio that Studio accepts runs, then succeeds with the identity',
    setUp: () => when(() => switchTarget(SessionTarget.studio)).thenAnswer((_) async => const SwitchedToStudio(_user)),
    build: build,
    act: (bloc) => bloc.add(const SessionTargetSwitchRequested(SessionTarget.studio)),
    expect: () => const [
      SessionTargetSwitchInProgress(SessionTarget.studio),
      SessionTargetSwitchSucceeded(SwitchedToStudio(_user)),
    ],
  );

  blocTest<SessionTargetSwitchBloc, SessionTargetSwitchState>(
    'a refused switch runs, then is refused with the code',
    setUp: () =>
        when(() => switchTarget(SessionTarget.platform))
            .thenAnswer((_) async => const SessionTargetSwitchRefused(AppErrorCode.platformAdminRoleRequired)),
    build: build,
    act: (bloc) => bloc.add(const SessionTargetSwitchRequested(SessionTarget.platform)),
    expect: () => const [
      SessionTargetSwitchInProgress(SessionTarget.platform),
      SessionTargetSwitchRefusedState(AppErrorCode.platformAdminRoleRequired),
    ],
  );

  blocTest<SessionTargetSwitchBloc, SessionTargetSwitchState>(
    'the same refusal twice is told twice',
    setUp: () =>
        when(() => switchTarget(SessionTarget.platform))
            .thenAnswer((_) async => const SessionTargetSwitchRefused(AppErrorCode.platformLicenseAdminSeats)),
    build: build,
    act: (bloc) async {
      bloc.add(const SessionTargetSwitchRequested(SessionTarget.platform));
      await Future<void>.delayed(Duration.zero);
      bloc.add(const SessionTargetSwitchRequested(SessionTarget.platform));
    },
    expect: () => const [
      SessionTargetSwitchInProgress(SessionTarget.platform),
      SessionTargetSwitchRefusedState(AppErrorCode.platformLicenseAdminSeats),
      SessionTargetSwitchInProgress(SessionTarget.platform),
      SessionTargetSwitchRefusedState(AppErrorCode.platformLicenseAdminSeats),
    ],
  );

  blocTest<SessionTargetSwitchBloc, SessionTargetSwitchState>(
    'a switch whose session ended while it ran is abandoned',
    setUp: () =>
        when(() => switchTarget(SessionTarget.platform)).thenAnswer((_) async => const SessionTargetSwitchAbandoned()),
    build: build,
    act: (bloc) => bloc.add(const SessionTargetSwitchRequested(SessionTarget.platform)),
    expect: () => const [SessionTargetSwitchInProgress(SessionTarget.platform), SessionTargetSwitchAbandonedState()],
  );

  final answer = Completer<SessionTargetSwitchResult>();
  blocTest<SessionTargetSwitchBloc, SessionTargetSwitchState>(
    'a second request while one runs is dropped',
    setUp: () => when(() => switchTarget(any())).thenAnswer((_) => answer.future),
    build: build,
    act: (bloc) async {
      bloc.add(const SessionTargetSwitchRequested(SessionTarget.platform));
      await Future<void>.delayed(Duration.zero);
      bloc.add(const SessionTargetSwitchRequested(SessionTarget.platform));
      bloc.add(const SessionTargetSwitchRequested(SessionTarget.studio));
      await Future<void>.delayed(Duration.zero);
      answer.complete(const SwitchedToPlatform(_admin));
    },
    expect: () => const [
      SessionTargetSwitchInProgress(SessionTarget.platform),
      SessionTargetSwitchSucceeded(SwitchedToPlatform(_admin)),
    ],
    verify: (_) => verify(() => switchTarget(any())).called(1),
  );
}
