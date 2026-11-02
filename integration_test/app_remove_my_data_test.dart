import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:libredb_mobile/app/app.dart';
import 'package:libredb_mobile/app/di/mock_sign_in_dependencies.dart';
import 'package:libredb_mobile/core/logging/app_logger.dart';
import 'package:libredb_mobile/core/testing/app_key_constants.dart';
import 'package:libredb_mobile/infrastructure/storage/local_storage.dart';

/// On-device mock twin of the "Remove my data" flow: signs in (mock), opens the profile sheet, goes to settings,
/// confirms "Remove my data", and lands back on the login screen — the sign-out that the removal ends with. Exercises
/// the profile sheet, the settings route, the confirm dialog and the sign-out redirect on a real device. See
/// docs/testing-architecture.md, "On-device twin tests".
///
/// Run: `fvm flutter test integration_test/app_remove_my_data_test.dart -d emulator-5554`
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  AppLogger.configure(isProduction: false, logFormat: LogFormat.simple);

  testWidgets('sign in → settings → remove my data → back on the login screen (mock mode)', (tester) async {
    await AppLocalStorage().save(StorageKeys.onboardingSeen.key, true);

    await tester.pumpWidget(App(dependencies: MockSignInDependencies(), language: 'en'));
    await tester.pumpAndSettle();

    if (find.byKey(loginButtonSsoKey).evaluate().isNotEmpty) {
      await tester.tap(find.byKey(loginButtonSsoKey));
      await tester.pumpAndSettle();
    }
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    // Open the profile sheet from the top-bar avatar, then go to settings.
    await tester.tap(find.byKey(profileButtonKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(profileSettingsKey));
    await tester.pumpAndSettle();

    // The entry sits at the bottom of the settings list, below the fold, so scroll it into view before tapping.
    // Confirm "Remove my data"; the confirm button's label is also its intent — it removes and signs out.
    await tester.ensureVisible(find.byKey(settingsRemoveMyDataKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(settingsRemoveMyDataKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove and sign out'));
    await tester.pumpAndSettle();

    // The removal ends in a sign-out, so the app returns to the login screen — the datum true only after it ran.
    expect(find.byKey(loginButtonSsoKey), findsOneWidget);
  });
}
