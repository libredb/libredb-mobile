@Tags(['widget'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:libredb_mobile/features/platform_connections/presentation/widgets/connection_active_dialog.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/shared/models/platform_connection.dart';

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

void main() {
  late List<bool?> results;

  setUp(() => results = []);

  Future<void> pumpOpener(WidgetTester tester, Future<void> Function(BuildContext context) open) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, _) => Scaffold(
            body: Builder(
              builder: (context) => TextButton(onPressed: () => open(context), child: const Text('open')),
            ),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(
        localizationsDelegates: const [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.delegate.supportedLocales,
        routerConfig: router,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Future<void> openFor(WidgetTester tester, PlatformConnection connection) => pumpOpener(
    tester,
    (context) async => results.add(await showConnectionActiveDialog(context, connection: connection)),
  );

  testWidgets('an active connection asks to disable it, and Disable answers true', (tester) async {
    await openFor(tester, _orders);

    expect(find.text('Disable connection'), findsOneWidget);
    expect(
      find.text(
        'Orders closes for every Studio user within about 30 seconds. Queries already running are not stopped. '
        'Its grants are kept.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Disable'));
    await tester.pumpAndSettle();

    expect(results, [true]);
  });

  testWidgets('an inactive connection asks to enable it, and Cancel answers false', (tester) async {
    await openFor(tester, _billing);

    expect(find.text('Enable connection'), findsOneWidget);
    expect(
      find.text(
        'Legacy Billing opens again for everyone who holds a grant on it. Those grants can take user seats of the '
        'license.',
      ),
      findsOneWidget,
    );
    expect(find.widgetWithText(FilledButton, 'Enable'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(results, [false]);
  });

  testWidgets('a barrier tap answers null', (tester) async {
    await openFor(tester, _orders);

    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();

    expect(results, [null]);
  });

  testWidgets('the user-seats dialog names the connection grants and closes with OK', (tester) async {
    await pumpOpener(tester, showConnectionUserSeatsDialog);

    expect(find.text('Not enough user seats'), findsOneWidget);
    expect(
      find.text('The Platform license does not have enough user seats for the grants of this connection.'),
      findsOneWidget,
    );
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
  });
}
