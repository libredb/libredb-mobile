import 'package:libredb_mobile/core/logging/app_logger.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/object_browser/data/models/object_browser_json.dart';
import 'package:libredb_mobile/features/object_browser/domain/entities/database_object.dart';
import 'package:libredb_mobile/features/object_browser/domain/entities/key_scan_page.dart';
import 'package:libredb_mobile/features/object_browser/domain/entities/kind_count.dart';
import 'package:libredb_mobile/features/object_browser/domain/entities/object_container.dart';
import 'package:libredb_mobile/features/object_browser/domain/entities/object_detail.dart';
import 'package:libredb_mobile/features/object_browser/domain/entities/object_source.dart';
import 'package:libredb_mobile/features/object_browser/domain/repositories/object_browser_repository.dart';
import 'package:libredb_mobile/infrastructure/http/api_client.dart';
import 'package:libredb_mobile/infrastructure/studio/studio_errors.dart';

/// Studio's object routes, all `POST` with the connection named in the body. The paths are relative to
/// `PROD_API_URL`, which ends in Studio's `/api`. It keeps no answer, so every read, a refresh or not, is a request.
class ObjectBrowserRepository implements IObjectBrowserRepository {
  ObjectBrowserRepository(this._apiClient);

  final ApiClient _apiClient;

  static final _log = AppLogger.getLogger('ObjectBrowserRepository');

  @override
  Future<Result<List<ObjectContainer>>> containers(String connectionId, {List<String>? parent, bool refresh = false}) =>
      _post('containers', '/db/objects/containers', {
        'connectionId': connectionId,
        'parent': ?parent,
      }, ObjectBrowserJson.containers);

  @override
  Future<Result<Map<String, KindCount>>> counts(
    String connectionId, {
    required List<String> container,
    bool refresh = false,
  }) => _post('counts', '/db/objects/counts', {
    'connectionId': connectionId,
    'container': container,
  }, ObjectBrowserJson.counts);

  @override
  Future<Result<List<DatabaseObject>>> list(
    String connectionId, {
    required List<String> container,
    required String kind,
    bool refresh = false,
  }) => _post('list', '/db/objects/list', {
    'connectionId': connectionId,
    'container': container,
    'kind': kind,
  }, ObjectBrowserJson.objects);

  @override
  Future<Result<ObjectDetail>> describe(
    String connectionId, {
    required List<String> path,
    required String kind,
    bool refresh = false,
  }) => _post('describe', '/db/objects/describe', {
    'connectionId': connectionId,
    'path': path,
    'kind': kind,
  }, ObjectBrowserJson.detail);

  @override
  Future<Result<ObjectSource>> source(String connectionId, {required List<String> path, required String kind}) => _post(
    'source',
    '/db/objects/source',
    {'connectionId': connectionId, 'path': path, 'kind': kind},
    ObjectBrowserJson.source,
  );

  @override
  Future<Result<List<DatabaseObject>>> search(String connectionId, {required String term, List<String>? kinds}) =>
      _post('search', '/db/objects/search', {
        'connectionId': connectionId,
        'term': term,
        'kinds': ?kinds,
      }, ObjectBrowserJson.searchResults);

  @override
  Future<Result<KeyScanPage>> scanKeys(
    String connectionId, {
    String? cursor,
    String? pattern,
    int? count,
    int? database,
    bool level = false,
  }) => _post('scanKeys', '/db/keys/scan', {
    'connectionId': connectionId,
    'cursor': ?cursor,
    'pattern': ?pattern,
    'count': ?count,
    'database': ?database,
    if (level) 'level': true,
  }, ObjectBrowserJson.keyScanPage);

  Future<Result<T>> _post<T>(
    String operation,
    String path,
    Map<String, Object?> body,
    T Function(String body) read,
  ) async {
    try {
      final response = await _apiClient.post(path, body);
      return Success(read(ApiClient.decodeUTF8(response.data!)));
    } catch (e) {
      final error = studioError(e);
      _log.warn('{} failed: {}', [operation, error.code ?? error.runtimeType]);
      return Failure(error);
    }
  }
}
