import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/connections/domain/entities/managed_connections.dart';
import 'package:libredb_mobile/features/connections/domain/repositories/connection_repository.dart';

class ListManagedConnectionsUseCase {
  const ListManagedConnectionsUseCase(this._repository);

  final IConnectionRepository _repository;

  Future<Result<ManagedConnections>> call() => _repository.listManaged();
}
