import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/platform_audit/application/usecases/list_audit_events_usecase.dart';
import 'package:libredb_mobile/features/platform_audit/domain/entities/audit_filter.dart';
import 'package:libredb_mobile/features/platform_audit/domain/entities/audit_page.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mock_classes.dart';

void main() {
  late MockIPlatformAuditRepository repository;

  setUp(() {
    repository = MockIPlatformAuditRepository();
    registerFallbackValue(const AuditFilter());
  });

  test('passes the filter, the offset and the limit to the repository and returns its page', () async {
    const page = AuditPage(events: [], total: 0, offset: 40);
    final filter = AuditFilter(status: 'error');
    when(
      () => repository.list(
        filter: any(named: 'filter'),
        offset: any(named: 'offset'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((_) async => const Success(page));

    final result = await ListAuditEventsUseCase(repository)(filter: filter, offset: 40, limit: 20);

    expect(result, const Success(page));
    verify(() => repository.list(filter: filter, offset: 40, limit: 20)).called(1);
  });

  test('sends a limit of 50 by default and returns a failure as it is', () async {
    const failure = Failure<AuditPage>(AuthError('Platform answered 403', code: 'platform.plan_feature_required'));
    when(
      () => repository.list(
        filter: any(named: 'filter'),
        offset: any(named: 'offset'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((_) async => failure);

    final result = await ListAuditEventsUseCase(repository)(filter: const AuditFilter(), offset: 0);

    expect(result, failure);
    verify(() => repository.list(filter: const AuditFilter(), offset: 0, limit: 50)).called(1);
  });
}
