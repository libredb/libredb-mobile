import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/auth/domain/entities/auth_entity.dart';

abstract class IAuthRepository {
  Future<Result<AuthTokenEntity>> authenticate(AuthCredentialsEntity userJWT);

  Future<Result<void>> logout();

  Future<Result<void>> sendOtp(SendOtpEntity request);

  Future<Result<AuthTokenEntity>> verifyOtp(VerifyOtpEntity request);
}
