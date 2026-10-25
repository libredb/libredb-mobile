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

  setUp(() {
    repository = MockIPlatformConnectionRepository();
    pushed = [];
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
          // The Platform shell's ResponsiveScaffold frames the page in the app.
          builder: (context, child) => Scaffold(body: child),
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

  testWidgets('offers no add, edit, delete, enable or disable control', (tester) async {
    answer(const Success([_orders, _billing]));
    await pumpPage(tester);
    await tester.pumpAndSettle();

    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.byType(Switch), findsNothing);
    expect(find.byType(Checkbox), findsNothing);
    expect(find.byType(PopupMenuButton<Object?>), findsNothing);
    for (final icon in [
      Icons.add,
      Icons.edit,
      Icons.edit_outlined,
      Icons.delete,
      Icons.delete_outline,
      Icons.more_vert,
    ]) {
      expect(find.byIcon(icon), findsNothing);
    }
    for (final word in ['Add', 'Edit', 'Delete', 'Enable', 'Disable']) {
      expect(find.textContaining(word), findsNothing);
    }
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
