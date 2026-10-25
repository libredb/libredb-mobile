import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/platform_connections/domain/repositories/platform_connection_repository.dart';
import 'package:libredb_mobile/shared/models/platform_connection.dart';

class ListPlatformConnectionsUseCase {
  const ListPlatformConnectionsUseCase(this._repository);

  final IPlatformConnectionRepository _repository;

  Future<Result<List<PlatformConnection>>> call() => _repository.list();
}
