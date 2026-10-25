import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/platform_grants/domain/entities/platform_grant.dart';
import 'package:libredb_mobile/features/platform_grants/domain/repositories/platform_grant_repository.dart';

class ListConnectionGrantsUseCase {
  const ListConnectionGrantsUseCase(this._repository);

  final IPlatformGrantRepository _repository;

  Future<Result<List<PlatformGrant>>> call(String connectionId) => _repository.list(connectionId);
}
