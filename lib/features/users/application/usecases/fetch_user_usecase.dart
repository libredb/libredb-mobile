import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/users/domain/repositories/user_repository.dart';
import 'package:libredb_mobile/shared/models/user_entity.dart';

class FetchUserUseCase {
  const FetchUserUseCase(this._repository);

  final IUserRepository _repository;

  Future<Result<UserEntity>> call(String id) {
    return _repository.retrieve(id);
  }
}
