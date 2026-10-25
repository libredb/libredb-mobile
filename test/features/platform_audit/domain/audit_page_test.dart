import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/features/platform_audit/domain/entities/audit_event.dart';
import 'package:libredb_mobile/features/platform_audit/domain/entities/audit_page.dart';

AuditEvent _event(String id) => AuditEvent(
  eventId: id,
  startedAt: DateTime.utc(2026, 10, 25, 9),
  finishedAt: DateTime.utc(2026, 10, 25, 9, 0, 1),
  subject: 'kc-1',
  username: null,
  sessionRole: 'user',
  connectionId: 'c1',
  connectionKnown: true,
  connectionName: 'Sales',
  engine: 'postgres',
  accessLevel: 'read',
  source: 'studio',
  statementType: 'SELECT',
  explain: null,
  statementCapture: 'redacted',
  statement: 'SELECT ?',
  statementTruncated: false,
  rowCount: 1,
  durationMs: 4,
  status: 'success',
  errorCode: null,
  errorMessage: null,
  transactionOutcome: null,
);

void main() {
  test('hasMore is true while offset plus the events on the page is below total', () {
    expect(AuditPage(events: [_event('1'), _event('2')], total: 5, offset: 0).hasMore, isTrue);
    expect(AuditPage(events: [_event('3'), _event('4')], total: 5, offset: 2).hasMore, isTrue);
  });

  test('hasMore is false on the last page', () {
    expect(AuditPage(events: [_event('5')], total: 5, offset: 4).hasMore, isFalse);
    expect(AuditPage(events: [_event('1'), _event('2')], total: 2, offset: 0).hasMore, isFalse);
  });

  test('hasMore is false for an empty page, whatever total says', () {
    expect(const AuditPage(events: [], total: 0, offset: 0).hasMore, isFalse);
    expect(const AuditPage(events: [], total: 9, offset: 50).hasMore, isFalse);
  });

  test('toString prints the counts only', () {
    expect('${AuditPage(events: [_event('1')], total: 5, offset: 0)}', 'AuditPage(events: 1, total: 5, offset: 0)');
  });
}
