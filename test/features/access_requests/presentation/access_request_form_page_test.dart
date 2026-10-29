@Tags(['widget'])
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:libredb_mobile/app/router/app_routes_constants.dart';
import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/access_requests/domain/entities/my_access_request.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/shared/widgets/confirmation_dialog_widget.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mock_classes.dart';
import '../support/access_request_fixtures.dart';
import '../support/access_requests_harness.dart';

Finder _connection(String id) => find.byKey(ValueKey('access-request-connection-$id'));
final _level = find.byKey(const ValueKey('access-request-level'));
final _reason = find.byKey(const ValueKey('access-request-reason'));
final _send = find.byKey(const ValueKey('access-request-send'));
Finder _error(String field) => find.byKey(ValueKey('access-request-error-$field'));

void main() {
  late MockIAccessRequestRepository repository;
  late S en;

  final open = fixtureConnection('c1', name: 'Analytics warehouse');
  final readOnly = fixtureConnection('c2', name: 'Billing reports', write: false);
  final heldRead = fixtureConnection('c3', name: 'Held for reading', heldLevel: 'read');
  final heldWrite = fixtureConnection('c4', name: 'Held for writing', heldLevel: 'write');
  final pending = fixtureConnection('c5', name: 'Support tickets', pendingRequestId: 'r5');
  final created = fixtureRequest('r9');

  setUpAll(() async => en = await loadEnglish());

  setUp(() {
    repository = MockIAccessRequestRepository();
    when(repository.requestableConnections)
        .thenAnswer((_) async => Success([open, readOnly, heldRead, heldWrite, pending]));
    when(repository.mine).thenAnswer((_) async => Success([created]));
  });

  Future<GoRouter> pumpForm(WidgetTester tester, {Locale locale = const Locale('en')}) =>
      pumpAccessRequests(tester, repository, location: ApplicationRoutesConstants.accessRequestNew, locale: locale);

  void answerCreate(Result<MyAccessRequest> result) => when(
    () => repository.create(
      connectionId: any(named: 'connectionId'),
      level: any(named: 'level'),
      reason: any(named: 'reason'),
    ),
  ).thenAnswer((_) async => result);

  Future<void> fill(
    WidgetTester tester, {
    String connection = 'c1',
    String level = 'Read',
    String reason = 'Why',
  }) async {
    await tester.tap(_connection(connection));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: _level, matching: find.text(level)));
    await tester.pumpAndSettle();
    await tester.enterText(_reason, reason);
    await tester.pumpAndSettle();
  }

  Future<void> send(WidgetTester tester) async {
    await tester.ensureVisible(_send);
    await tester.tap(_send);
    await tester.pumpAndSettle();
  }

  VerificationResult verifyCreates() => verify(
    () => repository.create(
      connectionId: any(named: 'connectionId'),
      level: any(named: 'level'),
      reason: any(named: 'reason'),
    ),
  );

  group('the connections', () {
    testWidgets('are listed in Platform order, by name', (tester) async {
      await pumpForm(tester);

      expect(find.text('Analytics warehouse'), findsOneWidget);
      expect(find.text('Billing reports'), findsOneWidget);
      expect(tester.getTopLeft(_connection('c1')).dy, lessThan(tester.getTopLeft(_connection('c2')).dy));
    });

    testWidgets('one with a pending request is disabled and says why', (tester) async {
      await pumpForm(tester);

      expect(tester.widget<ListTile>(_connection('c5')).enabled, isFalse);
      expect(
        find.descendant(of: _connection('c5'), matching: find.text(en.access_requests_form_connection_pending)),
        findsOneWidget,
      );
    });

    testWidgets('one held at the highest level is disabled and says why', (tester) async {
      await pumpForm(tester);

      expect(tester.widget<ListTile>(_connection('c4')).enabled, isFalse);
      expect(
        find.descendant(of: _connection('c4'), matching: find.text(en.access_requests_form_connection_granted)),
        findsOneWidget,
      );
    });

    testWidgets('one held at read can still be asked for write', (tester) async {
      await pumpForm(tester);

      expect(tester.widget<ListTile>(_connection('c3')).enabled, isTrue);
    });

    testWidgets('a disabled one cannot be picked', (tester) async {
      await pumpForm(tester);

      await tester.tap(_connection('c5'));
      await tester.pumpAndSettle();

      expect(tester.widget<ListTile>(_connection('c5')).selected, isFalse);
    });

    testWidgets('none to ask for says so', (tester) async {
      when(repository.requestableConnections).thenAnswer((_) async => const Success([]));

      await pumpForm(tester);

      expect(find.text(en.access_requests_form_no_connections), findsOneWidget);
    });

    testWidgets('a failed load shows its text and Retry loads again', (tester) async {
      when(repository.requestableConnections)
          .thenAnswer((_) async => Failure(NetworkError('off', code: AppErrorCode.networkOffline.key)));
      await pumpForm(tester);

      expect(find.text(en.error_network_offline), findsOneWidget);
      when(repository.requestableConnections).thenAnswer((_) async => Success([open]));
      await tester.tap(find.text(en.retry));
      await tester.pumpAndSettle();

      expect(_connection('c1'), findsOneWidget);
      verify(repository.requestableConnections).called(2);
    });
  });

  group('the level', () {
    SegmentedButton<String> levelButton(WidgetTester tester) => tester.widget<SegmentedButton<String>>(_level);

    testWidgets('write is disabled for a connection without a write credential, with the reason', (tester) async {
      await pumpForm(tester);

      await tester.tap(_connection('c2'));
      await tester.pumpAndSettle();

      expect(levelButton(tester).segments.firstWhere((s) => s.value == 'write').enabled, isFalse);
      expect(levelButton(tester).segments.firstWhere((s) => s.value == 'read').enabled, isTrue);
      expect(find.text(en.access_requests_form_level_write_unavailable), findsOneWidget);
    });

    testWidgets('read is disabled for a connection already held at read, with the reason', (tester) async {
      await pumpForm(tester);

      await tester.tap(_connection('c3'));
      await tester.pumpAndSettle();

      expect(levelButton(tester).segments.firstWhere((s) => s.value == 'read').enabled, isFalse);
      expect(levelButton(tester).segments.firstWhere((s) => s.value == 'write').enabled, isTrue);
      expect(find.text(en.access_requests_form_level_read_held), findsOneWidget);
    });
  });

  group('the reason', () {
    testWidgets('counts to 500 characters', (tester) async {
      await pumpForm(tester);

      expect(find.text('0/500'), findsOneWidget);
      await tester.enterText(_reason, 'hello');
      await tester.pumpAndSettle();

      expect(find.text('5/500'), findsOneWidget);
      expect(tester.widget<TextField>(_reason).maxLength, 500);
    });
  });

  group('send', () {
    testWidgets('an empty draft sends nothing and names every missing field', (tester) async {
      await pumpForm(tester);

      await send(tester);

      expect(find.text(en.access_requests_form_connection_required), findsOneWidget);
      expect(find.text(en.access_requests_form_level_required), findsOneWidget);
      expect(find.text(en.access_requests_form_reason_invalid), findsOneWidget);
      verifyNever(
        () => repository.create(
          connectionId: any(named: 'connectionId'),
          level: any(named: 'level'),
          reason: any(named: 'reason'),
        ),
      );
    });

    testWidgets('a reason of blanks counts as empty', (tester) async {
      await pumpForm(tester);
      await fill(tester, reason: '    ');

      await send(tester);

      expect(find.text(en.access_requests_form_reason_invalid), findsOneWidget);
      verifyNever(
        () => repository.create(
          connectionId: any(named: 'connectionId'),
          level: any(named: 'level'),
          reason: any(named: 'reason'),
        ),
      );
    });

    testWidgets('sends the connection, the level and the reason, closes to My requests and says it was sent', (
      tester,
    ) async {
      answerCreate(Success(created));
      final router = await pumpForm(tester);
      await fill(tester, reason: 'For the October report');

      await send(tester);

      verify(() => repository.create(connectionId: 'c1', level: 'read', reason: 'For the October report')).called(1);
      expect(router.state.uri.path, ApplicationRoutesConstants.accessRequests);
      expect(find.text(en.access_requests_sent_snackbar), findsOneWidget);
      verify(repository.mine).called(1);
      expect(find.byType(ConfirmationDialog), findsNothing);
    });

    testWidgets('Send is disabled while a request is out', (tester) async {
      final slow = Completer<Result<MyAccessRequest>>();
      when(
        () => repository.create(
          connectionId: any(named: 'connectionId'),
          level: any(named: 'level'),
          reason: any(named: 'reason'),
        ),
      ).thenAnswer((_) => slow.future);
      await pumpForm(tester);
      await fill(tester);

      await tester.ensureVisible(_send);
      await tester.tap(_send);
      await tester.pump();

      expect(find.descendant(of: _send, matching: find.byType(CircularProgressIndicator)), findsOneWidget);
      await tester.tap(_send, warnIfMissed: false);
      await tester.pump();
      verifyCreates().called(1);
      slow.complete(Success(created));
      await tester.pumpAndSettle();
    });

    for (final (name, code, open) in [
      ('409 pending', AppErrorCode.platformAccessRequestPending, true),
      ('409 already granted', AppErrorCode.platformAccessAlreadyGranted, true),
    ]) {
      testWidgets('$name shows its text and offers My requests', (tester) async {
        answerCreate(Failure(ValidationError('refused', code: code.key)));
        final router = await pumpForm(tester);
        await fill(tester);

        await send(tester);

        expect(
          find.descendant(
            of: _error('form'),
            matching: find.text(
              code == AppErrorCode.platformAccessRequestPending
                  ? en.error_platform_access_request_pending
                  : en.error_platform_access_already_granted,
            ),
          ),
          findsOneWidget,
        );
        expect(open, isTrue);
        await tester.tap(find.byKey(const ValueKey('access-request-open-requests')));
        await tester.pumpAndSettle();
        // The draft is still written, so leaving asks first.
        await tester.tap(find.text(en.yes));
        await tester.pumpAndSettle();
        expect(router.state.uri.path, ApplicationRoutesConstants.accessRequests);
      });
    }

    testWidgets('a 400 on reason lands under the reason field, and the draft stays', (tester) async {
      answerCreate(Failure(ValidationError('refused', code: AppErrorCode.platformAccessRequestReasonRefused.key)));
      await pumpForm(tester);
      await fill(tester, reason: 'Keep me');

      await send(tester);

      expect(
        find.descendant(of: _error('reason'), matching: find.text(en.error_platform_access_request_reason_refused)),
        findsOneWidget,
      );
      expect(find.text('Keep me'), findsOneWidget);
      expect(tester.widget<ListTile>(_connection('c1')).selected, isTrue);
    });

    testWidgets('a 400 on level lands under the level field', (tester) async {
      answerCreate(Failure(ValidationError('refused', code: AppErrorCode.platformGrantLevelRefused.key)));
      await pumpForm(tester);
      await fill(tester);

      await send(tester);

      expect(
        find.descendant(of: _error('level'), matching: find.text(en.error_platform_grant_level_refused)),
        findsOneWidget,
      );
    });

    for (final (name, code, text) in [
      ('a 403', AppErrorCode.platformAdminRoleRequired, (S s) => s.error_platform_admin_role_required),
      ('a 404', AppErrorCode.platformNotFound, (S s) => s.error_platform_not_found),
      ('an offline device', AppErrorCode.networkOffline, (S s) => s.error_network_offline),
      ('a Platform that does not answer', AppErrorCode.platformUnreachable, (S s) => s.error_platform_unreachable),
    ]) {
      testWidgets('$name shows its text with Retry, keeps the form and Retry sends again', (tester) async {
        answerCreate(Failure(ServerError('refused', code: code.key)));
        final router = await pumpForm(tester);
        await fill(tester, reason: 'Keep me');

        await send(tester);

        expect(find.descendant(of: _error('form'), matching: find.text(text(en))), findsOneWidget);
        expect(find.text('Keep me'), findsOneWidget);
        expect(router.state.uri.path, ApplicationRoutesConstants.accessRequestNew);
        answerCreate(Success(created));
        await tester.tap(find.byKey(const ValueKey('access-request-retry')));
        await tester.pumpAndSettle();

        verifyCreates().called(2);
        expect(router.state.uri.path, ApplicationRoutesConstants.accessRequests);
      });
    }
  });

  group('leaving', () {
    testWidgets('with a reason written asks first, and staying keeps the form', (tester) async {
      final router = await pumpForm(tester);
      await tester.enterText(_reason, 'Half written');
      await tester.pumpAndSettle();

      router.pop();
      await tester.pumpAndSettle();

      expect(find.byType(ConfirmationDialog), findsOneWidget);
      await tester.tap(find.text(en.no));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, ApplicationRoutesConstants.accessRequestNew);
      expect(find.text('Half written'), findsOneWidget);
    });

    testWidgets('with a reason written and confirmed, leaves', (tester) async {
      final router = await pumpForm(tester);
      await tester.enterText(_reason, 'Half written');
      await tester.pumpAndSettle();

      router.pop();
      await tester.pumpAndSettle();
      await tester.tap(find.text(en.yes));
      await tester.pumpAndSettle();

      expect(router.state.uri.path, ApplicationRoutesConstants.connectionList);
    });

    testWidgets('a reason of blanks leaves without asking', (tester) async {
      final router = await pumpForm(tester);
      await tester.enterText(_reason, '   ');
      await tester.pumpAndSettle();

      router.pop();
      await tester.pumpAndSettle();

      expect(find.byType(ConfirmationDialog), findsNothing);
      expect(router.state.uri.path, ApplicationRoutesConstants.connectionList);
    });
  });

  testWidgets('speaks Turkish when the app does', (tester) async {
    await pumpForm(tester, locale: const Locale('tr'));

    expect(find.text('Talebi gönder'), findsOneWidget);
    expect(find.text('Gerekçe'), findsOneWidget);
  });
}
