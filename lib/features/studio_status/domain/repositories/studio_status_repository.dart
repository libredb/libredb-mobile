import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/studio_status/domain/entities/studio_readiness.dart';

/// Whether Studio answers, and whether it can serve connections. Both endpoints are public: they need no session and
/// spend no rate-limit slot.
abstract class IStudioStatusRepository {
  /// Studio's liveness, `GET /api/health`. A failure means that Studio cannot be reached as Studio: no connection, a
  /// timeout, an untrusted certificate, or an answer that is not Studio's. It never says anything about the session.
  Future<Result<void>> liveness();

  /// Studio's readiness, `GET /api/ready`, with the 503 answers read as states rather than failures.
  Future<Result<StudioReadiness>> readiness();
}
