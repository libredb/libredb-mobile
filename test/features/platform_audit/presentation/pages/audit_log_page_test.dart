@Tags(['widget'])
library;

import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/platform_audit/domain/entities/audit_filter.dart';
import 'package:libredb_mobile/features/platform_audit/domain/entities/audit_page.dart';
import 'package:libredb_mobile/features/platform_audit/presentation/pages/audit_event_page.dart';
import 'package:mocktail/mocktail.dart';

import '../../audit_event_fixture.dart';
import '../../audit_pages_harness.dart';

void main() {
  late AuditPagesHarness harness;

  setUp(() => harness = AuditPagesHarness());

  Finder row(String id) => find.byKey(ValueKey('platform-audit-event-$id'));
  Finder inRow(String id, Finder matching) => find.descendant(of: row(id), matching: matching);
  Finder chip(String name) => find.byKey(ValueKey('platform-audit-chip-$name'));

  Future<void> openSheet(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('platform-audit-filters')));
    await tester.pumpAndSettle();
  }

  Future<void> closeSheet(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('platform-audit-filter-done')));
    await tester.pumpAndSettle();
  }

  group('on a phone with a home indicator', () {
    testWidgets('the Done button of the filters sheet ends above the bottom inset', (tester) async {
      harness.answer([auditEvent('e1')]);
      await harness.pump(tester);
      // iPhone: 34 logical points of home indicator, at the 1.0 pixel ratio the harness sets.
      tester.view.viewPadding = const FakeViewPadding(bottom: 34);
      tester.view.padding = const FakeViewPadding(bottom: 34);
      addTearDown(tester.view.resetViewPadding);
      addTearDown(tester.view.resetPadding);

      await openSheet(tester);

      final done = tester.getBottomLeft(find.byKey(const ValueKey('platform-audit-filter-done'))).dy;
      expect(done, lessThanOrEqualTo(tester.view.physicalSize.height - 34));
    });
  });

  group('rows', () {
    testWidgets('a full capture shows the user, connection, type, status, duration, rows and the first line', (
      tester,
    ) async {
      harness.answer([auditEvent('e1')]);
      await harness.pump(tester);

      expect(inRow('e1', find.text('alice.reader')), findsOneWidget);
      expect(inRow('e1', find.text('Orders')), findsOneWidget);
      expect(inRow('e1', find.text('SELECT')), findsOneWidget);
      expect(inRow('e1', find.text('Success')), findsOneWidget);
      expect(inRow('e1', find.textContaining('44 ms')), findsOneWidget);
      expect(inRow('e1', find.textContaining('Rows: 1')), findsOneWidget);
      expect(inRow('e1', find.text('SELECT id FROM orders')), findsOneWidget);
      expect(find.textContaining('WHERE id = 1'), findsNothing);
    });

    testWidgets('a redacted capture shows the first line of what Platform recorded', (tester) async {
      harness.answer([auditEvent('e1', statementCapture: 'redacted', statement: 'UPDATE orders SET total = ?')]);
      await harness.pump(tester);

      expect(inRow('e1', find.text('UPDATE orders SET total = ?')), findsOneWidget);
    });

    testWidgets('no capture says the statement was not captured', (tester) async {
      harness.answer([auditEvent('e1', statementCapture: 'none', statement: null)]);
      await harness.pump(tester);

      expect(inRow('e1', find.text('Statement not captured')), findsOneWidget);
    });

    testWidgets('an unknown connection shows the app marker, not Platform label', (tester) async {
      harness.answer([auditEvent('e1', connectionKnown: false, connectionName: 'unknown connection')]);
      await harness.pump(tester);

      expect(inRow('e1', find.text('Unknown connection')), findsOneWidget);
      expect(find.text('unknown connection'), findsNothing);
    });

    testWidgets('an unknown status is shown as Platform sent it', (tester) async {
      harness.answer([auditEvent('e1', status: 'timed-out')]);
      await harness.pump(tester);

      expect(inRow('e1', find.text('timed-out')), findsOneWidget);
    });

    testWidgets('each known status has its label', (tester) async {
      harness.answer([
        auditEvent('e1', status: 'error'),
        auditEvent('e2', status: 'cancelled'),
        auditEvent('e3', status: 'refused'),
      ]);
      await harness.pump(tester);

      expect(inRow('e1', find.text('Error')), findsOneWidget);
      expect(inRow('e2', find.text('Cancelled')), findsOneWidget);
      expect(inRow('e3', find.text('Refused')), findsOneWidget);
    });

    testWidgets('a null username shows the start of the subject', (tester) async {
      harness.answer([auditEvent('e1', username: null)]);
      await harness.pump(tester);

      expect(inRow('e1', find.text('5f0c1a52')), findsOneWidget);
    });

    testWidgets('a null row count shows no rows', (tester) async {
      harness.answer([auditEvent('e1', rowCount: null)]);
      await harness.pump(tester);

      expect(inRow('e1', find.textContaining('Rows')), findsNothing);
    });

    testWidgets('a time within a day is relative, an older one a local date', (tester) async {
      final now = DateTime.utc(2026, 10, 25, 12);
      await withClock(Clock.fixed(now), () async {
        harness.answer([
          auditEvent('e1', startedAt: now.subtract(const Duration(seconds: 20))),
          auditEvent('e2', startedAt: now.subtract(const Duration(minutes: 5))),
          auditEvent('e3', startedAt: now.subtract(const Duration(hours: 3))),
          auditEvent('e4', startedAt: DateTime.utc(2026, 10, 20, 8)),
        ]);
        await harness.pump(tester);

        expect(inRow('e1', find.textContaining('Just now')), findsOneWidget);
        expect(inRow('e2', find.textContaining('5 min ago')), findsOneWidget);
        expect(inRow('e3', find.textContaining('3 h ago')), findsOneWidget);
        expect(inRow('e4', find.textContaining('Oct 20, 2026')), findsOneWidget);
      });
    });

    testWidgets('a tap on a row opens the event', (tester) async {
      harness.answer([auditEvent('e1')]);
      await harness.pump(tester);

      await tester.tap(row('e1'));
      await tester.pumpAndSettle();

      expect(find.byType(AuditEventPage), findsOneWidget);
    });
  });

  group('states', () {
    testWidgets('an empty log without filters says no governed query ran yet', (tester) async {
      harness.answer(const []);
      await harness.pump(tester);

      expect(find.text('No governed queries yet'), findsOneWidget);
      expect(find.text('Clear filters'), findsNothing);
    });

    testWidgets('an empty log with filters says nothing matches and clears them', (tester) async {
      harness.answer(const []);
      await harness.pump(tester);
      await openSheet(tester);
      await tester.tap(find.byKey(const ValueKey('platform-audit-status-error')));
      await tester.pumpAndSettle();
      await closeSheet(tester);

      expect(find.text('No event matches the filters'), findsOneWidget);
      harness.sentFilters();

      await tester.tap(find.text('Clear filters'));
      await tester.pumpAndSettle();

      expect(harness.sentFilters(), [const AuditFilter()]);
      expect(find.text('No governed queries yet'), findsOneWidget);
    });

    testWidgets('a failed first load shows the failure with a retry', (tester) async {
      harness.answerWith(
        (filter, offset) async => Failure(ServerError('x', code: AppErrorCode.platformInternalError.key)),
      );
      await harness.pump(tester);

      expect(find.text('Could not load the audit log'), findsOneWidget);
      harness.answer([auditEvent('e1')]);
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(row('e1'), findsOneWidget);
    });

    testWidgets('a first load that failed under the Platform unreachable page is asked again once uncovered', (
      tester,
    ) async {
      harness.answerWith((filter, offset) async => const Failure(NetworkError('Connection refused')));
      await harness.pump(tester, unreachable: true);
      expect(harness.sentFilters(), hasLength(1));
      harness.answer([auditEvent('e1')]);

      harness.platformUnreachable.value = false;
      await tester.pumpAndSettle();

      expect(harness.sentFilters(), hasLength(1));
      expect(row('e1'), findsOneWidget);
    });

    testWidgets('a loaded log asks nothing once the Platform unreachable page uncovers it', (tester) async {
      harness.answer([auditEvent('e1')]);
      await harness.pump(tester);
      harness.sentFilters();
      harness.platformUnreachable.value = true;
      await tester.pump();

      harness.platformUnreachable.value = false;
      await tester.pumpAndSettle();

      verifyNever(
        () => harness.repository.list(
          filter: any(named: 'filter'),
          offset: any(named: 'offset'),
          limit: any(named: 'limit'),
        ),
      );
      expect(row('e1'), findsOneWidget);
    });

    testWidgets('leaving the page while a pull to refresh waits for Platform throws nothing', (tester) async {
      harness.answer([auditEvent('e1')]);
      await harness.pump(tester);
      final pending = Completer<Result<AuditPage>>();
      harness.answerWith((filter, offset) => pending.future);

      await tester.fling(find.byType(ListView), const Offset(0, 400), 1000);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
      pending.complete(Success(AuditPage(events: [auditEvent('e1')], total: 1, offset: 0)));
      await tester.pump(const Duration(seconds: 5));
      // The closing bloc lets the pending request finish before its stream ends, outside the fake clock.
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
      await tester.pump(const Duration(seconds: 5));

      expect(tester.takeException(), isNull);
    });

    testWidgets('a failed refresh shows a banner over the kept list', (tester) async {
      harness.answer([auditEvent('e1')]);
      await harness.pump(tester);
      harness.answerWith((filter, offset) async => Failure(NetworkError('x', code: AppErrorCode.networkOffline.key)));

      await tester.fling(find.byType(ListView), const Offset(0, 400), 1000);
      await tester.pumpAndSettle();

      expect(find.text('Could not refresh the audit log'), findsOneWidget);
      expect(row('e1'), findsOneWidget);
    });

    testWidgets('a failed refresh of an empty log shows the banner too', (tester) async {
      harness.answer(const []);
      await harness.pump(tester);
      harness.answerWith((filter, offset) async => Failure(NetworkError('x', code: AppErrorCode.networkOffline.key)));

      await tester.fling(find.text('No governed queries yet'), const Offset(0, 400), 1000);
      await tester.pumpAndSettle();

      expect(find.text('Could not refresh the audit log'), findsOneWidget);
      expect(find.text('No governed queries yet'), findsOneWidget);
    });

    testWidgets('PLAN_FEATURE_REQUIRED shows the plan page, without a retry or filters', (tester) async {
      harness.answerWith(
        (filter, offset) async => Failure(AuthError('403', code: AppErrorCode.platformPlanFeatureRequired.key)),
      );
      await harness.pump(tester);

      expect(find.text("The audit log is not in this install's plan"), findsOneWidget);
      expect(find.text('Retry'), findsNothing);
      expect(find.byKey(const ValueKey('platform-audit-filters')), findsNothing);
      expect(find.text('Could not load the audit log'), findsNothing);
    });

    testWidgets('PERMISSION_DENIED shows the permission page, without filters', (tester) async {
      harness.answerWith(
        (filter, offset) async => Failure(AuthError('403', code: AppErrorCode.platformPermissionDenied.key)),
      );
      await harness.pump(tester);

      expect(find.text('Platform does not let this account read the audit log'), findsOneWidget);
      expect(find.byKey(const ValueKey('platform-audit-filters')), findsNothing);
      expect(find.text('Could not load the audit log'), findsNothing);
    });

    testWidgets('the refusal pages follow the app language', (tester) async {
      harness.answerWith(
        (filter, offset) async => Failure(AuthError('403', code: AppErrorCode.platformPlanFeatureRequired.key)),
      );
      await harness.pump(tester, locale: const Locale('tr'));

      expect(find.text('Denetim kaydı bu kurulumun planında yok'), findsOneWidget);
    });
  });

  group('Load more', () {
    testWidgets('shows while Platform holds more, appends the next page and never lists an event twice', (
      tester,
    ) async {
      harness.answerWith(
        (filter, offset) async => Success(
          offset == 0
              ? AuditPage(events: [auditEvent('e0'), auditEvent('e1')], total: 4, offset: 0)
              : AuditPage(events: [auditEvent('e1'), auditEvent('e2')], total: 4, offset: offset),
        ),
      );
      await harness.pump(tester);
      expect(find.text('Load more'), findsOneWidget);

      await tester.tap(find.text('Load more'));
      await tester.pumpAndSettle();

      expect(row('e0'), findsOneWidget);
      expect(row('e1'), findsOneWidget);
      expect(row('e2'), findsOneWidget);
      expect(find.text('Load more'), findsNothing, reason: 'offset 2 plus 2 rows reached the total of 4');
    });

    testWidgets('a failed Load more shows a banner over the kept list and Load more again', (tester) async {
      harness.answer([auditEvent('e0')], total: 5);
      await harness.pump(tester);
      harness.answerWith((filter, offset) async => Failure(NetworkError('x', code: AppErrorCode.networkOffline.key)));

      await tester.tap(find.text('Load more'));
      await tester.pumpAndSettle();

      expect(find.text('Could not load more events'), findsOneWidget);
      expect(row('e0'), findsOneWidget);
      expect(find.text('Load more'), findsOneWidget);
    });

    testWidgets('a running Load more shows progress in place of the button', (tester) async {
      harness.answer([auditEvent('e0')], total: 5);
      await harness.pump(tester);
      final page = Completer<Result<AuditPage>>();
      harness.answerWith((filter, offset) => page.future);

      await tester.tap(find.text('Load more'));
      await tester.pump();

      expect(find.text('Load more'), findsNothing);
      expect(find.byKey(const ValueKey('platform-audit-loading-more')), findsOneWidget);
      page.complete(Success(AuditPage(events: [auditEvent('e1')], total: 2, offset: 1)));
      await tester.pumpAndSettle();
    });
  });

  group('filter sheet and chips', () {
    testWidgets('status, statement type and source are sent as chosen, each shown as a chip', (tester) async {
      harness.answer([auditEvent('e1')]);
      await harness.pump(tester);
      harness.sentFilters();
      await openSheet(tester);

      await tester.tap(find.byKey(const ValueKey('platform-audit-status-error')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('platform-audit-type-DELETE')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('platform-audit-source-multi-query')));
      await tester.pumpAndSettle();
      await closeSheet(tester);

      expect(harness.sentFilters().last, AuditFilter(status: 'error', statementType: 'DELETE', source: 'multi-query'));
      expect(find.descendant(of: chip('status'), matching: find.text('Status: Error')), findsOneWidget);
      expect(find.descendant(of: chip('statementType'), matching: find.text('Type: DELETE')), findsOneWidget);
      expect(find.descendant(of: chip('source'), matching: find.text('Source: multi-query')), findsOneWidget);
    });

    testWidgets('Any unsets a choice', (tester) async {
      harness.answer([auditEvent('e1')]);
      await harness.pump(tester);
      await openSheet(tester);
      await tester.tap(find.byKey(const ValueKey('platform-audit-status-refused')));
      await tester.pumpAndSettle();
      harness.sentFilters();

      await tester.tap(find.byKey(const ValueKey('platform-audit-status-any')));
      await tester.pumpAndSettle();
      await closeSheet(tester);

      expect(harness.sentFilters(), [const AuditFilter()]);
      expect(chip('status'), findsNothing);
    });

    testWidgets('removing a chip unsets its filter', (tester) async {
      harness.answer([auditEvent('e1')]);
      await harness.pump(tester);
      await openSheet(tester);
      await tester.tap(find.byKey(const ValueKey('platform-audit-status-error')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('platform-audit-type-SELECT')));
      await tester.pumpAndSettle();
      await closeSheet(tester);
      harness.sentFilters();

      await tester.tap(find.descendant(of: chip('status'), matching: find.byIcon(Icons.close)));
      await tester.pumpAndSettle();

      expect(harness.sentFilters(), [AuditFilter(statementType: 'SELECT')]);
      expect(chip('status'), findsNothing);
      expect(chip('statementType'), findsOneWidget);
    });

    testWidgets('from and to are sent in UTC, from the start of the first day to the end of the last', (tester) async {
      await withClock(Clock.fixed(DateTime(2026, 10, 25, 12)), () async {
        harness.answer([auditEvent('e1')]);
        await harness.pump(tester);
        await openSheet(tester);

        await tester.tap(find.byKey(const ValueKey('platform-audit-from')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('12'));
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('platform-audit-to')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('20'));
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();
        await closeSheet(tester);

        final sent = harness.sentFilters().last;
        expect(sent.from, DateTime(2026, 10, 12).toUtc());
        expect(sent.to, DateTime(2026, 10, 20, 23, 59, 59, 999).toUtc());
        expect(sent.from!.isUtc && sent.to!.isUtc, isTrue);
        expect(find.descendant(of: chip('from'), matching: find.text('From Oct 12, 2026')), findsOneWidget);
        expect(find.descendant(of: chip('to'), matching: find.text('To Oct 20, 2026')), findsOneWidget);
      });
    });

    testWidgets('a date already set can be cleared in the sheet', (tester) async {
      await withClock(Clock.fixed(DateTime(2026, 10, 25, 12)), () async {
        harness.answer([auditEvent('e1')]);
        await harness.pump(tester);
        await openSheet(tester);
        await tester.tap(find.byKey(const ValueKey('platform-audit-from')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('12'));
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();
        harness.sentFilters();

        await tester.tap(find.byKey(const ValueKey('platform-audit-from-clear')));
        await tester.pumpAndSettle();

        expect(harness.sentFilters(), [const AuditFilter()]);
      });
    });

    testWidgets('the to picker offers no day before from', (tester) async {
      await withClock(Clock.fixed(DateTime(2026, 10, 25, 12)), () async {
        harness.answer([auditEvent('e1')]);
        await harness.pump(tester);
        await openSheet(tester);
        await tester.tap(find.byKey(const ValueKey('platform-audit-from')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('12'));
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('platform-audit-to')));
        await tester.pumpAndSettle();

        final picker = tester.widget<CalendarDatePicker>(find.byType(CalendarDatePicker));
        expect(picker.firstDate, DateTime(2026, 10, 12));
      });
    });

    testWidgets('the search text is sent after the typing pauses, and shown as a chip', (tester) async {
      harness.answer([auditEvent('e1')]);
      await harness.pump(tester);
      harness.sentFilters();
      await openSheet(tester);

      await tester.enterText(find.byKey(const ValueKey('platform-audit-search')), '  orders ');
      await tester.pump(const Duration(milliseconds: 399));
      expect(() => harness.sentFilters(), throwsA(isA<TestFailure>()));
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pumpAndSettle();
      await closeSheet(tester);

      expect(harness.sentFilters(), [AuditFilter(search: 'orders')]);
      expect(find.descendant(of: chip('search'), matching: find.text('Text: orders')), findsOneWidget);
    });

    testWidgets('the search field refuses text over 200 UTF-16 code units, emoji counted as two', (tester) async {
      harness.answer([auditEvent('e1')]);
      await harness.pump(tester);
      harness.sentFilters();
      await openSheet(tester);
      final field = find.byKey(const ValueKey('platform-audit-search'));
      final hundred = '😀' * 100;

      await tester.enterText(field, hundred);
      await tester.pump();
      expect(find.text('200/200'), findsOneWidget);

      await tester.enterText(field, '$hundred😀');
      await tester.pump();
      expect(tester.widget<TextField>(field).controller!.text, hundred);

      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      final sent = harness.sentFilters();
      expect(sent.single.search, hundred);
      expect(sent.single.search!.length, 200);
    });

    testWidgets('the sheet opens on the filters set', (tester) async {
      harness.answer([auditEvent('e1')]);
      await harness.pump(tester);
      await openSheet(tester);
      await tester.tap(find.byKey(const ValueKey('platform-audit-status-error')));
      await tester.enterText(find.byKey(const ValueKey('platform-audit-search')), 'orders');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      await closeSheet(tester);

      await openSheet(tester);

      expect(tester.widget<ChoiceChip>(find.byKey(const ValueKey('platform-audit-status-error'))).selected, isTrue);
      expect(tester.widget<TextField>(find.byKey(const ValueKey('platform-audit-search'))).controller!.text, 'orders');
    });
  });
}
