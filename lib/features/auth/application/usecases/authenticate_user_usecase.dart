import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/auth/domain/entities/auth_entity.dart';
import 'package:libredb_mobile/features/auth/domain/repositories/auth_repository.dart';

class AuthenticateUserUseCase {
  const AuthenticateUserUseCase(this._repository);

  final IAuthRepository _repository;

  Future<Result<AuthTokenEntity>> call(AuthCredentialsEntity credentials) {
    return _repository.authenticate(credentials);
  }
}
