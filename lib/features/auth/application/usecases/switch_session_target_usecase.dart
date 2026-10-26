import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/core/logging/app_logger.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/auth/application/usecases/gate_refusal.dart';
import 'package:libredb_mobile/features/auth/domain/entities/session_target_switch_result.dart';
import 'package:libredb_mobile/features/auth/domain/repositories/auth_session_repository.dart';
import 'package:libredb_mobile/features/auth/domain/repositories/platform_identity_repository.dart';
import 'package:libredb_mobile/features/auth/domain/repositories/studio_identity_repository.dart';
import 'package:libredb_mobile/infrastructure/storage/session_generation.dart';
import 'package:libredb_mobile/shared/models/session_target.dart';

/// Switches the live session to another target without a new sign-in, because one access token carries both
/// audiences (libredb-platform `docs/api/v1.md`).
///
/// Only the gate of the target switched to is asked, with the live session's token: Studio's `GET /api/auth/me`, sent
/// as a probe ([IStudioIdentityRepository.fetch]) so a refused switch never opens the circuit for it, or Platform's
/// `GET /api/v1/me`. Only its 200 rewrites the stored target ([IAuthSessionRepository.persistTarget]), under
/// the session generation the switch started under, so a sign-out during the switch leaves no target stored. A
/// refusal keeps the session, its target and its stored data: unlike a refused sign-in nothing is cleared, and a switch
/// is no sign-out, so it never reaches the identity provider and writes no warn line.
///
/// The generation read when the switch starts decides its outcome: once that session has ended, the gate's answer,
/// a success or a refusal alike, and a target that could not be stored are [SessionTargetSwitchAbandoned], so no answer
/// of an ended session reaches the next one.
class SwitchSessionTargetUseCase {
  const SwitchSessionTargetUseCase(this._studioIdentity, this._platformIdentity, this._sessionRepository);

  static final _log = AppLogger.getLogger('SwitchSessionTargetUseCase');

  final IStudioIdentityRepository _studioIdentity;

  /// Null in a build without a Platform target, whose profile sheet never offers the switch.
  final IPlatformIdentityRepository? _platformIdentity;
  final IAuthSessionRepository _sessionRepository;

  /// Throws [StateError] for [SessionTarget.platform] in a build without a Platform target.
  Future<SessionTargetSwitchResult> call(SessionTarget to) async {
    final platformIdentity = _platformIdentity;
    if (to == SessionTarget.platform && platformIdentity == null) {
      throw StateError('Platform is not configured in this build');
    }
    final generation = SessionGeneration.current;
    final SessionTargetSwitchResult switched;
    switch (to) {
      case SessionTarget.studio:
        switch (await _studioIdentity.fetch(probe: true)) {
          case Success(:final data):
            switched = SwitchedToStudio(data);
          case Failure(:final error):
            if (SessionGeneration.hasEnded(generation)) return _abandoned(to);
            return _refused(to, _studioSwitchRefusal(error));
        }
      case SessionTarget.platform:
        switch (await platformIdentity!.fetch()) {
          case Success(:final data):
            switched = SwitchedToPlatform(data);
          case Failure(:final error):
            if (SessionGeneration.hasEnded(generation)) return _abandoned(to);
            return _refused(to, platformGateRefusal(error));
        }
    }
    if (SessionGeneration.hasEnded(generation)) return _abandoned(to);
    if (await _sessionRepository.persistTarget(to, generation: generation) case Failure(:final error)) {
      if (SessionGeneration.hasEnded(generation)) return _abandoned(to);
      _log.error('The switch to {} could not store the target: {}', [to.name, error.runtimeType]);
      return const SessionTargetSwitchRefused(AppErrorCode.generic);
    }
    _log.info('The session switched to {}', [to.name]);
    return switched;
  }

  /// The code of a Studio gate failure: [AppErrorCode.studioUnreachable] when Studio does not answer, that is a 5xx
  /// without Studio's code, as the edge in front of a stopped Studio sends, a connection that failed or a timeout, and
  /// [studioGateRefusal] for any other failure. The login page shows its own notice for an unreachable Studio, so only
  /// the switch maps it here.
  static AppErrorCode _studioSwitchRefusal(AppError error) => switch (error) {
    ServerError(code: null) || NetworkError(code: null) || TimeoutError(code: null) => AppErrorCode.studioUnreachable,
    _ => studioGateRefusal(error),
  };

  /// A sign-out or an idle timeout during a switch is an expected path, so it is told at info.
  static SessionTargetSwitchAbandoned _abandoned(SessionTarget to) {
    _log.info('The session ended before the switch to {} finished, so the switch is dropped', [to.name]);
    return const SessionTargetSwitchAbandoned();
  }

  static SessionTargetSwitchRefused _refused(SessionTarget to, AppErrorCode errorCode) {
    _log.info('The {} gate refused the switch, so the session keeps its target: {}', [to.name, errorCode.key]);
    return SessionTargetSwitchRefused(errorCode);
  }
}
