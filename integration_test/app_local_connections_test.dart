import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:libredb_mobile/app/shell/responsive_scaffold.dart';
import 'package:libredb_mobile/core/logging/app_logger.dart';
import 'package:libredb_mobile/features/connections/presentation/pages/connection_list_page.dart';
import 'package:libredb_mobile/infrastructure/storage/local_storage.dart';
import 'package:libredb_mobile/main/main_local.dart' as app;

/// On-device **local twin** of the connection-list flow, against the real `tool/studio-dev` backend over `adb reverse`.
/// Unlike the mock twin, nothing here is faked: it delegates to `main_local.main()`, so the real `DebugSessionSeed`
/// hook writes the session carried in `--dart-define=SEED_SESSION`, the real bootstrap runs, and the app signs in to
/// studio-dev without the Keycloak Custom Tab. The committed screenshot is this twin's product; the assertion is still
/// the proof.
///
/// It only runs green with studio-dev up and a seeded session, so it is never gated in CI. Run it with:
///   `scripts/on-device-local-twin.sh integration_test/app_local_connections_test.dart`
/// which fetches the tokens, sets up `adb reverse`, and drives it via `flutter drive` so the screenshot is written to
/// `build/screenshots/`. Add `--dart-define=SKIP_SHOTS=true` to assert without a screenshot.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  // Configure logging before the body touches AppLocalStorage, whose constructor logs. main_local.main() configures it
  // again when it boots; configure just reassigns the logger, so the second call is harmless.
  AppLogger.configure(isProduction: false, logFormat: LogFormat.simple);

  testWidgets('seeded session → connection list (local, studio-dev)', (tester) async {
    // A real device shows the introduction on a first run; mark it seen so the app opens on the authenticated shell.
    await AppLocalStorage().save(StorageKeys.onboardingSeen.key, true);

    // main_local reads SEED_SESSION, seeds the session into secure storage, then boots against studio-dev. The seeded
    // access token is expired, so startup refreshes it from the seeded refresh token before the first Studio call.
    // main_local.main() returns void (it is `void main() async`), so it is fired, not awaited; _pumpUntil below waits
    // out its async bootstrap.
    app.main();

    // The connection list loads behind a spinner while the token refresh and the first Studio calls run over
    // adb reverse, so pump in fixed steps rather than pumpAndSettle (which never settles under a spinner).
    await _pumpUntil(tester, find.byType(ConnectionListPage));
    expect(find.byType(ResponsiveScaffold), findsOneWidget);
    await _pumpUntil(tester, find.byKey(const ValueKey('connection-sections')));

    // Data true only on this screen with studio-dev's seeded connections (GET /api/connections/managed).
    await tester.scrollUntilVisible(
      find.text('Dev Postgres'),
      200,
      scrollable: find.descendant(
        of: find.byKey(const ValueKey('connection-sections')),
        matching: find.byType(Scrollable),
      ),
    );
    expect(find.text('Dev Postgres'), findsOneWidget);

    // The screenshot is unconditional for the local twin (its product), skippable only when a run cannot sink one.
    if (!const bool.fromEnvironment('SKIP_SHOTS')) {
      await binding.convertFlutterSurfaceToImage();
      await tester.pumpAndSettle();
      await binding.takeScreenshot('01_connections_local_android');
    }
  });
}

/// Pumps in fixed steps until [finder] matches or [timeout] elapses, for a screen whose arrival waits on the real
/// backend. Unlike `pumpAndSettle`, it does not require the frame to go idle, so a loading spinner does not hang it.
Future<void> _pumpUntil(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 30),
  Duration step = const Duration(milliseconds: 200),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(step);
    if (finder.evaluate().isNotEmpty) return;
  }
  throw TestFailure('timed out after $timeout waiting for $finder');
}
