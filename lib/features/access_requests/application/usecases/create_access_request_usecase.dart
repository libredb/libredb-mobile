import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/access_requests/domain/entities/my_access_request.dart';
import 'package:libredb_mobile/features/access_requests/domain/repositories/access_request_repository.dart';

/// Asks for access to one connection. The reason is trimmed where the body is built, so the draft the user sees is
/// passed through as it is.
class CreateAccessRequestUseCase {
  const CreateAccessRequestUseCase(this._repository);

  final IAccessRequestRepository _repository;

  Future<Result<MyAccessRequest>> call({required String connectionId, required String level, required String reason}) =>
      _repository.create(connectionId: connectionId, level: level, reason: reason);
}
