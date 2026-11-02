import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:libredb_mobile/app/app.dart';
import 'package:libredb_mobile/app/di/mock_sign_in_dependencies.dart';
import 'package:libredb_mobile/core/logging/app_logger.dart';
import 'package:libredb_mobile/core/testing/app_key_constants.dart';
import 'package:libredb_mobile/infrastructure/storage/local_storage.dart';

/// On-device mock twin of the Browse flow: signs in (mock), opens a connection, and browses its objects. Exercises the
/// connection → `/browse` navigation, the container level and the auto-opened session-default container on a real
/// device. The flow is the product; see docs/testing-architecture.md, "On-device twin tests".
///
/// Run: `fvm flutter test integration_test/app_browse_test.dart -d emulator-5554`
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  AppLogger.configure(isProduction: false, logFormat: LogFormat.simple);

  testWidgets('sign in → open a connection → browse its objects (mock mode)', (tester) async {
    await AppLocalStorage().save(StorageKeys.onboardingSeen.key, true);

    await tester.pumpWidget(App(dependencies: MockSignInDependencies(), language: 'en'));
    await tester.pumpAndSettle();

    if (find.byKey(loginButtonSsoKey).evaluate().isNotEmpty) {
      await tester.tap(find.byKey(loginButtonSsoKey));
      await tester.pumpAndSettle();
    }

    // Wait for the managed connections, then open one. Reporting sorts to the top, so it needs no scroll.
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('Reporting (SQL Server)'), findsOneWidget);
    await tester.tap(find.text('Reporting (SQL Server)'));
    await tester.pumpAndSettle();

    // Browse auto-opens the connection's session-default schema "public" and shows its object kinds with the counts
    // from the mocked POST /db/objects/counts (42 tables, among others). True only on this screen with this data.
    expect(find.text('public'), findsWidgets);
    expect(find.text('Tables'), findsWidgets);
    expect(find.text('42'), findsWidgets);
  });
}
