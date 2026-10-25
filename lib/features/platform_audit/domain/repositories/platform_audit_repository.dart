import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/platform_audit/domain/entities/audit_filter.dart';
import 'package:libredb_mobile/features/platform_audit/domain/entities/audit_page.dart';

abstract class IPlatformAuditRepository {
  /// One page of governed query events, newest first (`GET /api/v1/audit`).
  Future<Result<AuditPage>> list({required AuditFilter filter, required int offset, int limit = 50});
}
