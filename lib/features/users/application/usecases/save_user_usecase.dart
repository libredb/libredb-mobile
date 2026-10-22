import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/users/domain/repositories/user_repository.dart';
import 'package:libredb_mobile/shared/models/user_entity.dart';

class SaveUserUseCase {
  const SaveUserUseCase(this._repository);

  final IUserRepository _repository;

  Future<Result<UserEntity>> call(UserEntity user) {
    if (user.id == null) {
      return _repository.create(user);
    }
    return _repository.update(user);
  }
}
