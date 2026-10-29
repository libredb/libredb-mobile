@Tags(['widget'])
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:libredb_mobile/app/router/app_routes_constants.dart';
import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/access_requests/domain/entities/my_access_request.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/shared/design_system/components/app_badge.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mock_classes.dart';
import '../support/access_request_fixtures.dart';
import '../support/access_requests_harness.dart';

Finder _row(String id) => find.byKey(ValueKey('access-request-row-$id'));

Finder _withdraw(String id) => find.byKey(ValueKey('access-request-withdraw-$id'));

AppBadgeVariant _badgeOf(WidgetTester tester, String id) =>
    tester.widget<AppBadge>(find.descendant(of: _row(id), matching: find.byType(AppBadge))).variant;

void main() {
  late MockIAccessRequestRepository repository;
  late S en;

  final pending = fixtureRequest('r1');
  final approved = fixtureRequest('r2', status: 'approved', connectionName: 'Billing reports');
  final refused = fixtureRequest(
    'r3',
    status: 'refused',
    level: 'write',
    connectionName: 'Support tickets',
    decisionReason: 'Loads go through the data team.',
  );
  final withdrawn = fixtureRequest('r4', status: 'withdrawn', connectionName: 'Archive snapshots');
  final strange = fixtureRequest('r5', status: 'archived', connectionName: 'Old stuff');

  setUpAll(() async => en = await loadEnglish());

  setUp(() => repository = MockIAccessRequestRepository());

  void answerMine(List<MyAccessRequest> requests) => when(repository.mine).thenAnswer((_) async => Success(requests));

  group('the rows', () {
    testWidgets('show the connection, the level, the sent time and a badge per status, in Platform order', (
      tester,
    ) async {
      answerMine([pending, approved, refused, withdrawn, strange]);

      await pumpAccessRequests(tester, repository);

      final sent = DateFormat.yMMMd('en').add_Hm().format(pending.createdAt.toLocal());
      expect(find.descendant(of: _row('r1'), matching: find.text('Analytics warehouse')), findsOneWidget);
      expect(find.descendant(of: _row('r1'), matching: find.text('Read')), findsOneWidget);
      expect(find.descendant(of: _row('r1'), matching: find.text('Sent $sent')), findsOneWidget);
      expect(find.descendant(of: _row('r3'), matching: find.text('Write')), findsOneWidget);
      expect(tester.getTopLeft(_row('r1')).dy, lessThan(tester.getTopLeft(_row('r2')).dy));
      expect(tester.getTopLeft(_row('r4')).dy, lessThan(tester.getTopLeft(_row('r5')).dy));
    });

    testWidgets('badge the four known statuses and show an unknown one as its raw value', (tester) async {
      answerMine([pending, approved, refused, withdrawn, strange]);

      await pumpAccessRequests(tester, repository);

      expect(find.descendant(of: _row('r1'), matching: find.text('Pending')), findsOneWidget);
      expect(_badgeOf(tester, 'r1'), AppBadgeVariant.warning);
      expect(find.descendant(of: _row('r2'), matching: find.text('Approved')), findsOneWidget);
      expect(_badgeOf(tester, 'r2'), AppBadgeVariant.success);
      expect(find.descendant(of: _row('r3'), matching: find.text('Refused')), findsOneWidget);
      expect(_badgeOf(tester, 'r3'), AppBadgeVariant.destructive);
      expect(find.descendant(of: _row('r4'), matching: find.text('Withdrawn')), findsOneWidget);
      expect(_badgeOf(tester, 'r4'), AppBadgeVariant.secondary);
      expect(find.descendant(of: _row('r5'), matching: find.text('archived')), findsOneWidget);
      expect(_badgeOf(tester, 'r5'), AppBadgeVariant.outline);
    });

    testWidgets('a refused row shows the administrator reason, or says there is none', (tester) async {
      answerMine([refused, fixtureRequest('r6', status: 'refused')]);

      await pumpAccessRequests(tester, repository);

      expect(find.text("Administrator's reason: Loads go through the data team."), findsOneWidget);
      expect(
        find.descendant(of: _row('r6'), matching: find.text(en.access_requests_refused_no_reason)),
        findsOneWidget,
      );
    });

    testWidgets('an approved row says the connection appears after a refresh', (tester) async {
      answerMine([approved, pending]);

      await pumpAccessRequests(tester, repository);

      expect(find.descendant(of: _row('r2'), matching: find.text(en.access_requests_approved_note)), findsOneWidget);
      expect(find.text(en.access_requests_approved_note), findsOneWidget);
    });

    testWidgets('only a pending row offers Withdraw', (tester) async {
      answerMine([pending, approved, refused, withdrawn, strange]);

      await pumpAccessRequests(tester, repository);

      expect(_withdraw('r1'), findsOneWidget);
      expect(find.text('Withdraw'), findsOneWidget);
    });
  });

  group('withdraw', () {
    testWidgets('asks first, and Cancel sends nothing', (tester) async {
      answerMine([pending]);
      await pumpAccessRequests(tester, repository);

      await tester.tap(_withdraw('r1'));
      await tester.pumpAndSettle();
      expect(
        find.text('Your request for read access to Analytics warehouse will be withdrawn. You can ask again later.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      verifyNever(() => repository.withdraw(any()));
      expect(_withdraw('r1'), findsOneWidget);
    });

    testWidgets('confirmed, sends once, updates the row in place and does not reload the list', (tester) async {
      answerMine([pending, approved]);
      when(() => repository.withdraw('r1')).thenAnswer((_) async => Success(fixtureRequest('r1', status: 'withdrawn')));
      await pumpAccessRequests(tester, repository);

      await tester.tap(_withdraw('r1'));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Withdraw')));
      await tester.pumpAndSettle();

      verify(() => repository.withdraw('r1')).called(1);
      verify(repository.mine).called(1);
      expect(find.descendant(of: _row('r1'), matching: find.text('Withdrawn')), findsOneWidget);
      expect(_withdraw('r1'), findsNothing);
      expect(find.text(en.access_requests_withdrawn_snackbar), findsOneWidget);
      expect(_row('r2'), findsOneWidget);
    });

    testWidgets('while one runs, every Withdraw is disabled', (tester) async {
      final other = fixtureRequest('r7', connectionName: 'Second one');
      answerMine([pending, other]);
      final slow = Completer<Result<MyAccessRequest>>();
      when(() => repository.withdraw('r1')).thenAnswer((_) => slow.future);
      await pumpAccessRequests(tester, repository);

      await tester.tap(_withdraw('r1'));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Withdraw')));
      await tester.pump();

      expect(tester.widget<TextButton>(_withdraw('r1')).onPressed, isNull);
      expect(tester.widget<TextButton>(_withdraw('r7')).onPressed, isNull);
      slow.complete(Success(fixtureRequest('r1', status: 'withdrawn')));
      await tester.pumpAndSettle();
      expect(tester.widget<TextButton>(_withdraw('r7')).onPressed, isNotNull);
    });

    testWidgets('a failure shows its text, keeps the row pending and is never sent again', (tester) async {
      answerMine([pending]);
      when(() => repository.withdraw('r1'))
          .thenAnswer((_) async => Failure(NetworkError('down', code: AppErrorCode.platformUnreachable.key)));
      await pumpAccessRequests(tester, repository);

      await tester.tap(_withdraw('r1'));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Withdraw')));
      await tester.pumpAndSettle();

      expect(find.text(en.error_platform_unreachable), findsOneWidget);
      expect(find.descendant(of: _row('r1'), matching: find.text('Pending')), findsOneWidget);
      verify(() => repository.withdraw('r1')).called(1);
    });

    testWidgets('a request already decided shows its text and reads the list again', (tester) async {
      answerMine([pending]);
      when(() => repository.withdraw('r1')).thenAnswer(
        (_) async => Failure(ValidationError('decided', code: AppErrorCode.platformAccessRequestDecided.key)),
      );
      await pumpAccessRequests(tester, repository);

      await tester.tap(_withdraw('r1'));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Withdraw')));
      await tester.pumpAndSettle();

      expect(find.text(en.error_platform_access_request_decided), findsOneWidget);
      verify(repository.mine).called(2);
      verify(() => repository.withdraw('r1')).called(1);
    });
  });

  group('the list as a whole', () {
    testWidgets('an empty list says so and offers Request access, which opens the form', (tester) async {
      answerMine([]);
      when(repository.requestableConnections).thenAnswer((_) async => Success([fixtureConnection('c1')]));
      final router = await pumpAccessRequests(tester, repository);

      expect(find.text(en.access_requests_empty_title), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Request access').first);
      await tester.pumpAndSettle();

      expect(router.state.uri.path, ApplicationRoutesConstants.accessRequestNew);
    });

    testWidgets('the floating button opens the form', (tester) async {
      answerMine([pending]);
      when(repository.requestableConnections).thenAnswer((_) async => Success([fixtureConnection('c1')]));
      final router = await pumpAccessRequests(tester, repository);

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      expect(router.state.uri.path, ApplicationRoutesConstants.accessRequestNew);
    });

    for (final (name, code, text) in [
      ('a 403 from Platform', AppErrorCode.platformAdminRoleRequired, (S s) => s.error_platform_admin_role_required),
      ('a 404 from a Platform without the routes', AppErrorCode.platformNotFound, (S s) => s.error_platform_not_found),
      ('an offline device', AppErrorCode.networkOffline, (S s) => s.error_network_offline),
      ('a Platform that does not answer', AppErrorCode.platformUnreachable, (S s) => s.error_platform_unreachable),
    ]) {
      testWidgets('$name shows its text and Retry, which asks again', (tester) async {
        when(repository.mine).thenAnswer((_) async => Failure(ServerError('refused', code: code.key)));
        await pumpAccessRequests(tester, repository);

        expect(find.text(text(en)), findsOneWidget);
        expect(find.text(en.access_requests_load_failed), findsOneWidget);
        answerMine([pending]);
        await tester.tap(find.text(en.retry));
        await tester.pumpAndSettle();

        expect(find.text('Analytics warehouse'), findsOneWidget);
        verify(repository.mine).called(2);
      });
    }

    testWidgets('a failed pull to refresh shows a snackbar and keeps the list', (tester) async {
      answerMine([pending]);
      await pumpAccessRequests(tester, repository);
      when(repository.mine)
          .thenAnswer((_) async => Failure(NetworkError('down', code: AppErrorCode.platformUnreachable.key)));

      await tester.fling(find.byKey(const ValueKey("access-requests-list")), const Offset(0, 900), 1000);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(find.text(en.error_platform_unreachable), findsOneWidget);
      expect(_row('r1'), findsOneWidget);
    });

    testWidgets('a pull to refresh shows what Platform now holds', (tester) async {
      answerMine([pending]);
      await pumpAccessRequests(tester, repository);
      answerMine([approved, pending]);

      await tester.fling(find.byKey(const ValueKey("access-requests-list")), const Offset(0, 900), 1000);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      verify(repository.mine).called(2);
      expect(_row('r2'), findsOneWidget);
    });

    testWidgets('speaks Turkish when the app does', (tester) async {
      answerMine([pending]);

      await pumpAccessRequests(tester, repository, locale: const Locale('tr'));

      expect(find.text('Beklemede'), findsOneWidget);
      expect(find.text('Geri çek'), findsOneWidget);
    });
  });
}
