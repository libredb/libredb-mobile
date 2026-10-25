import 'package:libredb_mobile/core/logging/app_logger.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/platform_audit/data/models/audit_page_json.dart';
import 'package:libredb_mobile/features/platform_audit/domain/entities/audit_filter.dart';
import 'package:libredb_mobile/features/platform_audit/domain/entities/audit_page.dart';
import 'package:libredb_mobile/features/platform_audit/domain/repositories/platform_audit_repository.dart';
import 'package:libredb_mobile/infrastructure/platform/platform_api_client.dart';
import 'package:libredb_mobile/infrastructure/platform/platform_errors.dart';

/// LibreDB Platform's audit log, the governed query events of the install. The path is relative to
/// `PLATFORM_API_URL`, which ends in Platform's `/api`.
///
/// The events are held in memory by the caller only: every `/v1/` path is networkOnly, so nothing is cached, and no
/// filter value, statement, subject or name reaches the log.
class PlatformAuditRepository implements IPlatformAuditRepository {
  PlatformAuditRepository(this._apiClient);

  final PlatformApiClient _apiClient;

  static final _log = AppLogger.getLogger('PlatformAuditRepository');

  @override
  Future<Result<AuditPage>> list({required AuditFilter filter, required int offset, int limit = 50}) async {
    assert(limit >= 1 && limit <= 200, 'Platform accepts a limit from 1 to 200');
    assert(offset >= 0, 'Platform accepts an offset of 0 or more');
    try {
      // Never a null map, so the mock asset of a local build is the same for every filter.
      final response = await _apiClient.get(
        '/v1/audit',
        queryParams: {
          'limit': limit,
          'offset': offset,
          'subject': ?filter.subject,
          'connectionId': ?filter.connectionId,
          'source': ?filter.source,
          'statementType': ?filter.statementType,
          'status': ?filter.status,
          if (filter.from case final from?) 'from': from.toUtc().toIso8601String(),
          if (filter.to case final to?) 'to': to.toUtc().toIso8601String(),
          'search': ?filter.search,
        },
      );
      final page = AuditPageJson.read(response.data!, offset: offset);
      // Only numbers and filter names: a filter value, a statement or a subject stays out of the log.
      _log.debug('list: {} events of {} from offset {}, filters {}', [
        page.events.length,
        page.total,
        offset,
        filter.setFilterNames,
      ]);
      return Success(page);
    } catch (e) {
      final error = platformError(e);
      _log.warn('list failed: {}', [error.code ?? error.runtimeType]);
      return Failure(error);
    }
  }
}
