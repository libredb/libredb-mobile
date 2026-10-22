import 'package:libredb_mobile/core/logging/app_logger.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/auth/data/models/studio_identity_model.dart';
import 'package:libredb_mobile/features/auth/domain/repositories/studio_identity_repository.dart';
import 'package:libredb_mobile/infrastructure/http/api_client.dart';
import 'package:libredb_mobile/infrastructure/studio/studio_errors.dart';
import 'package:libredb_mobile/shared/models/studio_identity.dart';

/// Studio's session endpoints. The paths are relative to `PROD_API_URL`, which ends in Studio's `/api`.
class StudioIdentityRepository implements IStudioIdentityRepository {
  StudioIdentityRepository(this._apiClient);

  final ApiClient _apiClient;

  static final _log = AppLogger.getLogger('StudioIdentityRepository');

  @override
  Future<Result<StudioIdentity>> fetch() async {
    try {
      final response = await _apiClient.get('/auth/me');
      final identity = StudioIdentityModel.fromJsonString(ApiClient.decodeUTF8(response.data!));
      switch (identity.role) {
        case StudioAdminRole() || StudioUserRole():
          break;
        case StudioUnknownRole(:final name):
          // The visible sign that the app is older than its server; the role gets the least the app grants.
          _log.warn('fetch: Studio names a role this app does not know: {}', [name]);
      }
      _log.debug('fetch: role {}, bearer {}', [identity.role.name, identity.viaBearer]);
      return Success(identity);
    } catch (e) {
      final error = studioError(e);
      _log.warn('fetch failed: {}', [error.code ?? error.runtimeType]);
      return Failure(error);
    }
  }

  @override
  Future<Result<void>> recordSignOut() async {
    try {
      // Sent with the client's Content-Type: application/json, which Studio requires of a POST without an Origin.
      final response = await _apiClient.post('/auth/logout', const <String, Object?>{});
      StudioIdentityModel.readSignOutAccepted(ApiClient.decodeUTF8(response.data!));
      return const Success(null);
    } catch (e) {
      final error = studioError(e);
      // Only the code or the type: the sign-out goes on without Studio's record, and the answer body is not logged.
      _log.debug('recordSignOut failed: {}', [error.code ?? error.runtimeType]);
      return Failure(error);
    }
  }
}
