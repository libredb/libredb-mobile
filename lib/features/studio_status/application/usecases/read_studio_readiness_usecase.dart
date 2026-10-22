import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/studio_status/domain/entities/studio_readiness.dart';
import 'package:libredb_mobile/features/studio_status/domain/repositories/studio_status_repository.dart';

/// Studio's readiness, read to word a governance outage.
class ReadStudioReadinessUseCase {
  const ReadStudioReadinessUseCase(this._repository);

  final IStudioStatusRepository _repository;

  Future<Result<StudioReadiness>> call() => _repository.readiness();
}
