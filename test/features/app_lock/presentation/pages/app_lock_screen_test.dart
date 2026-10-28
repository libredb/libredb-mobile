@Tags(['widget'])
library;

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/core/testing/app_key_constants.dart';
import 'package:libredb_mobile/features/app_lock/application/app_lock_bloc.dart';
import 'package:libredb_mobile/features/app_lock/domain/entities/app_lock_settings.dart';
import 'package:libredb_mobile/features/app_lock/domain/services/device_authenticator.dart';
import 'package:libredb_mobile/features/app_lock/presentation/pages/app_lock_screen.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mock_classes.dart';
import '../../../../support/golden_app.dart';

const _on5 = AppLockSettings(enabled: true, timeout: AppLockTimeout.fiveMinutes);

void main() {
  late MockAppLockBloc bloc;
  late int signOuts;

  setUpAll(
    () => registerFallbackValue(const AppLockUnlockRequested(DeviceAuthPrompt(reason: '', title: '', cancel: ''))),
  );

  setUp(() {
    bloc = MockAppLockBloc();
    signOuts = 0;
  });

  Future<void> pump(WidgetTester tester, AppLockState state, {bool signingOut = false, Locale? locale}) async {
    whenListen(bloc, const Stream<AppLockState>.empty(), initialState: state);
    final screen = BlocProvider<AppLockBloc>.value(
      value: bloc,
      child: AppLockScreen(signingOut: signingOut, onSignOut: () => signOuts++),
    );
    await tester.pumpWidget(goldenScreen(screen));
    await tester.pump();
  }

  testWidgets('a locked app offers Unlock and Sign out', (tester) async {
    await pump(tester, const AppLockLocked(settings: _on5));

    expect(find.text('LibreDB is locked'), findsOneWidget);
    expect(find.text('Unlock with your fingerprint, face or screen lock to continue.'), findsOneWidget);
    expect(find.byKey(appLockUnlockKey), findsOneWidget);
    expect(find.byKey(appLockSignOutKey), findsOneWidget);
  });

  testWidgets('Unlock opens the prompt with its texts in the app language', (tester) async {
    await pump(tester, const AppLockLocked(settings: _on5));

    await tester.tap(find.byKey(appLockUnlockKey));

    final event = verify(() => bloc.add(captureAny())).captured.single as AppLockUnlockRequested;
    expect(event.prompt.reason, 'Unlock LibreDB');
    expect(event.prompt.title, 'LibreDB is locked');
    expect(event.prompt.cancel, 'Cancel');
  });

  testWidgets('Sign out runs the app\'s sign-out', (tester) async {
    await pump(tester, const AppLockLocked(settings: _on5));

    await tester.tap(find.byKey(appLockSignOutKey));

    expect(signOuts, 1);
  });

  testWidgets('a failed prompt says it was not recognized', (tester) async {
    await pump(tester, const AppLockLocked(settings: _on5, failure: AppLockFailure.failed));

    expect(find.text('Not recognized. Try again.'), findsOneWidget);
    expect(find.byKey(appLockUnlockKey), findsOneWidget);
  });

  testWidgets('too many attempts say to try later', (tester) async {
    await pump(tester, const AppLockLocked(settings: _on5, failure: AppLockFailure.lockedOut));

    expect(find.text('Too many attempts. Try again later.'), findsOneWidget);
  });

  testWidgets('a failed check says so and keeps Unlock', (tester) async {
    await pump(tester, const AppLockLocked(settings: _on5, failure: AppLockFailure.checkFailed));

    expect(
      find.text("LibreDB could not check this device's screen lock. Try Unlock again, or sign out."),
      findsOneWidget,
    );
    expect(find.byKey(appLockUnlockKey), findsOneWidget);
  });

  testWidgets('while the prompt is open both actions wait', (tester) async {
    await pump(tester, const AppLockAuthenticating(settings: _on5));

    expect(tester.widget<ButtonStyleButton>(find.byKey(appLockUnlockKey)).enabled, isFalse);
    expect(tester.widget<ButtonStyleButton>(find.byKey(appLockSignOutKey)).enabled, isFalse);
  });

  testWidgets('a device without a screen lock is told to set one and offered only Sign out', (tester) async {
    await pump(tester, const AppLockUnavailable(settings: _on5, reason: AppLockUnavailableReason.noScreenLock));

    expect(find.text('Set a screen lock on this device to use LibreDB, or sign out.'), findsOneWidget);
    expect(find.byKey(appLockUnlockKey), findsNothing);
    await tester.tap(find.byKey(appLockSignOutKey));
    expect(signOuts, 1);
  });

  testWidgets('while signing out the screen shows progress and takes no tap', (tester) async {
    await pump(tester, const AppLockLocked(settings: _on5), signingOut: true);

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(tester.widget<ButtonStyleButton>(find.byKey(appLockUnlockKey)).enabled, isFalse);
    expect(tester.widget<ButtonStyleButton>(find.byKey(appLockSignOutKey)).enabled, isFalse);
  });

  // 844 by 390 is a phone's landscape size, which #419 made unreachable on a phone; the screen still meets it in a
  // split-screen view and on a tablet or foldable, where the platform ignores the app's portrait lock.
  testWidgets('fits a landscape phone', (tester) async {
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await pump(tester, const AppLockLocked(settings: _on5, failure: AppLockFailure.lockedOut));

    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.byKey(appLockSignOutKey));
    await tester.tap(find.byKey(appLockSignOutKey));
    expect(signOuts, 1);
  });
}
