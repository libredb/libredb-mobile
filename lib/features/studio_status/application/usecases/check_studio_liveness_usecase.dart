import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/studio_status/domain/repositories/studio_status_repository.dart';

/// Whether Studio answers its liveness check.
class CheckStudioLivenessUseCase {
  const CheckStudioLivenessUseCase(this._repository);

  final IStudioStatusRepository _repository;

  Future<Result<void>> call() => _repository.liveness();
}
