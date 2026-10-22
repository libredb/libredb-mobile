import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/account/data/models/change_password.dart';
import 'package:libredb_mobile/shared/models/user_entity.dart';

abstract class IAccountRepository {
  Future<Result<UserEntity>> register(UserEntity newUser);

  Future<Result<void>> changePassword(PasswordChangeDTO passwordChangeDTO);

  Future<Result<void>> resetPassword(String mailAddress);

  Future<Result<UserEntity>> getAccount();

  Future<Result<UserEntity>> update(UserEntity user);
}
