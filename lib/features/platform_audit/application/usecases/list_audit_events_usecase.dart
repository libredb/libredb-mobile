import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/platform_audit/domain/entities/audit_filter.dart';
import 'package:libredb_mobile/features/platform_audit/domain/entities/audit_page.dart';
import 'package:libredb_mobile/features/platform_audit/domain/repositories/platform_audit_repository.dart';

class ListAuditEventsUseCase {
  const ListAuditEventsUseCase(this._repository);

  final IPlatformAuditRepository _repository;

  Future<Result<AuditPage>> call({required AuditFilter filter, required int offset, int limit = 50}) =>
      _repository.list(filter: filter, offset: offset, limit: limit);
}
