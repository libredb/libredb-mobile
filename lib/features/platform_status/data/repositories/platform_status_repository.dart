import 'package:libredb_mobile/core/logging/app_logger.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/platform_status/data/models/platform_status_json.dart';
import 'package:libredb_mobile/features/platform_status/domain/repositories/platform_status_repository.dart';
import 'package:libredb_mobile/infrastructure/http/api_client.dart';
import 'package:libredb_mobile/infrastructure/platform/platform_api_client.dart';
import 'package:libredb_mobile/infrastructure/platform/platform_errors.dart';

/// Platform's liveness endpoint. The path is relative to `PLATFORM_API_URL`, which ends in Platform's `/api`; the
/// endpoint is outside `/api/v1`, public in both deployment modes, and answers without any I/O.
///
/// The probe is sent without a bearer (it is a public endpoint), never answered from the cache, and bypasses the
/// client's retries and circuit breaker: each check sends one request, so [probeTimeout] is the whole wait, and a Retry
/// reaches Platform as soon as it answers again.
class PlatformStatusRepository implements IPlatformStatusRepository {
  PlatformStatusRepository(this._apiClient);

  final PlatformApiClient _apiClient;

  /// How long one liveness check waits to connect and for the answer.
  static const probeTimeout = Duration(seconds: 10);

  static final _log = AppLogger.getLogger('PlatformStatusRepository');

  @override
  Future<Result<void>> liveness() async {
    try {
      final response = await _apiClient.get('/health/live', timeout: probeTimeout, bypassResilience: true);
      PlatformStatusJson.liveness(ApiClient.decodeUTF8(response.data!));
      _log.debug('liveness: Platform answers');
      return const Success(null);
    } catch (e) {
      final error = platformError(e);
      _log.warn('liveness failed: {}', [error.code ?? error.runtimeType]);
      return Failure(error);
    }
  }
}
