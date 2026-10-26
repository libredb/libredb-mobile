import 'package:libredb_mobile/core/logging/app_logger.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/auth/data/models/platform_identity_model.dart';
import 'package:libredb_mobile/features/auth/domain/repositories/platform_identity_repository.dart';
import 'package:libredb_mobile/infrastructure/platform/platform_api_client.dart';
import 'package:libredb_mobile/infrastructure/platform/platform_errors.dart';
import 'package:libredb_mobile/shared/models/platform_identity.dart';

/// LibreDB Platform's identity endpoint. The path is relative to `PLATFORM_API_URL`, which ends in Platform's `/api`.
class PlatformIdentityRepository implements IPlatformIdentityRepository {
  PlatformIdentityRepository(this._apiClient);

  final PlatformApiClient _apiClient;

  static final _log = AppLogger.getLogger('PlatformIdentityRepository');

  @override
  Future<Result<PlatformIdentity>> fetch({bool probe = false}) async {
    try {
      final response = await _apiClient.get('/v1/me', bypassResilience: probe);
      final identity = PlatformIdentityModel.fromJsonString(response.data!);
      // Only the roles: the e-mail and the name stay out of the log.
      _log.debug('fetch: roles {}', [identity.roles]);
      return Success(identity);
    } catch (e) {
      final error = platformError(e);
      _log.warn('fetch failed: {}', [error.code ?? error.runtimeType]);
      return Failure(error);
    }
  }
}
