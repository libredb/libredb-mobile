import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/platform_grants/domain/repositories/platform_grant_repository.dart';

class RevokeGrantUseCase {
  const RevokeGrantUseCase(this._repository);

  final IPlatformGrantRepository _repository;

  Future<Result<void>> call(String connectionId, String grantId) => _repository.revoke(connectionId, grantId);
}
