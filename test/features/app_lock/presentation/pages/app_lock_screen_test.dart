@Tags(['widget'])
library;

import 'dart:async';

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
  late MockIDeviceAuthenticator authenticator;
  late int signOuts;

  setUpAll(
    () => registerFallbackValue(const AppLockUnlockRequested(DeviceAuthPrompt(reason: '', title: '', cancel: ''))),
  );

  setUp(() {
    bloc = MockAppLockBloc();
    authenticator = MockIDeviceAuthenticator();
    when(() => authenticator.availableBiometric()).thenAnswer((_) async => DeviceBiometric.none);
    signOuts = 0;
  });

  Future<void> pump(WidgetTester tester, AppLockState state, {bool signingOut = false, Locale? locale}) async {
    whenListen(bloc, const Stream<AppLockState>.empty(), initialState: state);
    final screen = RepositoryProvider<IDeviceAuthenticator>.value(
      value: authenticator,
      child: BlocProvider<AppLockBloc>.value(
        value: bloc,
        child: AppLockScreen(signingOut: signingOut, onSignOut: () => signOuts++),
      ),
    );
    await tester.pumpWidget(goldenScreen(screen));
    await tester.pump();
  }

  testWidgets('a locked app offers Unlock and Sign out', (tester) async {
    await pump(tester, const AppLockLocked(settings: _on5));

    expect(find.text('LibreDB is locked'), findsOneWidget);
    expect(find.text('Unlock with your screen lock to continue.'), findsOneWidget);
    expect(find.byKey(appLockUnlockKey), findsOneWidget);
    expect(find.byKey(appLockSignOutKey), findsOneWidget);
  });

  // #444: the screen names the biometric the device has, not a fingerprint on every device.
  Finder unlockIcon() => find.descendant(of: find.byKey(appLockUnlockKey), matching: find.byType(Icon));

  IconData? unlockIconData(WidgetTester tester) => tester.widget<Icon>(unlockIcon()).icon;

  group('the biometric the device has', () {
    Future<void> pumpWith(WidgetTester tester, Future<DeviceBiometric> Function() answer) async {
      when(() => authenticator.availableBiometric()).thenAnswer((_) => answer());
      await pump(tester, const AppLockLocked(settings: _on5));
    }

    testWidgets('a Face ID device shows a face and says face, never fingerprint', (tester) async {
      await pumpWith(tester, () async => DeviceBiometric.face);

      expect(unlockIconData(tester), Icons.face_unlock_outlined);
      expect(find.text('Unlock with your face or screen lock to continue.'), findsOneWidget);
      expect(find.textContaining('fingerprint'), findsNothing);
    });

    testWidgets('a fingerprint device shows a fingerprint', (tester) async {
      await pumpWith(tester, () async => DeviceBiometric.fingerprint);

      expect(unlockIconData(tester), Icons.fingerprint);
      expect(find.text('Unlock with your fingerprint or screen lock to continue.'), findsOneWidget);
    });

    testWidgets('an iris device shows an eye', (tester) async {
      await pumpWith(tester, () async => DeviceBiometric.iris);

      expect(unlockIconData(tester), Icons.remove_red_eye_outlined);
      expect(find.text('Unlock with your iris or screen lock to continue.'), findsOneWidget);
    });

    testWidgets('a device with several biometrics claims none of them', (tester) async {
      await pumpWith(tester, () async => DeviceBiometric.several);

      expect(unlockIconData(tester), Icons.lock_open_outlined);
      expect(find.text('Unlock with your biometrics or screen lock to continue.'), findsOneWidget);
    });

    testWidgets('a device with no biometric enrolled names only the screen lock', (tester) async {
      await pumpWith(tester, () async => DeviceBiometric.none);

      expect(unlockIconData(tester), Icons.lock_open_outlined);
      expect(find.text('Unlock with your screen lock to continue.'), findsOneWidget);
    });

    testWidgets('a failed question claims no biometric', (tester) async {
      await pumpWith(tester, () async => throw StateError('platform channel failed'));

      expect(unlockIconData(tester), Icons.lock_open_outlined);
      expect(find.text('Unlock with your screen lock to continue.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('while the answer is pending no icon and no biometric text show, so nothing flickers', (tester) async {
      final answer = Completer<DeviceBiometric>();
      await pumpWith(tester, () => answer.future);

      expect(unlockIcon(), findsNothing);
      expect(find.textContaining('Unlock with your'), findsOneWidget);
      expect(
        find.ancestor(
          of: find.textContaining('Unlock with your'),
          matching: find.byWidgetPredicate((widget) => widget is Visibility && !widget.visible),
        ),
        findsOneWidget,
        reason: 'the text keeps its space but is hidden and unread until the platform has answered',
      );
      expect(find.byKey(appLockUnlockKey), findsOneWidget);

      answer.complete(DeviceBiometric.face);
      await tester.pump();
      await tester.pump();

      expect(unlockIconData(tester), Icons.face_unlock_outlined);
      expect(find.text('Unlock with your face or screen lock to continue.'), findsOneWidget);
    });

    testWidgets('a slow answer falls back to the screen lock after a few seconds', (tester) async {
      await pumpWith(tester, () => Completer<DeviceBiometric>().future);

      expect(unlockIcon(), findsNothing);
      await tester.pump(const Duration(seconds: 4));

      expect(unlockIconData(tester), Icons.lock_open_outlined);
      expect(find.text('Unlock with your screen lock to continue.'), findsOneWidget);
    });
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

  // 844 by 390 is a phone's landscape size, which #419 made unreachable on every form factor; the screen still meets
  // it in a window the system sizes — a split-screen or free-form window, which ignores an orientation restriction.
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
