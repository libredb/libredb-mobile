import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/auth/domain/entities/auth_entity.dart';
import 'package:libredb_mobile/features/auth/domain/repositories/auth_repository.dart';

class SendOtpUseCase {
  const SendOtpUseCase(this._repository);

  final IAuthRepository _repository;

  Future<Result<void>> call(SendOtpEntity request) {
    return _repository.sendOtp(request);
  }
}
