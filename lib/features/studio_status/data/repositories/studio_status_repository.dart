import 'package:libredb_mobile/core/logging/app_logger.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/studio_status/data/models/studio_status_json.dart';
import 'package:libredb_mobile/features/studio_status/domain/entities/studio_readiness.dart';
import 'package:libredb_mobile/features/studio_status/domain/repositories/studio_status_repository.dart';
import 'package:libredb_mobile/infrastructure/http/api_client.dart';
import 'package:libredb_mobile/infrastructure/studio/studio_errors.dart';
import 'package:libredb_mobile/infrastructure/studio/studio_timeouts.dart';

/// Studio's liveness and readiness endpoints. The paths are relative to `PROD_API_URL`, which ends in Studio's `/api`.
class StudioStatusRepository implements IStudioStatusRepository {
  StudioStatusRepository(this._apiClient);

  final ApiClient _apiClient;

  static final _log = AppLogger.getLogger('StudioStatusRepository');

  @override
  Future<Result<void>> liveness() async {
    try {
      final response = await _apiClient.get('/health', timeout: studioProbeTimeout);
      StudioStatusJson.liveness(ApiClient.decodeUTF8(response.data!));
      _log.debug('liveness: Studio answers');
      return const Success(null);
    } catch (e) {
      final error = studioError(e);
      _log.warn('liveness failed: {}', [error.code ?? error.runtimeType]);
      return Failure(error);
    }
  }

  /// Studio answers `loading`, `misconfigured` and `incompatible` with 503, which is read as an answer.
  @override
  Future<Result<StudioReadiness>> readiness() async {
    try {
      final response = await _apiClient.get('/ready', timeout: studioProbeTimeout, acceptedStatuses: const {503});
      final readiness = StudioStatusJson.readiness(ApiClient.decodeUTF8(response.data!));
      _log.debug('readiness: {}', [readiness.runtimeType]);
      return Success(readiness);
    } catch (e) {
      final error = studioError(e);
      _log.warn('readiness failed: {}', [error.code ?? error.runtimeType]);
      return Failure(error);
    }
  }
}
