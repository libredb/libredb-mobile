import 'package:libredb_mobile/core/logging/app_logger.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/infrastructure/http/api_client.dart';
import 'package:libredb_mobile/infrastructure/studio/provider_meta_json.dart';
import 'package:libredb_mobile/infrastructure/studio/studio_errors.dart';
import 'package:libredb_mobile/shared/models/provider_meta.dart';
import 'package:libredb_mobile/shared/models/provider_meta_repository.dart';

/// `POST /db/provider-meta` with the connection named in the body, relative to `PROD_API_URL`, which ends in Studio's
/// `/api`.
class ProviderMetaRepository implements IProviderMetaRepository {
  ProviderMetaRepository(this._apiClient);

  final ApiClient _apiClient;

  static final _log = AppLogger.getLogger('ProviderMetaRepository');

  @override
  Future<Result<ProviderMeta>> providerMeta(String connectionId) async {
    try {
      final response = await _apiClient.post('/db/provider-meta', {'connectionId': connectionId});
      return Success(ProviderMetaJson.read(ApiClient.decodeUTF8(response.data!)));
    } catch (e) {
      final error = studioError(e);
      _log.warn('providerMeta failed: {}', [error.code ?? error.runtimeType]);
      return Failure(error);
    }
  }
}
