import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/account/domain/repositories/account_repository.dart';
import 'package:libredb_mobile/shared/models/user_entity.dart';

class UpdateAccountUseCase {
  const UpdateAccountUseCase(this._repository);

  final IAccountRepository _repository;

  Future<Result<UserEntity>> call(UserEntity user) {
    return _repository.update(user);
  }
}
