import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/features/platform_audit/domain/entities/audit_event.dart';

void main() {
  final event = AuditEvent(
    eventId: '42',
    startedAt: DateTime.utc(2026, 10, 25, 9),
    finishedAt: DateTime.utc(2026, 10, 25, 9, 0, 1),
    subject: 'kc-subject-alice',
    username: 'alice.stone',
    sessionRole: 'user',
    connectionId: 'cm0connection000000000001',
    connectionKnown: true,
    connectionName: 'Payroll Archive',
    engine: 'postgres',
    accessLevel: 'write',
    source: 'studio',
    statementType: 'UPDATE',
    explain: null,
    statementCapture: 'full',
    statement: 'UPDATE salaries SET amount = 1',
    statementTruncated: true,
    rowCount: 3,
    durationMs: 12,
    status: 'error',
    errorCode: '42501',
    errorMessage: 'permission denied for table salaries',
    transactionOutcome: 'rolled_back',
  );

  test('toString prints the event id and the status only', () {
    expect('$event', 'AuditEvent(eventId: 42, status: error)');
  });

  test('toString never prints a statement, an error message, a subject, a username or a connection name', () {
    final text = '$event';

    for (final value in [
      'salaries',
      'permission denied',
      'kc-subject-alice',
      'alice.stone',
      'Payroll Archive',
      'UPDATE',
      'full',
    ]) {
      expect(text, isNot(contains(value)));
    }
  });

  test('compares by value', () {
    final copy = AuditEvent(
      eventId: '42',
      startedAt: DateTime.utc(2026, 10, 25, 9),
      finishedAt: DateTime.utc(2026, 10, 25, 9, 0, 1),
      subject: 'kc-subject-alice',
      username: 'alice.stone',
      sessionRole: 'user',
      connectionId: 'cm0connection000000000001',
      connectionKnown: true,
      connectionName: 'Payroll Archive',
      engine: 'postgres',
      accessLevel: 'write',
      source: 'studio',
      statementType: 'UPDATE',
      explain: null,
      statementCapture: 'full',
      statement: 'UPDATE salaries SET amount = 1',
      statementTruncated: true,
      rowCount: 3,
      durationMs: 12,
      status: 'error',
      errorCode: '42501',
      errorMessage: 'permission denied for table salaries',
      transactionOutcome: 'rolled_back',
    );

    expect(copy, event);
  });
}
