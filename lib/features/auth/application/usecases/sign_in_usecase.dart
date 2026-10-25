import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/core/logging/app_logger.dart';
import 'package:libredb_mobile/core/result/result.dart';
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
            errorCode = _refusal(error);
        }
      case SessionTarget.platform:
        switch (await platformIdentity!.fetch()) {
          case Success(:final data):
            return PlatformSignInSucceeded(data);
          case Failure(:final error):
            errorCode = _platformRefusal(error);
        }
    }
    _log.warn('The {} gate refused the sign-in, so the stored session is cleared: {}', [target.name, errorCode.key]);
    if (await _sessionRepository.clear() case Failure(:final error)) {
      _log.error('The refused sign-in could not be cleared: {}', [error.runtimeType]);
    }
    return SsoSignInRejected(errorCode);
  }

  /// The code a sign-in Studio refused shows: Studio's account code of a 403 as it is,
  /// [AppErrorCode.studioAccountRefused] for any other [AuthError], which is a 401 that reached the caller, and the
  /// code `studioError` gave for anything else.
  static AppErrorCode _refusal(AppError error) {
    final code = AppErrorCode.fromKey(error.code);
    return switch (error) {
      AuthError() when code == AppErrorCode.studioAccountHasNoRole || code == AppErrorCode.studioAccountHasNoIdentity =>
        code!,
      AuthError() => AppErrorCode.studioAccountRefused,
      _ => code ?? AppErrorCode.generic,
    };
  }

  /// The code a sign-in Platform refused shows: a `platform.*` code that `platformError` gave as it is, whatever the
  /// error type, [AppErrorCode.platformAccountRefused] for any other [AuthError], which is a 401 that reached the
  /// caller (`BEARER_INVALID` again after the refresh, or one without Platform's envelope), and the code the shared
  /// transport mapping gave, or the generic one, for anything else.
  static AppErrorCode _platformRefusal(AppError error) {
    final code = AppErrorCode.fromKey(error.code);
    return switch (error) {
      _ when code != null && code.key.startsWith('platform.') => code,
      AuthError() => AppErrorCode.platformAccountRefused,
      _ => code ?? AppErrorCode.generic,
    };
  }
}
