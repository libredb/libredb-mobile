@Tags(['widget'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/app/router/app_routes_constants.dart';
import 'package:libredb_mobile/features/platform_audit/navigation/audit_event_args.dart';

import '../audit_event_fixture.dart';
import '../audit_pages_harness.dart';

/// The audit list rows and the event's statement and error message are kept out of screenshots while on screen, and
/// nothing else of the audit pages holds a lease.
void main() {
  late AuditPagesHarness harness;

  setUp(() => harness = AuditPagesHarness());

  testWidgets('the list holds a lease while it shows rows, and the event page holds it while it covers the list', (
    tester,
  ) async {
    harness.answer([auditEvent('e1')]);
    await harness.pump(tester);
    expect(harness.protection.leases, 1);

    await tester.tap(find.byKey(const ValueKey('platform-audit-event-e1')));
    await tester.pumpAndSettle();
    expect(harness.protection.leases, 1, reason: 'the covered list released its lease, the event page took one');

    harness.router.pop();
    await tester.pumpAndSettle();
    expect(harness.protection.leases, 1, reason: 'the event page released its lease, the list took one again');
  });

  testWidgets('an empty list holds no lease', (tester) async {
    harness.answer(const []);
    await harness.pump(tester);

    expect(harness.protection.leases, 0);
  });

  testWidgets('the event page holds a lease while shown and releases it when it goes', (tester) async {
    harness.answer(const []);
    await harness.pump(
      tester,
      location: ApplicationRoutesConstants.platformAuditEvent,
      extra: AuditEventArgs(event: auditEvent('e1'), onFilterSelected: (_) {}),
    );
    expect(harness.protection.leases, 1);

    harness.router.go(ApplicationRoutesConstants.platformAudit);
    await tester.pumpAndSettle();

    expect(harness.protection.leases, 0);
  });

  testWidgets('the event page holds a lease on a small screen, with the statement below the fold', (tester) async {
    harness.answer(const []);
    await harness.pump(
      tester,
      size: const Size(360, 400),
      location: ApplicationRoutesConstants.platformAuditEvent,
      extra: AuditEventArgs(event: auditEvent('e1'), onFilterSelected: (_) {}),
    );

    expect(harness.protection.leases, 1);
  });

  testWidgets('a list covered by the event page holds no lease of its own', (tester) async {
    harness.answer(const []);
    await harness.pump(tester);
    expect(harness.protection.leases, 0);

    harness.router.push(
      ApplicationRoutesConstants.platformAuditEvent,
      extra: AuditEventArgs(event: auditEvent('e1'), onFilterSelected: (_) {}),
    );
    await tester.pumpAndSettle();

    expect(harness.protection.leases, 1);
  });
}
