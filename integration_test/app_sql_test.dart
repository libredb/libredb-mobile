import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:libredb_mobile/app/app.dart';
import 'package:libredb_mobile/app/di/mock_sign_in_dependencies.dart';
import 'package:libredb_mobile/core/logging/app_logger.dart';
import 'package:libredb_mobile/core/testing/app_key_constants.dart';
import 'package:libredb_mobile/features/sql_editor/presentation/widgets/editor_actions.dart';
import 'package:libredb_mobile/features/sql_editor/presentation/widgets/editor_input.dart';
import 'package:libredb_mobile/infrastructure/storage/local_storage.dart';

/// On-device mock twin of the SQL-editor flow: signs in (mock), opens a connection, types a statement, runs it, and
/// reads the result table. Exercises the editor input, the run action and the result rendering on a real device. The
/// masked-result assertion lives in the local twin (masking is server-side); here the mocked POST /db/query answer is
/// the product. See docs/testing-architecture.md, "On-device twin tests".
///
/// Run: `fvm flutter test integration_test/app_sql_test.dart -d emulator-5554`
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  AppLogger.configure(isProduction: false, logFormat: LogFormat.simple);

  testWidgets('sign in → open a connection → run a statement → read the result (mock mode)', (tester) async {
    await AppLocalStorage().save(StorageKeys.onboardingSeen.key, true);

    await tester.pumpWidget(App(dependencies: MockSignInDependencies(), language: 'en'));
    await tester.pumpAndSettle();

    if (find.byKey(loginButtonSsoKey).evaluate().isNotEmpty) {
      await tester.tap(find.byKey(loginButtonSsoKey));
      await tester.pumpAndSettle();
    }

    // Open a connection (sets the active one), then switch to the SQL editor through the bottom navigation.
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reporting (SQL Server)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('SQL'));
    await tester.pumpAndSettle();

    // Type a read statement and run it. The pump after entering text lets Run enable (it is disabled while empty).
    await tester.enterText(find.byKey(EditorInput.fieldKey), 'SELECT * FROM orders');
    await tester.pump();
    await tester.tap(find.byKey(EditorActions.runKey));
    await tester.pumpAndSettle();

    // The mocked POST /db/query answers two rows; its cells are true only on this screen with this data.
    expect(find.text('paid'), findsWidgets);
    expect(find.text('gift'), findsWidgets);
  });
}
