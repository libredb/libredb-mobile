import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/access_requests/domain/entities/requestable_connection.dart';
import 'package:libredb_mobile/features/access_requests/domain/repositories/access_request_repository.dart';

/// The connections the signed-in Studio user may ask for.
class ListRequestableConnectionsUseCase {
  const ListRequestableConnectionsUseCase(this._repository);

  final IAccessRequestRepository _repository;

  Future<Result<List<RequestableConnection>>> call() => _repository.requestableConnections();
}
