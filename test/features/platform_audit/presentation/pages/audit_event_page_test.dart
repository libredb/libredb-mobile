@Tags(['widget'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/app/router/app_routes_constants.dart';
import 'package:libredb_mobile/core/security/screen_capture_guard.dart';
import 'package:libredb_mobile/features/platform_audit/domain/entities/audit_event.dart';
import 'package:libredb_mobile/features/platform_audit/domain/entities/audit_filter.dart';
import 'package:libredb_mobile/features/platform_audit/navigation/audit_event_args.dart';
import 'package:libredb_mobile/features/platform_audit/presentation/pages/audit_event_page.dart';
import 'package:libredb_mobile/features/platform_audit/presentation/pages/audit_log_page.dart';

import '../../audit_event_fixture.dart';
import '../../audit_pages_harness.dart';

import 'package:libredb_mobile/shared/design_system/tokens/app_typography.dart';

void main() {
  late AuditPagesHarness harness;

  setUp(() => harness = AuditPagesHarness());

  Future<void> openOn(WidgetTester tester, AuditEvent event) => harness.pump(
    tester,
    location: ApplicationRoutesConstants.platformAuditEvent,
    extra: AuditEventArgs(event: event, onFilterSelected: (_) {}),
  );

  Finder field(String key) => find.byKey(ValueKey('platform-audit-field-$key'));
  Finder valueOf(String key, String text) => find.descendant(of: field(key), matching: find.text(text));

  testWidgets('lists every field of the event', (tester) async {
    await openOn(
      tester,
      auditEvent(
        'e9',
        explain: 'analyze',
        status: 'error',
        errorCode: '42P01',
        errorMessage: 'relation "orderz" does not exist',
        transactionOutcome: 'rolled-back',
        statementCapture: 'full',
      ),
    );

    expect(valueOf('eventId', 'e9'), findsOneWidget);
    expect(valueOf('started', 'Oct 25, 2026'), findsNothing, reason: 'times show with the hour');
    expect(find.descendant(of: field('started'), matching: find.textContaining('Oct 25, 2026')), findsOneWidget);
    expect(find.descendant(of: field('finished'), matching: find.textContaining('Oct 25, 2026')), findsOneWidget);
    expect(valueOf('user', 'alice.reader'), findsOneWidget);
    expect(valueOf('subject', '5f0c1a52-1d2e-4c1b-9a51-000000000001'), findsOneWidget);
    expect(valueOf('sessionRole', 'user'), findsOneWidget);
    expect(valueOf('connection', 'Orders'), findsOneWidget);
    expect(valueOf('connectionId', 'cm0conn0000000000000000001'), findsOneWidget);
    expect(valueOf('engine', 'postgres'), findsOneWidget);
    expect(valueOf('accessLevel', 'read'), findsOneWidget);
    expect(valueOf('source', 'editor'), findsOneWidget);
    expect(valueOf('statementType', 'SELECT'), findsOneWidget);
    expect(valueOf('explain', 'analyze'), findsOneWidget);
    expect(valueOf('capture', 'Full'), findsOneWidget);
    expect(valueOf('rows', '1'), findsOneWidget);
    expect(valueOf('duration', '44 ms'), findsOneWidget);
    expect(valueOf('status', 'Error'), findsOneWidget);
    expect(valueOf('errorCode', '42P01'), findsOneWidget);
    expect(valueOf('errorMessage', 'relation "orderz" does not exist'), findsOneWidget);
    expect(valueOf('transaction', 'rolled-back'), findsOneWidget);
    expect(
      find.descendant(of: field('statement'), matching: find.byType(SelectableText)),
      findsOneWidget,
      reason: 'the statement is selectable',
    );
    final statement = tester.widget<SelectableText>(
      find.descendant(of: field('statement'), matching: find.byType(SelectableText)),
    );
    expect(statement.data, 'SELECT id FROM orders\nWHERE id = 1');
    expect(statement.style?.fontFamily, AppTypography.mono);
  });

  testWidgets('a null field shows as not recorded', (tester) async {
    await openOn(
      tester,
      auditEvent(
        'e9',
        username: null,
        sessionRole: null,
        engine: null,
        accessLevel: null,
        rowCount: null,
        transactionOutcome: null,
        errorCode: null,
        errorMessage: null,
        connectionKnown: null,
      ),
    );

    for (final key in [
      'user',
      'sessionRole',
      'engine',
      'accessLevel',
      'explain',
      'rows',
      'errorCode',
      'errorMessage',
      'transaction',
    ]) {
      expect(valueOf(key, 'Not recorded'), findsOneWidget, reason: key);
    }
  });

  testWidgets('a truncated statement says Studio cut it', (tester) async {
    await openOn(tester, auditEvent('e9', statementTruncated: true));

    expect(find.text('Truncated by Studio'), findsOneWidget);
  });

  testWidgets('a redacted statement says the capture setting redacted it', (tester) async {
    await openOn(tester, auditEvent('e9', statementCapture: 'redacted', statement: 'SELECT ? FROM orders'));

    expect(find.text("Redacted by the connection's capture setting"), findsOneWidget);
    expect(find.text('SELECT ? FROM orders'), findsOneWidget);
  });

  testWidgets('no capture says not captured and shows no statement', (tester) async {
    await openOn(tester, auditEvent('e9', statementCapture: 'none', statement: null));

    expect(find.descendant(of: field('statement'), matching: find.text('Not captured')), findsOneWidget);
    expect(find.byType(SelectableText), findsNothing);
  });

  testWidgets('an unknown connection shows the app marker', (tester) async {
    await openOn(tester, auditEvent('e9', connectionKnown: false, connectionName: 'unknown connection'));

    expect(valueOf('connection', 'Unknown connection'), findsOneWidget);
  });

  testWidgets('the statement and the error message are inside screen capture protection', (tester) async {
    await openOn(tester, auditEvent('e9', errorMessage: 'boom'));

    expect(find.ancestor(of: field('statement'), matching: find.byType(ScreenCaptureGuard)), findsOneWidget);
    expect(find.ancestor(of: field('errorMessage'), matching: find.byType(ScreenCaptureGuard)), findsOneWidget);
  });

  testWidgets('Only this user hands the subject to the list and pops', (tester) async {
    AuditFilter? selected;
    harness.answer([auditEvent('e1')]);
    await harness.pump(tester);
    harness.router.push(
      ApplicationRoutesConstants.platformAuditEvent,
      extra: AuditEventArgs(
        event: auditEvent('e1'),
        onFilterSelected: (update) => selected = update(AuditFilter(status: 'error')),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Only this user'));
    await tester.pumpAndSettle();

    expect(selected, AuditFilter(status: 'error', subject: '5f0c1a52-1d2e-4c1b-9a51-000000000001'));
    expect(find.byType(AuditEventPage), findsNothing);
    expect(find.byType(AuditLogPage), findsOneWidget);
  });

  testWidgets('Only this connection hands the connection id to the list and pops', (tester) async {
    AuditFilter? selected;
    harness.answer([auditEvent('e1')]);
    await harness.pump(tester);
    harness.router.push(
      ApplicationRoutesConstants.platformAuditEvent,
      extra: AuditEventArgs(
        event: auditEvent('e1'),
        onFilterSelected: (update) => selected = update(const AuditFilter()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Only this connection'));
    await tester.pumpAndSettle();

    expect(selected, AuditFilter(connectionId: 'cm0conn0000000000000000001'));
    expect(find.byType(AuditLogPage), findsOneWidget);
  });

  group('from the list', () {
    testWidgets('Only this user filters the list, which names the user in its chip', (tester) async {
      harness.answer([auditEvent('e1')]);
      await harness.pump(tester);
      await tester.tap(find.byKey(const ValueKey('platform-audit-event-e1')));
      await tester.pumpAndSettle();
      harness.sentFilters();

      await tester.tap(find.text('Only this user'));
      await tester.pumpAndSettle();

      expect(harness.sentFilters(), [AuditFilter(subject: '5f0c1a52-1d2e-4c1b-9a51-000000000001')]);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('platform-audit-chip-subject')),
          matching: find.text('User: alice.reader'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('Only this connection filters the list, which names the connection in its chip', (tester) async {
      harness.answer([auditEvent('e1')]);
      await harness.pump(tester);
      await tester.tap(find.byKey(const ValueKey('platform-audit-event-e1')));
      await tester.pumpAndSettle();
      harness.sentFilters();

      await tester.tap(find.text('Only this connection'));
      await tester.pumpAndSettle();

      expect(harness.sentFilters(), [AuditFilter(connectionId: 'cm0conn0000000000000000001')]);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('platform-audit-chip-connectionId')),
          matching: find.text('Connection: Orders'),
        ),
        findsOneWidget,
      );
    });
  });

  test('the text of the args names no subject, username, statement or error message', () {
    final args = AuditEventArgs(
      event: auditEvent('e1', errorMessage: 'secret error'),
      onFilterSelected: (_) {},
    );

    final text = args.toString();
    for (final value in ['5f0c1a52', 'alice.reader', 'SELECT id', 'secret error', 'Orders']) {
      expect(text, isNot(contains(value)), reason: value);
    }
  });
}
