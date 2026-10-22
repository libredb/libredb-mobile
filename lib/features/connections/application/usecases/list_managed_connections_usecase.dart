import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/shared/models/studio_connection.dart';
import 'package:libredb_mobile/features/connections/domain/repositories/connection_repository.dart';

class ListManagedConnectionsUseCase {
  const ListManagedConnectionsUseCase(this._repository);

  final IConnectionRepository _repository;

  Future<Result<List<StudioConnection>>> call() => _repository.listManaged();
}
