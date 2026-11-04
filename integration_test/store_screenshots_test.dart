import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:libredb_mobile/app/app.dart';
import 'package:libredb_mobile/app/di/mock_sign_in_dependencies.dart';
import 'package:libredb_mobile/core/logging/app_logger.dart';
import 'package:libredb_mobile/core/testing/app_key_constants.dart';
import 'package:libredb_mobile/features/sql_editor/presentation/widgets/editor_actions.dart';
import 'package:libredb_mobile/features/sql_editor/presentation/widgets/editor_input.dart';

/// App Store / Play listing screenshot capture — a utility, NOT a CI test. Walks onboarding → sign-in →
/// connection list → browse → SQL in mock mode and sinks a screenshot at each. Run via the on-device driver on a
/// 6.9" iPhone simulator so the frames come out at store resolution:
///
///   flutter drive --driver test_driver/integration_test.dart \
///     --target integration_test/store_screenshots_test.dart -d IPHONE_SIM_UDID
///
/// Screenshots land in build/screenshots/*.png (see test_driver/integration_test.dart).
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  AppLogger.configure(isProduction: false, logFormat: LogFormat.simple);

  const onboardingSteps = 6;

  testWidgets('capture store screenshots (mock mode, en)', (tester) async {
    // No onboardingSeen flag set, so the onboarding deck shows on cold start.
    await tester.pumpWidget(App(dependencies: MockSignInDependencies(), language: 'en'));
    await tester.pumpAndSettle();

    // Onboarding: swipe left to advance, screenshot each screen.
    for (var i = 0; i < onboardingSteps; i++) {
      await binding.takeScreenshot('0${i + 1}_onboarding');
      if (i < onboardingSteps - 1) {
        await tester.fling(find.byKey(onboardingHeadlineKey), const Offset(-400, 0), 1200);
        await tester.pumpAndSettle();
      }
    }

    // Leave the deck on the last screen → login.
    if (find.byKey(onboardingDoneKey).evaluate().isNotEmpty) {
      await tester.tap(find.byKey(onboardingDoneKey));
      await tester.pumpAndSettle();
    }

    // Sign in (mock SSO).
    if (find.byKey(loginButtonSsoKey).evaluate().isNotEmpty) {
      await tester.tap(find.byKey(loginButtonSsoKey));
      await tester.pumpAndSettle();
    }

    // Connection list. Wait out the sign-in "Success" snackbar so it is not in frame.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await binding.takeScreenshot('07_connections');

    // Open a connection → browse its objects.
    await tester.tap(find.text('Reporting (SQL Server)'));
    await tester.pumpAndSettle();
    await binding.takeScreenshot('08_browse');

    // SQL editor → run a statement → read the result.
    await tester.tap(find.text('SQL'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(EditorInput.fieldKey), 'SELECT * FROM orders');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(EditorActions.runKey));
    await tester.pumpAndSettle();
    await binding.takeScreenshot('09_sql');
  });
}
