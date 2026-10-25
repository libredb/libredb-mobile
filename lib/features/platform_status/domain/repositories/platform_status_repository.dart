import 'package:libredb_mobile/core/result/result.dart';

/// Whether LibreDB Platform answers. The endpoint is public: it needs no session and no bearer.
abstract class IPlatformStatusRepository {
  /// Platform's liveness, `GET /api/health/live`. A failure means that Platform cannot be reached as Platform: no
  /// connection, a timeout, an untrusted certificate, or an answer that is not Platform's. It never says anything
  /// about the session.
  Future<Result<void>> liveness();
}
