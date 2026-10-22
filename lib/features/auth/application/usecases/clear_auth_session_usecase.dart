import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/auth/domain/repositories/auth_session_repository.dart';

/// Removes the stored session, as a logout does, without ending it anywhere else.
class ClearAuthSessionUseCase {
  const ClearAuthSessionUseCase(this._repository);

  final IAuthSessionRepository _repository;

  Future<Result<void>> call() => _repository.clear();
}
