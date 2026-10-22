import 'package:flutter_bloc_advance/core/logging/app_logger.dart';
import 'package:flutter_bloc_advance/core/result/result.dart';
import 'package:flutter_bloc_advance/features/auth/data/models/studio_identity_model.dart';
import 'package:flutter_bloc_advance/features/auth/domain/repositories/studio_identity_repository.dart';
import 'package:flutter_bloc_advance/infrastructure/http/api_client.dart';
import 'package:flutter_bloc_advance/infrastructure/studio/studio_errors.dart';
import 'package:flutter_bloc_advance/shared/models/studio_identity.dart';

/// Studio's session endpoint. The path is relative to `PROD_API_URL`, which ends in Studio's `/api`.
class StudioIdentityRepository implements IStudioIdentityRepository {
  StudioIdentityRepository(this._apiClient);

  final ApiClient _apiClient;

  static final _log = AppLogger.getLogger('StudioIdentityRepository');

  @override
  Future<Result<StudioIdentity>> fetch() async {
    try {
      final response = await _apiClient.get('/auth/me');
      final identity = StudioIdentityModel.fromJsonString(ApiClient.decodeUTF8(response.data!));
      _log.debug('fetch: role {}, bearer {}', [identity.role.name, identity.viaBearer]);
      return Success(identity);
    } catch (e) {
      final error = studioError(e);
      _log.warn('fetch failed: {}', [error.code ?? error.runtimeType]);
      return Failure(error);
    }
  }
}
