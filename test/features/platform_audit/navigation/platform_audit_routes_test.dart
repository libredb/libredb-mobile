@Tags(['widget'])
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/app/router/app_routes_constants.dart';
import 'package:libredb_mobile/features/platform_audit/navigation/platform_audit_routes.dart';
import 'package:libredb_mobile/features/platform_audit/presentation/pages/audit_event_page.dart';
import 'package:libredb_mobile/features/platform_audit/presentation/pages/audit_log_page.dart';

import '../audit_event_fixture.dart';
import '../audit_pages_harness.dart';

void main() {
  late AuditPagesHarness harness;

  setUp(() {
    harness = AuditPagesHarness()..answer([auditEvent('e1')]);
  });

  test('both routes are named, so analytics logs them by name and not by their location', () {
    expect(PlatformAuditFeatureRoutes.routes.map((route) => (route.name, route.path)), [
      ('platformAudit', ApplicationRoutesConstants.platformAudit),
      ('platformAuditEvent', ApplicationRoutesConstants.platformAuditEvent),
    ]);
  });

  test('the locations carry no value', () {
    expect(ApplicationRoutesConstants.platformAudit, '/platform/audit');
    expect(ApplicationRoutesConstants.platformAuditEvent, '/platform/audit/event');
  });

  testWidgets('the event location without extra opens the audit list', (tester) async {
    await harness.pump(tester, location: ApplicationRoutesConstants.platformAuditEvent);

    expect(find.byType(AuditEventPage), findsNothing);
    expect(find.byType(AuditLogPage), findsOneWidget);
    expect(harness.router.routerDelegate.currentConfiguration.uri.path, ApplicationRoutesConstants.platformAudit);
  });

  testWidgets('the event location with something else as extra opens the audit list', (tester) async {
    await harness.pump(tester, location: ApplicationRoutesConstants.platformAuditEvent, extra: 'e1');

    expect(find.byType(AuditLogPage), findsOneWidget);
  });

  testWidgets('a row opens the event above the list, which stays below it', (tester) async {
    await harness.pump(tester);

    await tester.tap(find.byKey(const ValueKey('platform-audit-event-e1')));
    await tester.pumpAndSettle();

    expect(find.byType(AuditEventPage), findsOneWidget);
    expect(harness.router.canPop(), isTrue);
    expect(harness.router.routerDelegate.currentConfiguration.last.matchedLocation, '/platform/audit/event');
  });
}
