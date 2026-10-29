import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/access_requests/domain/entities/my_access_request.dart';
import 'package:libredb_mobile/features/access_requests/domain/repositories/access_request_repository.dart';

/// Withdraws one open access request of the signed-in Studio user.
class WithdrawAccessRequestUseCase {
  const WithdrawAccessRequestUseCase(this._repository);

  final IAccessRequestRepository _repository;

  Future<Result<MyAccessRequest>> call(String requestId) => _repository.withdraw(requestId);
}
