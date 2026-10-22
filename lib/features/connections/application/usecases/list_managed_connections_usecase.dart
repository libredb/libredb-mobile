import 'package:flutter_bloc_advance/core/result/result.dart';
import 'package:flutter_bloc_advance/features/connections/domain/entities/studio_connection.dart';
import 'package:flutter_bloc_advance/features/connections/domain/repositories/connection_repository.dart';

class ListManagedConnectionsUseCase {
  const ListManagedConnectionsUseCase(this._repository);

  final IConnectionRepository _repository;

  Future<Result<List<StudioConnection>>> call() => _repository.listManaged();
}
