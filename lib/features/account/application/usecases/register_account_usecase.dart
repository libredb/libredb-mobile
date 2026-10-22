import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/account/domain/repositories/account_repository.dart';
import 'package:libredb_mobile/shared/models/user_entity.dart';

class RegisterAccountUseCase {
  const RegisterAccountUseCase(this._repository);

  final IAccountRepository _repository;

  Future<Result<UserEntity>> call(UserEntity user) {
    return _repository.register(user);
  }
}
