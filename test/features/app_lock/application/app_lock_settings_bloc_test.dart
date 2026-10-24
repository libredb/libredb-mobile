import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/features/app_lock/application/app_lock_settings_bloc.dart';
import 'package:libredb_mobile/features/app_lock/domain/entities/app_lock_settings.dart';
import 'package:libredb_mobile/features/app_lock/domain/services/device_authenticator.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mock_classes.dart';

const _prompt = DeviceAuthPrompt(reason: 'Confirm it is you', title: 'App lock', cancel: 'Cancel');

const _off = AppLockSettings.defaults;
const _on5 = AppLockSettings(enabled: true, timeout: AppLockTimeout.fiveMinutes);
const _on1 = AppLockSettings(enabled: true, timeout: AppLockTimeout.oneMinute);

void main() {
  late MockIAppLockSettingsRepository repository;
  late MockIDeviceAuthenticator authenticator;

  setUpAll(() {
    registerFallbackValue(_prompt);
    registerFallbackValue(_off);
  });

  setUp(() {
    repository = MockIAppLockSettingsRepository();
    authenticator = MockIDeviceAuthenticator();
    when(() => authenticator.canAuthenticate()).thenAnswer((_) async => true);
    when(() => authenticator.authenticate(any())).thenAnswer((_) async => const DeviceAuthSucceeded());
    when(() => repository.write(any())).thenAnswer((_) async {});
  });

  AppLockSettingsBloc build() => AppLockSettingsBloc(repository: repository, authenticator: authenticator);

  AppLockSettingsChangeRequested change(AppLockSettings current, AppLockSettings next) =>
      AppLockSettingsChangeRequested(current: current, next: next, prompt: _prompt);

  blocTest<AppLockSettingsBloc, AppLockSettingsState>(
    'opening asks whether the device has a screen lock',
    build: build,
    act: (bloc) => bloc.add(const AppLockSettingsOpened()),
    expect: () => const [AppLockSettingsReady(canAuthenticate: true)],
  );

  blocTest<AppLockSettingsBloc, AppLockSettingsState>(
    'a device without a screen lock cannot turn the lock on',
    setUp: () => when(() => authenticator.canAuthenticate()).thenAnswer((_) async => false),
    build: build,
    act: (bloc) => bloc.add(const AppLockSettingsOpened()),
    expect: () => const [AppLockSettingsReady(canAuthenticate: false)],
  );

  blocTest<AppLockSettingsBloc, AppLockSettingsState>(
    'a check that fails is logged and the switch stays unavailable',
    setUp: () => when(() => authenticator.canAuthenticate()).thenThrow(StateError('no activity')),
    build: build,
    act: (bloc) => bloc.add(const AppLockSettingsOpened()),
    expect: () => const [AppLockSettingsReady(canAuthenticate: false)],
  );

  blocTest<AppLockSettingsBloc, AppLockSettingsState>(
    'turning it on asks the prompt first, then stores it',
    build: build,
    seed: () => const AppLockSettingsReady(canAuthenticate: true),
    act: (bloc) => bloc.add(change(_off, _on5)),
    expect: () => const [
      AppLockSettingsSaving(canAuthenticate: true),
      AppLockSettingsSaved(canAuthenticate: true, settings: _on5),
    ],
    verify: (_) {
      verifyInOrder([() => authenticator.authenticate(_prompt), () => repository.write(_on5)]);
    },
  );

  blocTest<AppLockSettingsBloc, AppLockSettingsState>(
    'a cancelled prompt leaves it off and stores nothing',
    setUp: () => when(() => authenticator.authenticate(any())).thenAnswer((_) async => const DeviceAuthCancelled()),
    build: build,
    seed: () => const AppLockSettingsReady(canAuthenticate: true),
    act: (bloc) => bloc.add(change(_off, _on5)),
    expect: () => const [AppLockSettingsSaving(canAuthenticate: true), AppLockSettingsReady(canAuthenticate: true)],
    verify: (_) => verifyNever(() => repository.write(any())),
  );

  blocTest<AppLockSettingsBloc, AppLockSettingsState>(
    'a failed prompt leaves it off and stores nothing',
    setUp: () => when(() => authenticator.authenticate(any())).thenAnswer((_) async => const DeviceAuthFailed()),
    build: build,
    seed: () => const AppLockSettingsReady(canAuthenticate: true),
    act: (bloc) => bloc.add(change(_off, _on5)),
    expect: () => const [AppLockSettingsSaving(canAuthenticate: true), AppLockSettingsReady(canAuthenticate: true)],
    verify: (_) => verifyNever(() => repository.write(any())),
  );

  blocTest<AppLockSettingsBloc, AppLockSettingsState>(
    'a prompt that finds no screen lock makes the switch unavailable',
    setUp: () => when(() => authenticator.authenticate(any())).thenAnswer((_) async => const DeviceAuthNoScreenLock()),
    build: build,
    seed: () => const AppLockSettingsReady(canAuthenticate: true),
    act: (bloc) => bloc.add(change(_off, _on5)),
    expect: () => const [AppLockSettingsSaving(canAuthenticate: true), AppLockSettingsReady(canAuthenticate: false)],
    verify: (_) => verifyNever(() => repository.write(any())),
  );

  blocTest<AppLockSettingsBloc, AppLockSettingsState>(
    'changing the timeout stores it without a prompt',
    build: build,
    seed: () => const AppLockSettingsReady(canAuthenticate: true),
    act: (bloc) => bloc.add(change(_on5, _on1)),
    expect: () => const [
      AppLockSettingsSaving(canAuthenticate: true),
      AppLockSettingsSaved(canAuthenticate: true, settings: _on1),
    ],
    verify: (_) => verifyNever(() => authenticator.authenticate(any())),
  );

  blocTest<AppLockSettingsBloc, AppLockSettingsState>(
    'turning it off stores it without a prompt, on a device without a screen lock too',
    build: build,
    seed: () => const AppLockSettingsReady(canAuthenticate: false),
    act: (bloc) => bloc.add(change(_on1, _on1.copyWith(enabled: false))),
    expect: () => const [
      AppLockSettingsSaving(canAuthenticate: false),
      AppLockSettingsSaved(
        canAuthenticate: false,
        settings: AppLockSettings(enabled: false, timeout: AppLockTimeout.oneMinute),
      ),
    ],
    verify: (_) => verifyNever(() => authenticator.authenticate(any())),
  );

  blocTest<AppLockSettingsBloc, AppLockSettingsState>(
    'a refused write says so and the change is not in force',
    setUp: () => when(() => repository.write(any())).thenThrow(StateError('refused')),
    build: build,
    seed: () => const AppLockSettingsReady(canAuthenticate: true),
    act: (bloc) => bloc.add(change(_on5, _on1)),
    expect: () => const [
      AppLockSettingsSaving(canAuthenticate: true),
      AppLockSettingsFailure(canAuthenticate: true, errorCode: AppErrorCode.settingsAppLockNotSaved),
    ],
  );

  blocTest<AppLockSettingsBloc, AppLockSettingsState>(
    'a second change while the prompt is open is dropped',
    setUp: () {
      final answer = Completer<DeviceAuthResult>();
      when(() => authenticator.authenticate(any())).thenAnswer((_) => answer.future);
      Future<void>.delayed(const Duration(milliseconds: 10), () => answer.complete(const DeviceAuthSucceeded()));
    },
    build: build,
    seed: () => const AppLockSettingsReady(canAuthenticate: true),
    act: (bloc) => bloc
      ..add(change(_off, _on5))
      ..add(change(_off, _on5)),
    wait: const Duration(milliseconds: 20),
    expect: () => const [
      AppLockSettingsSaving(canAuthenticate: true),
      AppLockSettingsSaved(canAuthenticate: true, settings: _on5),
    ],
    verify: (_) => verify(() => authenticator.authenticate(any())).called(1),
  );
}
