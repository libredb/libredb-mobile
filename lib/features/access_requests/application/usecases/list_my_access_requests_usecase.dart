import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/access_requests/domain/entities/my_access_request.dart';
import 'package:libredb_mobile/features/access_requests/domain/repositories/access_request_repository.dart';

/// The signed-in Studio user's own access requests.
class ListMyAccessRequestsUseCase {
  const ListMyAccessRequestsUseCase(this._repository);

  final IAccessRequestRepository _repository;

  Future<Result<List<MyAccessRequest>>> call() => _repository.mine();
}
