import 'package:libredb_mobile/core/logging/app_logger.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/platform_grants/data/models/directory_page_json.dart';
import 'package:libredb_mobile/features/platform_grants/domain/entities/directory_page.dart';
import 'package:libredb_mobile/features/platform_grants/domain/repositories/platform_directory_repository.dart';
import 'package:libredb_mobile/infrastructure/platform/platform_api_client.dart';
import 'package:libredb_mobile/infrastructure/platform/platform_errors.dart';

/// LibreDB Platform's directory, the Keycloak users a grant can name. The path is relative to `PLATFORM_API_URL`,
/// which ends in Platform's `/api`.
///
/// Each search costs Platform up to 22 Keycloak Admin calls, so the caller sends few; the answer is never cached,
/// since every `/v1/` path is networkOnly.
class PlatformDirectoryRepository implements IPlatformDirectoryRepository {
  PlatformDirectoryRepository(this._apiClient);

  final PlatformApiClient _apiClient;

  static final _log = AppLogger.getLogger('PlatformDirectoryRepository');

  @override
  Future<Result<DirectoryPage>> search({required String query, required int page}) async {
    try {
      final q = query.trim();
      // Never a null map, so the mock asset of a local build is the same for every query.
      final response = await _apiClient.get(
        '/v1/directory/users',
        queryParams: {'page': page, if (q.isNotEmpty) 'q': q},
      );
      final answer = DirectoryPageJson.read(response.data!);
      // Only numbers: the query, a username or an e-mail address stays out of the log.
      _log.debug('search: page {}, {} users of {}', [answer.page, answer.users.length, answer.total]);
      return Success(answer);
    } catch (e) {
      final error = platformError(e);
      _log.warn('search failed: {}', [error.code ?? error.runtimeType]);
      return Failure(error);
    }
  }
}
