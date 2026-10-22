import 'package:libredb_mobile/features/auth/domain/repositories/sso_sign_out_repository.dart';

/// The logout the user starts in an `oidc` build, see [ISsoSignOutRepository.signOut].
class SsoSignOutUseCase {
  const SsoSignOutUseCase(this._repository);

  final ISsoSignOutRepository _repository;

  Future<SsoSignOut> call() => _repository.signOut();
}
