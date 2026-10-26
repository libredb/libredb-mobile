@Tags(['widget'])
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:libredb_mobile/app/router/app_routes_constants.dart';
import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/platform_connections/domain/repositories/platform_connection_repository.dart';
import 'package:libredb_mobile/features/platform_connections/presentation/pages/platform_connection_list_page.dart';
import 'package:libredb_mobile/features/platform_connections/presentation/widgets/connection_list_providers.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/shared/design_system/components/app_empty_state.dart';
import 'package:libredb_mobile/shared/design_system/components/app_error_state.dart';
import 'package:libredb_mobile/shared/design_system/components/app_skeleton.dart';
import 'package:libredb_mobile/shared/design_system/theme/app_theme.dart';
import 'package:libredb_mobile/shared/design_system/tokens/engine_icons.dart';
import 'package:libredb_mobile/shared/models/platform_connection.dart';
import 'package:libredb_mobile/shared/widgets/platform_unreachable_status.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mock_classes.dart';

const _orders = PlatformConnection(
  id: 'c1',
  name: 'Orders',
  engine: 'postgres',
  status: 'active',
  hasWriteCredential: true,
);
const _billing = PlatformConnection(
  id: 'c2',
  name: 'Legacy Billing',
  engine: 'mysql',
  status: 'inactive',
  hasWriteCredential: false,
);
const _disabledOrders = PlatformConnection(
  id: 'c1',
  name: 'Orders',
  engine: 'postgres',
  status: 'inactive',
  hasWriteCredential: true,
);
const _odd = PlatformConnection(
  id: 'tenant/c 3',
  name: 'Odd One',
  engine: 'cockroach',
  status: 'archived',
  hasWriteCredential: true,
);

void main() {
  late MockIPlatformConnectionRepository repository;
  late List<(String, Object?)> pushed;

  /// Whether the Platform unreachable page covers the page.
  late ValueNotifier<bool> platformUnreachable;

  setUp(() {
    repository = MockIPlatformConnectionRepository();
    pushed = [];
    platformUnreachable = ValueNotifier(false);
    addTearDown(platformUnreachable.dispose);
  });

  void answer(Result<List<PlatformConnection>> result) => when(() => repository.list()).thenAnswer((_) async => result);

  Future<void> pumpPage(WidgetTester tester) async {
    final router = GoRouter(
      initialLocation: ApplicationRoutesConstants.platformConnections,
      routes: [
        GoRoute(
          path: ApplicationRoutesConstants.platformConnections,
          builder: (_, _) => const PlatformConnectionListProviders(child: PlatformConnectionListPage()),
        ),
        GoRoute(
          path: ApplicationRoutesConstants.platformConnectionGrants,
          builder: (_, state) {
            pushed.add((state.uri.path, state.extra));
            return Text('grants of ${state.pathParameters['id']}');
          },
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      RepositoryProvider<IPlatformConnectionRepository>.value(
        value: repository,
        child: MaterialApp.router(
          theme: AppTheme.light(),
          localizationsDelegates: const [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.delegate.supportedLocales,
          routerConfig: router,
          // The Platform shell's ResponsiveScaffold frames the page in the app, under the Platform gate.
          builder: (context, child) => ValueListenableBuilder(
            valueListenable: platformUnreachable,
            builder: (context, isUnreachable, _) => PlatformUnreachableStatus(
              isUnreachable: isUnreachable,
              child: Scaffold(body: child),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('shows the skeleton while the list loads', (tester) async {
    final pending = Completer<Result<List<PlatformConnection>>>();
    when(() => repository.list()).thenAnswer((_) => pending.future);

    await pumpPage(tester);
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(AppSkeleton), findsWidgets);
    pending.complete(const Success([]));
    await tester.pump(const Duration(milliseconds: 100));
  });

  testWidgets('says the install has no connections yet, and where they are added', (tester) async {
    answer(const Success([]));

    await pumpPage(tester);
    await tester.pumpAndSettle();

    expect(find.byType(AppEmptyState), findsOneWidget);
    expect(find.text('This install has no connections yet'), findsOneWidget);
    expect(find.text('Connections are added in the Platform web console.'), findsOneWidget);
    expect(find.byType(RefreshIndicator), findsOneWidget);
  });

  testWidgets('shows the rows in server order with their badges', (tester) async {
    answer(const Success([_orders, _billing, _odd]));

    await pumpPage(tester);
    await tester.pumpAndSettle();

    final names = tester.widgetList<Text>(find.textContaining(RegExp('^(Orders|Legacy Billing|Odd One)\$')));
    expect(names.map((t) => t.data), ['Orders', 'Legacy Billing', 'Odd One']);
    expect(find.byType(RefreshIndicator), findsOneWidget);

    Finder inRow(String name, Finder finder) =>
        find.descendant(of: find.byKey(ValueKey('platform-connection-${_idOf(name)}')), matching: finder);
    expect(inRow('Orders', find.text('Active')), findsOneWidget);
    expect(inRow('Orders', find.text('postgres')), findsOneWidget);
    expect(inRow('Orders', find.text('Read grants only')), findsNothing);
    expect(inRow('Legacy Billing', find.text('Inactive')), findsOneWidget);
    expect(inRow('Legacy Billing', find.text('Read grants only')), findsOneWidget);
    expect(inRow('Odd One', find.text('Unknown status')), findsOneWidget);
  });

  testWidgets('labels the engine icon with the engine id, and an unknown engine gets the generic icon', (tester) async {
    answer(const Success([_orders, _odd]));

    await pumpPage(tester);
    await tester.pumpAndSettle();

    final odd = tester.widget<Icon>(
      find
          .descendant(of: find.byKey(const ValueKey('platform-connection-tenant/c 3')), matching: find.byType(Icon))
          .first,
    );
    expect(odd.icon, genericEngineIcon);
    expect(odd.semanticLabel, 'cockroach');
    final orders = tester.widget<Icon>(
      find.descendant(of: find.byKey(const ValueKey('platform-connection-c1')), matching: find.byType(Icon)).first,
    );
    expect(orders.icon, engineIcon('postgres'));
    expect(orders.semanticLabel, 'postgres');
  });

  testWidgets('says no connection matches a search that finds none, and clearing it shows every row', (tester) async {
    answer(const Success([_orders, _billing]));
    await pumpPage(tester);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'nothing like it');
    await tester.pumpAndSettle();

    expect(find.text('No connection matches the filter'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget, reason: 'the filter stays, so it can be cleared');

    await tester.tap(find.byIcon(Icons.clear));
    await tester.pumpAndSettle();

    expect(find.text('Orders'), findsOneWidget);
    expect(find.text('Legacy Billing'), findsOneWidget);
  });

  testWidgets('leaving the page while a pull to refresh waits for Platform throws nothing', (tester) async {
    answer(const Success([_orders]));
    await pumpPage(tester);
    await tester.pumpAndSettle();
    final pending = Completer<Result<List<PlatformConnection>>>();
    when(() => repository.list()).thenAnswer((_) => pending.future);

    await tester.fling(find.text('Orders'), const Offset(0, 400), 1000);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    pending.complete(const Success([_orders]));
    await tester.pump(const Duration(seconds: 5));
    // The closing bloc lets the pending request finish before its stream ends, outside the fake clock.
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pump(const Duration(seconds: 5));

    expect(tester.takeException(), isNull);
  });

  group('once Platform answers again after its unreachable page covered the list', () {
    testWidgets('a list that failed while covered asks Platform again, once', (tester) async {
      platformUnreachable.value = true;
      answer(const Failure(NetworkError('Connection refused')));
      await pumpPage(tester);
      await tester.pumpAndSettle();
      verify(() => repository.list()).called(1);
      answer(const Success([_orders]));

      platformUnreachable.value = false;
      await tester.pumpAndSettle();

      verify(() => repository.list()).called(1);
      expect(find.text('Orders'), findsOneWidget);
    });

    testWidgets('a loaded list asks nothing and keeps its rows', (tester) async {
      answer(const Success([_orders]));
      await pumpPage(tester);
      await tester.pumpAndSettle();
      verify(() => repository.list()).called(1);
      platformUnreachable.value = true;
      await tester.pump();

      platformUnreachable.value = false;
      await tester.pumpAndSettle();

      verifyNever(() => repository.list());
      expect(find.text('Orders'), findsOneWidget);
    });
  });

  testWidgets('keeps the list under a banner when a refresh fails, and its retry asks again', (tester) async {
    answer(const Success([_orders]));
    await pumpPage(tester);
    await tester.pumpAndSettle();
    answer(Failure(ServerError('Platform text', code: AppErrorCode.platformInternalError.key)));

    await tester.fling(find.text('Orders'), const Offset(0, 400), 1000);
    await tester.pumpAndSettle();

    expect(find.text('Could not refresh the connections'), findsOneWidget);
    expect(find.text('Platform could not complete the request. Try again later.'), findsOneWidget);
    expect(find.text('Orders'), findsOneWidget);

    answer(const Success([_orders, _billing]));
    await tester.tap(find.widgetWithText(TextButton, 'Retry'));
    await tester.pumpAndSettle();

    expect(find.text('Could not refresh the connections'), findsNothing);
    expect(find.text('Legacy Billing'), findsOneWidget);
    verify(() => repository.list()).called(3);
  });

  testWidgets('keeps the empty install under a banner when a refresh fails, and its retry asks again', (tester) async {
    answer(const Success([]));
    await pumpPage(tester);
    await tester.pumpAndSettle();
    answer(Failure(ServerError('Platform text', code: AppErrorCode.platformInternalError.key)));

    await tester.fling(find.byType(AppEmptyState), const Offset(0, 400), 1000);
    await tester.pumpAndSettle();

    expect(find.text('Could not refresh the connections'), findsOneWidget);
    expect(find.text('Platform could not complete the request. Try again later.'), findsOneWidget);
    expect(find.text('This install has no connections yet'), findsOneWidget);
    expect(find.text('Platform text'), findsNothing);

    answer(const Success([_orders]));
    await tester.tap(find.widgetWithText(TextButton, 'Retry'));
    await tester.pumpAndSettle();

    expect(find.text('Could not refresh the connections'), findsNothing);
    expect(find.text('Orders'), findsOneWidget);
    verify(() => repository.list()).called(3);
  });

  testWidgets('shows a failure with its message and a retry that loads again', (tester) async {
    answer(Failure(ServerError('Platform text', code: AppErrorCode.platformApiDisabled.key)));
    await pumpPage(tester);
    await tester.pumpAndSettle();

    expect(find.byType(AppErrorState), findsOneWidget);
    expect(find.text('Could not load the connections'), findsOneWidget);
    expect(find.text('This Platform install does not accept the mobile app.'), findsOneWidget);
    expect(find.byType(RefreshIndicator), findsOneWidget);

    answer(const Success([_orders]));
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.text('Orders'), findsOneWidget);
  });

  testWidgets('offers no add, edit or delete control', (tester) async {
    answer(const Success([_orders, _billing]));
    await pumpPage(tester);
    await tester.pumpAndSettle();

    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.byType(Switch), findsNothing);
    expect(find.byType(Checkbox), findsNothing);
    for (final icon in [Icons.add, Icons.edit, Icons.edit_outlined, Icons.delete, Icons.delete_outline]) {
      expect(find.byIcon(icon), findsNothing);
    }
    await tester.tap(find.byKey(const ValueKey('platform-connection-actions-c1')));
    await tester.pumpAndSettle();
    for (final word in ['Add', 'Edit', 'Delete']) {
      expect(find.textContaining(word), findsNothing);
    }
  });

  group('enable and disable', () {
    Finder actions(String id) => find.byKey(ValueKey('platform-connection-actions-$id'));
    Finder inRow(String id, Finder finder) =>
        find.descendant(of: find.byKey(ValueKey('platform-connection-$id')), matching: finder);

    void answerSetActive(Result<PlatformConnection> result) =>
        when(() => repository.setActive(any(), active: any(named: 'active'))).thenAnswer((_) async => result);

    Future<void> confirmDisableOrders(WidgetTester tester) async {
      await tester.tap(actions('c1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Disable connection'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Disable'));
      await tester.pumpAndSettle();
    }

    testWidgets('labels the menu item by status, and an unknown status shows no menu', (tester) async {
      answer(const Success([_orders, _billing, _odd]));
      await pumpPage(tester);
      await tester.pumpAndSettle();

      expect(actions('tenant/c 3'), findsNothing);
      expect(tester.widget<PopupMenuButton<Object?>>(actions('c1')).tooltip, 'Connection actions');

      await tester.tap(actions('c1'));
      await tester.pumpAndSettle();
      expect(find.text('Disable connection'), findsOneWidget);
      expect(find.text('Enable connection'), findsNothing);
      await tester.tapAt(Offset.zero);
      await tester.pumpAndSettle();

      await tester.tap(actions('c2'));
      await tester.pumpAndSettle();
      expect(find.text('Enable connection'), findsOneWidget);
      expect(find.text('Disable connection'), findsNothing);
    });

    testWidgets('the disable dialog says what happens, and cancel sends nothing', (tester) async {
      answer(const Success([_orders, _billing]));
      await pumpPage(tester);
      await tester.pumpAndSettle();

      await tester.tap(actions('c1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Disable connection'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Orders closes for every Studio user within about 30 seconds. Queries already running are not stopped. '
          'Its grants are kept.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      verifyNever(() => repository.setActive(any(), active: any(named: 'active')));
    });

    testWidgets('the enable dialog says what happens, and a barrier tap sends nothing', (tester) async {
      answer(const Success([_orders, _billing]));
      await pumpPage(tester);
      await tester.pumpAndSettle();

      await tester.tap(actions('c2'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Enable connection'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Legacy Billing opens again for everyone who holds a grant on it. Those grants can take user seats of the '
          'license.',
        ),
        findsOneWidget,
      );
      expect(find.widgetWithText(FilledButton, 'Enable'), findsOneWidget);
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();

      verifyNever(() => repository.setActive(any(), active: any(named: 'active')));
    });

    testWidgets('while a request is out every menu is disabled and the row shows progress', (tester) async {
      final pending = Completer<Result<PlatformConnection>>();
      when(() => repository.setActive(any(), active: any(named: 'active'))).thenAnswer((_) => pending.future);
      answer(const Success([_orders, _billing]));
      await pumpPage(tester);
      await tester.pumpAndSettle();

      await tester.tap(actions('c1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Disable connection'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Disable'));
      await tester.pump();

      expect(actions('c1'), findsNothing);
      expect(inRow('c1', find.byType(CircularProgressIndicator)), findsOneWidget);
      expect(tester.widget<PopupMenuButton<Object?>>(actions('c2')).enabled, isFalse);
      verify(() => repository.setActive('c1', active: false)).called(1);

      pending.complete(const Success(_disabledOrders));
      await tester.pumpAndSettle();
      expect(tester.widget<PopupMenuButton<Object?>>(actions('c2')).enabled, isTrue);
    });

    testWidgets('after a 200 the row shows the answered status in place, without a reload', (tester) async {
      answerSetActive(const Success(_disabledOrders));
      answer(const Success([_orders, _billing]));
      await pumpPage(tester);
      await tester.pumpAndSettle();

      await confirmDisableOrders(tester);

      expect(inRow('c1', find.text('Inactive')), findsOneWidget);
      expect(find.text('Connection disabled'), findsOneWidget);
      final names = tester.widgetList<Text>(find.textContaining(RegExp(r'^(Orders|Legacy Billing)$')));
      expect(names.map((t) => t.data), ['Orders', 'Legacy Billing']);
      verify(() => repository.list()).called(1);
      verify(() => repository.setActive('c1', active: false)).called(1);
    });

    testWidgets('the snackbar names the answered status, not the asked one', (tester) async {
      // Another admin enabled it meanwhile: Platform answers it active.
      answerSetActive(const Success(_orders));
      answer(const Success([_orders, _billing]));
      await pumpPage(tester);
      await tester.pumpAndSettle();

      await confirmDisableOrders(tester);

      expect(find.text('Connection enabled'), findsOneWidget);
      expect(inRow('c1', find.text('Active')), findsOneWidget);
    });

    testWidgets('a 404 says the connection no longer exists and refreshes the list', (tester) async {
      answerSetActive(Failure(NotFoundError('404 NOT_FOUND', code: AppErrorCode.platformNotFound.key)));
      answer(const Success([_orders, _billing]));
      await pumpPage(tester);
      await tester.pumpAndSettle();
      answer(const Success([_billing]));

      await confirmDisableOrders(tester);

      expect(find.text('This connection no longer exists'), findsOneWidget);
      expect(find.text('Orders'), findsNothing);
      verify(() => repository.list()).called(2);
    });

    testWidgets('LICENSE_USER_SEATS opens the connection-worded dialog, never the grant-worded text', (tester) async {
      answerSetActive(Failure(AuthError('403', code: AppErrorCode.platformLicenseUserSeats.key)));
      answer(const Success([_orders, _billing]));
      await pumpPage(tester);
      await tester.pumpAndSettle();

      await tester.tap(actions('c2'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Enable connection'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Enable'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(
        find.text('The Platform license does not have enough user seats for the grants of this connection.'),
        findsOneWidget,
      );
      expect(find.text('The Platform license has no free user seat for this grant.'), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(inRow('c2', find.text('Inactive')), findsOneWidget);
    });

    for (final (name, error, text) in [
      (
        '400 VALIDATION_FAILED',
        ValidationError('400', code: AppErrorCode.platformValidationFailed.key),
        'Platform did not accept the request.',
      ),
      (
        '403 LICENSE_EXPIRED',
        AuthError('403', code: AppErrorCode.platformLicenseExpired.key),
        'The Platform license has expired.',
      ),
      (
        '500 INTERNAL_ERROR',
        ServerError('500', code: AppErrorCode.platformInternalError.key),
        'Platform could not complete the request. Try again later.',
      ),
    ]) {
      testWidgets('a $name shows its message in a snackbar and the row keeps its status', (tester) async {
        answerSetActive(Failure(error));
        answer(const Success([_orders, _billing]));
        await pumpPage(tester);
        await tester.pumpAndSettle();

        await confirmDisableOrders(tester);

        expect(find.descendant(of: find.byType(SnackBar), matching: find.text(text)), findsOneWidget);
        expect(inRow('c1', find.text('Active')), findsOneWidget);
        verify(() => repository.list()).called(1);
      });
    }

    testWidgets('a card tap still opens the grants page', (tester) async {
      answer(const Success([_orders]));
      await pumpPage(tester);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Orders'));
      await tester.pumpAndSettle();

      expect(pushed.single, ('/platform/connections/c1', _orders));
      verifyNever(() => repository.setActive(any(), active: any(named: 'active')));
    });
  });

  testWidgets('a tap on a row, an inactive one too, opens its grants with the connection as extra', (tester) async {
    answer(const Success([_billing, _odd]));
    await pumpPage(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Legacy Billing'));
    await tester.pumpAndSettle();

    expect(pushed.single, ('/platform/connections/c2', _billing));
  });

  testWidgets('a tap on a row whose id needs encoding pushes the encoded id', (tester) async {
    answer(const Success([_odd]));
    await pumpPage(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Odd One'));
    await tester.pumpAndSettle();

    expect(pushed.single.$2, _odd);
    expect(pushed.single.$1, '/platform/connections/tenant%2Fc%203');
    expect(find.text('grants of tenant/c 3'), findsOneWidget);
  });
}

String _idOf(String name) => switch (name) {
  'Orders' => 'c1',
  'Legacy Billing' => 'c2',
  _ => 'tenant/c 3',
};
