import 'package:libredb_mobile/core/logging/app_logger.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/auth/domain/repositories/auth_repository.dart';
import 'package:libredb_mobile/features/auth/domain/repositories/auth_session_repository.dart';

/// The app side of a logout: it clears the stored session. `SsoSignOutAuthRepository` wraps it to also end the session
/// at the identity provider.
class LoginRepository implements IAuthRepository {
  static final _log = AppLogger.getLogger("LoginRepository");

  LoginRepository({required this._sessionRepository});

  final IAuthSessionRepository _sessionRepository;

  @override
  Future<Result<void>> logout() async {
    _log.debug("BEGIN:logout repository start");
    // Delegate to IAuthSessionRepository.clear so there is exactly
    // one cleanup implementation (best-effort across both backends,
    // error aggregation, partial-logout failure semantics). Keeping
    // two parallel cleanups guaranteed they would drift the next time
    // either logout flow changed.
    final result = await _sessionRepository.clear();
    switch (result) {
      case Failure(:final error):
        _log.error("END:logout failed: {}", [error]);
      case Success():
        _log.debug("END:logout successful");
    }
    return result;
  }
}
