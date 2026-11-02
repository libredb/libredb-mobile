import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:libredb_mobile/app/app.dart';
import 'package:libredb_mobile/app/di/mock_sign_in_dependencies.dart';
import 'package:libredb_mobile/app/shell/responsive_scaffold.dart';
import 'package:libredb_mobile/core/logging/app_logger.dart';
import 'package:libredb_mobile/core/testing/app_key_constants.dart';
import 'package:libredb_mobile/features/connections/presentation/pages/connection_list_page.dart';
import 'package:libredb_mobile/infrastructure/storage/local_storage.dart';

/// On-device mock twin of the connection-list flow. Boots the full app exactly as `main_mock.dart` does — the mocked
/// API of `assets/mock/*.json` (`AppConfig.mock()`) and the mock sign-in in place of Keycloak — and drives cold start
/// → single sign-on → connection list on a real emulator or device.
///
/// Its headless twin is `test/integration/app_smoke_test.dart`. This one adds what a headless widget test cannot
/// exercise: real rendering, hit-testing and platform channels on the device. The assertion is the proof; a
/// screenshot (local twin, Phase 2) is secondary.
///
/// Run (no screenshots): `fvm flutter test integration_test/app_connections_test.dart -d emulator-5554`
/// Run (with screenshots): `fvm flutter drive --driver test_driver/integration_test.dart
///   --target integration_test/app_connections_test.dart -d emulator-5554`
///
/// Never gated in CI — see docs/testing-architecture.md.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  // The global test bootstrap (test/flutter_test_config.dart) does not run for integration_test/, so the app's
  // loggers would hit a LateInitializationError on the first build. Configure logging as that bootstrap does.
  AppLogger.configure(isProduction: false, logFormat: LogFormat.simple);

  testWidgets('cold start → single sign-on → connection list (mock mode)', (tester) async {
    // On a real device the introduction is shown on a first run; mark it seen so the app opens on the login screen,
    // the flow this twin is about. This writes to the device's real preferences, the same store the app reads.
    await AppLocalStorage().save(StorageKeys.onboardingSeen.key, true);

    await tester.pumpWidget(App(dependencies: MockSignInDependencies(), language: 'en'));
    await tester.pumpAndSettle();

    // On a device that may still carry a session from an earlier run, sign in only when the login screen is shown;
    // an already-authenticated start lands on the connection list directly. Either path ends on the same screen.
    if (find.byKey(loginButtonSsoKey).evaluate().isNotEmpty) {
      await tester.tap(find.byKey(loginButtonSsoKey));
      await tester.pumpAndSettle();
    }

    // The router redirects to the authenticated shell, which opens the connection list.
    expect(find.byType(ResponsiveScaffold), findsOneWidget);
    expect(find.byType(ConnectionListPage), findsOneWidget);

    // The mock API answers the managed connections after a short delay.
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    // Data true only on this screen: the managed connections from GET_connections_managed.json, grouped and sorted by
    // group name. Reporting sorts to the top; Sales is further down, so it has to be scrolled into view. The finds are
    // scoped to the sections list, because a connection also appears in the recent strip once it has been opened, and
    // that strip's presence depends on device state and screen height — scoping keeps the twin stable across devices.
    final sections = find.byKey(const ValueKey('connection-sections'));
    expect(find.descendant(of: sections, matching: find.text('Reporting (SQL Server)')), findsOneWidget);
    await tester.scrollUntilVisible(
      find.descendant(of: sections, matching: find.text('Sales (PostgreSQL)')),
      200,
      scrollable: find.descendant(of: sections, matching: find.byType(Scrollable)),
    );
    expect(find.descendant(of: sections, matching: find.text('Sales (PostgreSQL)')), findsOneWidget);
  });
}
