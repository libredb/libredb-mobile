import 'package:libredb_mobile/features/auth/domain/entities/sso_sign_in_result.dart';
import 'package:libredb_mobile/features/auth/domain/repositories/sso_auth_repository.dart';

class SignInWithSsoUseCase {
  const SignInWithSsoUseCase(this._repository);

  final ISsoAuthRepository _repository;

  Future<SsoSignInResult> call() => _repository.signIn();
}
