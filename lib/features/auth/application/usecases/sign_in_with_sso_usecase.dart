import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/core/logging/app_logger.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/auth/domain/entities/sso_sign_in_result.dart';
import 'package:libredb_mobile/features/auth/domain/repositories/auth_session_repository.dart';
import 'package:libredb_mobile/features/auth/domain/repositories/sso_auth_repository.dart';
import 'package:libredb_mobile/features/auth/domain/repositories/studio_identity_repository.dart';

/// Signs the user in through the identity provider, then asks Studio whether it accepts the account.
///
/// The provider's tokens are stored first, so `GET /api/auth/me` goes out with them as the bearer. Only Studio's 200
/// is a sign-in; on any failure the stored session is cleared and the sign-in is refused, so an account Studio does
/// not accept never opens the app and loses the session on its first call. The role comes only from that answer.
class SignInWithSsoUseCase {
  const SignInWithSsoUseCase(this._ssoRepository, this._identityRepository, this._sessionRepository);

  static final _log = AppLogger.getLogger('SignInWithSsoUseCase');

  final ISsoAuthRepository _ssoRepository;
  final IStudioIdentityRepository _identityRepository;
  final IAuthSessionRepository _sessionRepository;

  Future<SsoSignInResult> call() async {
    switch (await _ssoRepository.signIn()) {
      case SsoProviderCancelled():
        return const SsoSignInCancelled();
      case SsoProviderRejected(:final errorCode):
        return SsoSignInRejected(errorCode);
      case SsoProviderSignedIn():
        break;
    }
    switch (await _identityRepository.fetch()) {
      case Success(:final data):
        return SsoSignInSucceeded(data);
      case Failure(:final error):
        final errorCode = _refusal(error);
        _log.warn('Studio did not accept the sign-in, so the stored session is cleared: {}', [errorCode.key]);
        if (await _sessionRepository.clear() case Failure(:final error)) {
          _log.error('The refused sign-in could not be cleared: {}', [error.runtimeType]);
        }
        return SsoSignInRejected(errorCode);
    }
  }

  /// The code the refused sign-in shows: Studio's account code of a 403 as it is, [AppErrorCode.studioAccountRefused]
  /// for any other [AuthError], which is a 401 that reached the caller, and the code `studioError` gave for anything
  /// else.
  static AppErrorCode _refusal(AppError error) {
    final code = AppErrorCode.fromKey(error.code);
    return switch (error) {
      AuthError() when code == AppErrorCode.studioAccountHasNoRole || code == AppErrorCode.studioAccountHasNoIdentity =>
        code!,
      AuthError() => AppErrorCode.studioAccountRefused,
      _ => code ?? AppErrorCode.generic,
    };
  }
}
