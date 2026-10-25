import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/platform_grants/domain/entities/directory_page.dart';

abstract class IPlatformDirectoryRepository {
  /// Page [page] (from 1) of the Keycloak users matching [query] anywhere in the username, name or e-mail address, or
  /// every user for an empty one (`GET /api/v1/directory/users`). The query is sent trimmed.
  Future<Result<DirectoryPage>> search({required String query, required int page});
}
