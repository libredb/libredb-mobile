import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/core/logging/app_logger.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/auth/application/usecases/gate_refusal.dart';
import 'package:libredb_mobile/features/auth/domain/entities/sso_sign_in_result.dart';
import 'package:libredb_mobile/features/auth/domain/repositories/auth_session_repository.dart';
import 'package:libredb_mobile/features/auth/domain/repositories/platform_identity_repository.dart';
import 'package:libredb_mobile/features/auth/domain/repositories/sso_auth_repository.dart';
import 'package:libredb_mobile/features/auth/domain/repositories/studio_identity_repository.dart';
import 'package:libredb_mobile/shared/models/session_target.dart';

/// Signs the user in through the identity provider for a session target, then asks that target's gate whether it
/// accepts the account.
///
/// The provider's tokens are stored first, with the target, so the gate's call goes out with them as the bearer. The
/// Studio gate is Studio's `GET /api/auth/me` and the Platform gate is Platform's `GET /api/v1/me`; only the 200 of
/// the target's own gate is a sign-in, and the other gate is never asked, so Platform's answer never decides a Studio
/// role and Studio's never decides a Platform right. On any gate failure the stored session is cleared and the
/// sign-in is refused, without a provider logout, so a retry through the other entry usually needs no password.
class SignInUseCase {
  const SignInUseCase(this._ssoRepository, this._studioIdentity, this._platformIdentity, this._sessionRepository);

  static final _log = AppLogger.getLogger('SignInUseCase');

  final ISsoAuthRepository _ssoRepository;
  final IStudioIdentityRepository _studioIdentity;

  /// Null in a build without a Platform target, whose login page never offers the Platform entry.
  final IPlatformIdentityRepository? _platformIdentity;
  final IAuthSessionRepository _sessionRepository;

  /// Throws [StateError] for [SessionTarget.platform] in a build without a Platform target.
  Future<SsoSignInResult> call(SessionTarget target) async {
    final platformIdentity = _platformIdentity;
    if (target == SessionTarget.platform && platformIdentity == null) {
      throw StateError('Platform is not configured in this build');
    }
    switch (await _ssoRepository.signIn(target: target)) {
      case SsoProviderCancelled():
        return const SsoSignInCancelled();
      case SsoProviderRejected(:final errorCode):
        return SsoSignInRejected(errorCode);
      case SsoProviderSignedIn():
        break;
    }
    final AppErrorCode errorCode;
    switch (target) {
      case SessionTarget.studio:
        switch (await _studioIdentity.fetch()) {
          case Success(:final data):
            return StudioSignInSucceeded(data);
          case Failure(:final error):
            errorCode = studioGateRefusal(error);
        }
      case SessionTarget.platform:
        switch (await platformIdentity!.fetch()) {
          case Success(:final data):
            return PlatformSignInSucceeded(data);
          case Failure(:final error):
            errorCode = platformGateRefusal(error);
        }
    }
    _log.warn('The {} gate refused the sign-in, so the stored session is cleared: {}', [target.name, errorCode.key]);
    if (await _sessionRepository.clear() case Failure(:final error)) {
      _log.error('The refused sign-in could not be cleared: {}', [error.runtimeType]);
    }
    return SsoSignInRejected(errorCode);
  }
}
