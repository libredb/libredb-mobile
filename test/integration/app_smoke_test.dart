@Tags(['widget'])
library;

import 'package:flutter/widgets.dart';
import 'package:libredb_mobile/app/di/local_sign_in_dependencies.dart';
import 'package:libredb_mobile/app/shell/responsive_scaffold.dart';
import 'package:libredb_mobile/features/connections/presentation/pages/connection_list_page.dart';
import 'package:libredb_mobile/core/testing/app_key_constants.dart';
import 'package:libredb_mobile/app/app.dart';
import 'package:flutter_test/flutter_test.dart';

/// End-to-end smoke: boots the full app as `main_local.dart` does, the mocked API of `assets/mock/*.json`
/// (`AppConfig.dev()`) and the local sign-in in place of Keycloak, and drives cold-start → single sign-on → connection
/// list. Exercises routing + DI + BLoCs + the mock HTTP layer together.
///
/// Runs headless under the normal `flutter test` (no device/emulator). The
/// global bootstrap (`test/flutter_test_config.dart`) supplies the
/// secure-storage mock + a clean storage reset before each test, so the app
/// starts unauthenticated and lands on login.
void main() {
  testWidgets('cold start → single sign-on → connection list (mock mode)', (tester) async {
    await tester.pumpWidget(App(dependencies: LocalSignInDependencies(), language: 'en'));
    await tester.pumpAndSettle();

    // Cold start lands on the login screen (no token after the reset), which offers only single sign-on.
    expect(find.byKey(loginButtonSsoKey), findsOneWidget);

    // The local sign-in stands in for Keycloak and needs no server.
    await tester.tap(find.byKey(loginButtonSsoKey));
    await tester.pumpAndSettle();

    // Router redirects to the authenticated shell, which opens the connection list.
    expect(find.byType(ResponsiveScaffold), findsOneWidget);
    expect(find.byType(ConnectionListPage), findsOneWidget);
    // The mock API answers the managed connections after a delay.
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    // The sections come sorted by group name, so Analytics is first and Sales further down the list.
    expect(find.text('Reporting (SQL Server)'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Sales (PostgreSQL)'),
      200,
      scrollable: find.descendant(
        of: find.byKey(const ValueKey('connection-sections')),
        matching: find.byType(Scrollable),
      ),
    );
    expect(find.text('Sales (PostgreSQL)'), findsOneWidget);
  });
}
