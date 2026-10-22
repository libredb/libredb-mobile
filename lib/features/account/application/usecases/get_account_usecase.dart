import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/account/domain/repositories/account_repository.dart';
import 'package:libredb_mobile/shared/models/user_entity.dart';

class GetAccountUseCase {
  const GetAccountUseCase(this._repository);

  final IAccountRepository _repository;

  Future<Result<UserEntity>> call() {
    return _repository.getAccount();
  }
}
