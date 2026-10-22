import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/auth/domain/entities/auth_entity.dart';
import 'package:libredb_mobile/features/auth/domain/repositories/auth_repository.dart';

class VerifyOtpUseCase {
  const VerifyOtpUseCase(this._repository);

  final IAuthRepository _repository;

  Future<Result<AuthTokenEntity>> call(VerifyOtpEntity request) {
    return _repository.verifyOtp(request);
  }
}
