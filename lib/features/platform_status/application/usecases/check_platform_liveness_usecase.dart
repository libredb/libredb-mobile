import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/platform_status/domain/repositories/platform_status_repository.dart';

/// Whether Platform answers its liveness check.
class CheckPlatformLivenessUseCase {
  const CheckPlatformLivenessUseCase(this._repository);

  final IPlatformStatusRepository _repository;

  Future<Result<void>> call() => _repository.liveness();
}
