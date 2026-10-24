@Tags(['widget'])
library;

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/core/testing/app_key_constants.dart';
import 'package:libredb_mobile/features/app_lock/application/app_lock_bloc.dart';
import 'package:libredb_mobile/features/app_lock/domain/entities/app_lock_settings.dart';
import 'package:libredb_mobile/features/app_lock/domain/repositories/app_lock_settings_repository.dart';
import 'package:libredb_mobile/features/app_lock/domain/services/device_authenticator.dart';
import 'package:libredb_mobile/features/app_lock/presentation/widgets/app_lock_settings_section.dart';
import 'package:libredb_mobile/infrastructure/config/environment.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mock_classes.dart';
import '../../../../support/golden_app.dart';

const _off = AppLockSettings.defaults;
const _on5 = AppLockSettings(enabled: true, timeout: AppLockTimeout.fiveMinutes);

void main() {
  late MockAppLockBloc lock;
  late MockIAppLockSettingsRepository repository;
  late MockIDeviceAuthenticator authenticator;

  setUpAll(() {
    registerFallbackValue(const DeviceAuthPrompt(reason: '', title: '', cancel: ''));
    registerFallbackValue(_off);
    registerFallbackValue(const AppLockSettingsChanged(_off));
  });

  setUp(() {
    lock = MockAppLockBloc();
    repository = MockIAppLockSettingsRepository();
    authenticator = MockIDeviceAuthenticator();
    when(() => authenticator.canAuthenticate()).thenAnswer((_) async => true);
    when(() => authenticator.authenticate(any())).thenAnswer((_) async => const DeviceAuthSucceeded());
    when(() => repository.write(any())).thenAnswer((_) async {});
  });

  Future<void> pump(WidgetTester tester, AppLockState state, {bool required = false}) async {
    whenListen(lock, const Stream<AppLockState>.empty(), initialState: state);
    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: [
          RepositoryProvider<AppConfig>.value(value: AppConfig.test(appLockRequired: required)),
          RepositoryProvider<IAppLockSettingsRepository>.value(value: repository),
          RepositoryProvider<IDeviceAuthenticator>.value(value: authenticator),
        ],
        child: BlocProvider<AppLockBloc>.value(
          value: lock,
          child: goldenScreen(const Scaffold(body: AppLockSettingsSection())),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  SwitchListTile switchTile(WidgetTester tester) => tester.widget<SwitchListTile>(find.byKey(appLockSwitchKey));

  testWidgets('shows the switch off with the default timeout of five minutes', (tester) async {
    await pump(tester, const AppLockOff(settings: _off));

    expect(find.text('App lock'), findsOneWidget);
    expect(find.text('Ask for your fingerprint, face or screen lock when the app opens'), findsOneWidget);
    expect(switchTile(tester).value, isFalse);
    expect(switchTile(tester).onChanged, isNotNull);
    expect(find.text('5 minutes in the background'), findsOneWidget);
    expect(tester.widget<ListTile>(find.byKey(appLockTimeoutKey)).enabled, isFalse);
  });

  testWidgets('turning it on asks the prompt, stores it and hands it to the app lock', (tester) async {
    await pump(tester, const AppLockOff(settings: _off));

    await tester.tap(find.byKey(appLockSwitchKey));
    await tester.pumpAndSettle();

    final prompt = verify(() => authenticator.authenticate(captureAny())).captured.single as DeviceAuthPrompt;
    expect(prompt.reason, 'Confirm it is you to turn on the app lock');
    verify(() => repository.write(_on5)).called(1);
    verify(() => lock.add(const AppLockSettingsChanged(_on5))).called(1);
  });

  testWidgets('a cancelled prompt leaves it off', (tester) async {
    when(() => authenticator.authenticate(any())).thenAnswer((_) async => const DeviceAuthCancelled());
    await pump(tester, const AppLockOff(settings: _off));

    await tester.tap(find.byKey(appLockSwitchKey));
    await tester.pumpAndSettle();

    verifyNever(() => repository.write(any()));
    verifyNever(() => lock.add(any()));
  });

  testWidgets('a device without a screen lock shows why the switch is unavailable', (tester) async {
    when(() => authenticator.canAuthenticate()).thenAnswer((_) async => false);
    await pump(tester, const AppLockOff(settings: _off));

    expect(find.text('Set a screen lock on this device to turn this on'), findsOneWidget);
    expect(switchTile(tester).value, isFalse);
    expect(switchTile(tester).onChanged, isNull);
  });

  testWidgets('a lock left on after the screen lock was removed can still be turned off', (tester) async {
    when(() => authenticator.canAuthenticate()).thenAnswer((_) async => false);
    await pump(tester, const AppLockUnlocked(settings: _on5));

    expect(switchTile(tester).value, isTrue);
    await tester.tap(find.byKey(appLockSwitchKey));
    await tester.pumpAndSettle();

    verifyNever(() => authenticator.authenticate(any()));
    verify(() => repository.write(_off)).called(1);
  });

  testWidgets('the timeout offers immediately, 1, 5 and 15 minutes and stores the choice', (tester) async {
    await pump(tester, const AppLockUnlocked(settings: _on5));

    await tester.tap(find.byKey(appLockTimeoutKey));
    await tester.pumpAndSettle();
    expect(find.text('Immediately'), findsOneWidget);
    expect(find.text('1 minute in the background'), findsOneWidget);
    expect(find.text('5 minutes in the background'), findsNWidgets(2));
    expect(find.text('15 minutes in the background'), findsOneWidget);

    await tester.tap(find.text('Immediately'));
    await tester.pumpAndSettle();

    const immediately = AppLockSettings(enabled: true, timeout: AppLockTimeout.immediately);
    verify(() => repository.write(immediately)).called(1);
    verify(() => lock.add(const AppLockSettingsChanged(immediately))).called(1);
  });

  testWidgets('a refused write says the setting was not saved', (tester) async {
    when(() => repository.write(any())).thenThrow(StateError('refused'));
    await pump(tester, const AppLockUnlocked(settings: _on5));

    await tester.tap(find.byKey(appLockSwitchKey));
    await tester.pumpAndSettle();

    expect(find.text('The app lock setting could not be saved.'), findsOneWidget);
    verifyNever(() => lock.add(any()));
  });

  testWidgets('a build that requires the lock shows the switch on and disabled', (tester) async {
    await pump(tester, const AppLockUnlocked(settings: _off), required: true);

    expect(switchTile(tester).value, isTrue);
    expect(switchTile(tester).onChanged, isNull);
    expect(find.text('Required by your organization'), findsOneWidget);
    expect(tester.widget<ListTile>(find.byKey(appLockTimeoutKey)).enabled, isTrue);
  });

  testWidgets('a build that requires the lock shows it on and disabled on a device without a screen lock', (
    tester,
  ) async {
    when(() => authenticator.canAuthenticate()).thenAnswer((_) async => false);
    await pump(tester, const AppLockUnlocked(settings: _off), required: true);

    expect(switchTile(tester).value, isTrue);
    expect(switchTile(tester).onChanged, isNull);
    expect(find.text('Required by your organization'), findsOneWidget);
  });
}
