import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:libredb_mobile/core/logging/app_logger.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/access_requests/data/models/access_request_create_body.dart';
import 'package:libredb_mobile/features/access_requests/data/models/access_request_json.dart';
import 'package:libredb_mobile/features/access_requests/data/models/requestable_connections_json.dart';
import 'package:libredb_mobile/features/access_requests/domain/entities/my_access_request.dart';
import 'package:libredb_mobile/features/access_requests/domain/entities/requestable_connection.dart';
import 'package:libredb_mobile/features/access_requests/domain/repositories/access_request_repository.dart';
import 'package:libredb_mobile/infrastructure/platform/platform_api_client.dart';
import 'package:libredb_mobile/infrastructure/platform/platform_errors.dart';

/// LibreDB Platform's requester routes, the ones a Studio session may call. The paths are relative to
/// `PLATFORM_API_URL`, which ends in Platform's `/api`; the request id is one encoded path segment.
///
/// Nothing is cached, since every `/v1/` path is networkOnly, and neither the create nor the withdrawal is ever sent
/// twice: both are a `POST` without the client's `idempotent` opt-in.
///
/// The log carries counts, the operation, the mapped code and nothing else: no reason, decision reason, username,
/// e-mail address or connection name ever reaches a line.
class AccessRequestRepository implements IAccessRequestRepository {
  AccessRequestRepository(this._apiClient);

  final PlatformApiClient _apiClient;

  /// The body keys the verbose HTTP log and the dev console mask on these requests.
  static const _sensitiveKeys = {'reason'};

  static final _log = AppLogger.getLogger('AccessRequestRepository');

  @override
  Future<Result<List<RequestableConnection>>> requestableConnections() async {
    try {
      final response = await _apiClient.get('/v1/requester/connections');
      final connections = RequestableConnectionsJson.read(response.data!);
      // Only the count: a connection name stays out of the log.
      _log.debug('requestableConnections: {} connections', [connections.length]);
      return Success(connections);
    } catch (e) {
      return _failure('requestableConnections', e);
    }
  }

  @override
  Future<Result<List<MyAccessRequest>>> mine() async {
    try {
      final response = await _apiClient.get('/v1/requester/access-requests');
      final requests = AccessRequestJson.readList(response.data!);
      // Only the count: a reason, a decision reason and a connection name stay out of the log.
      _log.debug('mine: {} requests', [requests.length]);
      return Success(requests);
    } catch (e) {
      return _failure('mine', e);
    }
  }

  @override
  Future<Result<MyAccessRequest>> create({
    required String connectionId,
    required String level,
    required String reason,
  }) async {
    try {
      final response = await _apiClient.post(
        '/v1/requester/access-requests',
        AccessRequestCreateBody(connectionId: connectionId, level: level, reason: reason).toJson(),
        sensitiveKeys: _sensitiveKeys,
      );
      // Read whatever the 2xx status: Platform answers 201, and MockInterceptor answers 201 to every POST.
      final request = AccessRequestJson.readOne(response.data!);
      // Neither the reason nor the connection name; the level is the app's own vocabulary.
      _log.debug('create: asked for {}', [level]);
      return Success(request);
    } catch (e) {
      return _failure('create', e, map: platformAccessRequestWriteError);
    }
  }

  @override
  Future<Result<MyAccessRequest>> withdraw(String requestId) async {
    try {
      // The body is an empty object, not null: ApiClient serializes anything else than a Map, String or List by
      // calling toJson() on it, so a null body would throw before a request is sent.
      final response = await _apiClient.post(
        '/v1/requester/access-requests',
        const <String, Object?>{},
        pathParams: '${Uri.encodeComponent(requestId)}/withdraw',
        sensitiveKeys: _sensitiveKeys,
      );
      final request = AccessRequestJson.readOne(response.data!);
      _log.debug('withdraw: {}', [request.status.name]);
      return Success(request);
    } catch (e) {
      return _failure('withdraw', e);
    }
  }

  static Failure<T> _failure<T>(String operation, Object e, {AppError Function(Object) map = platformError}) {
    final error = map(e);
    _log.warn('{} failed: {}', [operation, error.code ?? error.runtimeType]);
    return Failure(error);
  }
}
