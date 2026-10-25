import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/platform_grants/domain/repositories/platform_grant_repository.dart';

class PutGrantUseCase {
  const PutGrantUseCase(this._repository);

  final IPlatformGrantRepository _repository;

  Future<Result<String>> call(
    String connectionId,
    String subject, {
    required String level,
    required DateTime? expiresAt,
  }) => _repository.put(connectionId, subject, level: level, expiresAt: expiresAt);
}
