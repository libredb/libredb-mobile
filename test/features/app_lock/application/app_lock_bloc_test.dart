import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/core/security/screen_capture_protection.dart';
import 'package:libredb_mobile/features/app_lock/application/app_lock_bloc.dart';
import 'package:libredb_mobile/features/app_lock/domain/entities/app_lock_settings.dart';
import 'package:libredb_mobile/features/app_lock/domain/services/device_authenticator.dart';
import 'package:libredb_mobile/shared/utils/app_lifecycle_source.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mock_classes.dart';
import '../../../support/screen_capture.dart';

const _prompt = DeviceAuthPrompt(reason: 'Unlock LibreDB', title: 'LibreDB is locked', cancel: 'Cancel');

const _on5 = AppLockSettings(enabled: true, timeout: AppLockTimeout.fiveMinutes);

class _FakeLifecycle implements IAppLifecycleSource {
  final _changes = StreamController<AppLifecycleState>.broadcast(sync: true);

  @override
  AppLifecycleState? current = AppLifecycleState.resumed;

  @override
  Stream<AppLifecycleState> get changes => _changes.stream;

  void go(AppLifecycleState state) {
    current = state;
    _changes.add(state);
  }

  /// The states Android reports when the user leaves the app for another.
  void leave() {
    go(AppLifecycleState.inactive);
    go(AppLifecycleState.hidden);
    go(AppLifecycleState.paused);
  }

  /// The states Android reports when the user comes back.
  void comeBack() {
    go(AppLifecycleState.hidden);
    go(AppLifecycleState.inactive);
    go(AppLifecycleState.resumed);
  }
}

void main() {
  late MockIAppLockSettingsRepository settings;
  late MockIDeviceAuthenticator authenticator;
  late MockIRecentsPreview recents;
  late _FakeLifecycle lifecycle;
  late RecordingScreenCapturePlatform capturePlatform;
  late ScreenCaptureProtection capture;

  setUpAll(() => registerFallbackValue(_prompt));

  setUp(() {
    settings = MockIAppLockSettingsRepository();
    authenticator = MockIDeviceAuthenticator();
    recents = MockIRecentsPreview();
    lifecycle = _FakeLifecycle();
    capturePlatform = RecordingScreenCapturePlatform();
    capture = ScreenCaptureProtection(platform: capturePlatform, enabled: true);
    when(() => settings.read()).thenAnswer((_) async => _on5);
    when(() => authenticator.canAuthenticate()).thenAnswer((_) async => true);
    when(() => authenticator.authenticate(any())).thenAnswer((_) async => const DeviceAuthSucceeded());
    when(() => recents.setHidden(any())).thenAnswer((_) async => true);
  });

  /// A started bloc, its states recorded into [states].
  AppLockBloc start(
    FakeAsync async,
    List<AppLockState> states, {
    bool lockRequired = false,
    Duration? idleTimeout = const Duration(minutes: 15),
  }) {
    final bloc = AppLockBloc(
      settingsRepository: settings,
      authenticator: authenticator,
      lifecycle: lifecycle,
      recentsPreview: recents,
      captureProtection: capture,
      lockRequired: lockRequired,
      idleTimeout: idleTimeout,
    );
    bloc.stream.listen(states.add);
    bloc.add(const AppLockStarted());
    async.flushMicrotasks();
    return bloc;
  }

  /// A bloc started and signed in through a restored session, then unlocked by the prompt.
  AppLockBloc startUnlocked(FakeAsync async, List<AppLockState> states, {Duration? idleTimeout}) {
    final bloc = start(async, states, idleTimeout: idleTimeout ?? const Duration(minutes: 15))
      ..add(const AppLockSignedIn());
    async.flushMicrotasks();
    states.clear();
    return bloc;
  }

  group('settings', () {
    test('starts off when the stored settings are off', () {
      fakeAsync((async) {
        when(() => settings.read()).thenAnswer((_) async => AppLockSettings.defaults);
        final states = <AppLockState>[];
        final bloc = start(async, states);

        expect(bloc.state, const AppLockOff(settings: AppLockSettings.defaults));
        expect(bloc.state.coversApp, isFalse);
      });
    });

    test('starts unlocked while nobody is signed in when the lock is on', () {
      fakeAsync((async) {
        final states = <AppLockState>[];
        final bloc = start(async, states);

        expect(bloc.state, const AppLockUnlocked(settings: _on5));
      });
    });

    test('is starting, and covers nothing, until the settings are read', () {
      fakeAsync((async) {
        final read = Completer<AppLockSettings>();
        when(() => settings.read()).thenAnswer((_) => read.future);
        final states = <AppLockState>[];
        final bloc = start(async, states);

        expect(bloc.state, const AppLockStarting());
        expect(bloc.state.coversApp, isFalse);

        read.complete(_on5);
        async.flushMicrotasks();
        expect(bloc.state, const AppLockUnlocked(settings: _on5));
      });
    });

    test('a cold start that restores a session waits for the settings, then locks', () {
      fakeAsync((async) {
        final read = Completer<AppLockSettings>();
        when(() => settings.read()).thenAnswer((_) => read.future);
        final states = <AppLockState>[];
        final bloc = start(async, states)..add(const AppLockSessionRestored());
        async.flushMicrotasks();
        expect(bloc.state, const AppLockStarting());

        read.complete(_on5);
        async.flushMicrotasks();
        expect(bloc.state, const AppLockLocked(settings: _on5));
      });
    });

    test('unreadable settings keep the lock on, the safe side, with the default timeout', () {
      fakeAsync((async) {
        when(() => settings.read()).thenThrow(const FormatException('app_lock_timeout is not a timeout'));
        final states = <AppLockState>[];
        final bloc = start(async, states)..add(const AppLockSessionRestored());
        async.flushMicrotasks();

        expect(bloc.state, const AppLockLocked(settings: _on5));
      });
    });

    test('new settings from the settings section take effect', () {
      fakeAsync((async) {
        final states = <AppLockState>[];
        final bloc = startUnlocked(async, states);

        bloc.add(const AppLockSettingsChanged(AppLockSettings.defaults));
        async.flushMicrotasks();
        expect(bloc.state, const AppLockOff(settings: AppLockSettings.defaults));

        const on1 = AppLockSettings(enabled: true, timeout: AppLockTimeout.oneMinute);
        bloc.add(const AppLockSettingsChanged(on1));
        async.flushMicrotasks();
        expect(bloc.state, const AppLockUnlocked(settings: on1));
      });
    });
  });

  group('cold start', () {
    test('a cold start that restores a session locks', () {
      fakeAsync((async) {
        final states = <AppLockState>[];
        final bloc = start(async, states)..add(const AppLockSessionRestored());
        async.flushMicrotasks();

        expect(bloc.state, const AppLockLocked(settings: _on5));
        expect(bloc.state.coversApp, isTrue);
        verify(() => authenticator.canAuthenticate()).called(1);
        verifyNever(() => authenticator.authenticate(any()));
      });
    });

    test('a cold start does not lock while the lock is off', () {
      fakeAsync((async) {
        when(() => settings.read()).thenAnswer((_) async => AppLockSettings.defaults);
        final states = <AppLockState>[];
        final bloc = start(async, states)..add(const AppLockSessionRestored());
        async.flushMicrotasks();

        expect(bloc.state, const AppLockOff(settings: AppLockSettings.defaults));
      });
    });

    test('a sign-in at the identity provider opens unlocked', () {
      fakeAsync((async) {
        final states = <AppLockState>[];
        final bloc = start(async, states)..add(const AppLockSignedIn());
        async.flushMicrotasks();

        expect(bloc.state, const AppLockUnlocked(settings: _on5));
      });
    });
  });

  group('background', () {
    test('a resume after at least the timeout in the background locks', () {
      fakeAsync((async) {
        final states = <AppLockState>[];
        final bloc = startUnlocked(async, states);

        lifecycle.leave();
        async.elapse(const Duration(minutes: 6));
        lifecycle.comeBack();
        async.flushMicrotasks();

        expect(bloc.state, const AppLockLocked(settings: _on5));
      });
    });

    test('a resume after exactly the timeout locks', () {
      fakeAsync((async) {
        final states = <AppLockState>[];
        final bloc = startUnlocked(async, states);

        lifecycle.leave();
        async.elapse(const Duration(minutes: 5));
        lifecycle.comeBack();
        async.flushMicrotasks();

        expect(bloc.state, const AppLockLocked(settings: _on5));
      });
    });

    test('a resume before the timeout does not lock', () {
      fakeAsync((async) {
        final states = <AppLockState>[];
        final bloc = startUnlocked(async, states);

        lifecycle.leave();
        async.elapse(const Duration(minutes: 1));
        lifecycle.comeBack();
        async.flushMicrotasks();

        expect(bloc.state, const AppLockUnlocked(settings: _on5));
        expect(states, isEmpty);
      });
    });

    test('the background time does not add up over several short stays', () {
      fakeAsync((async) {
        final states = <AppLockState>[];
        final bloc = startUnlocked(async, states);

        for (var i = 0; i < 3; i++) {
          lifecycle.leave();
          async.elapse(const Duration(minutes: 4));
          lifecycle.comeBack();
          async.flushMicrotasks();
        }

        expect(bloc.state, const AppLockUnlocked(settings: _on5));
      });
    });

    test('immediately locks on any return from the background', () {
      fakeAsync((async) {
        const immediately = AppLockSettings(enabled: true, timeout: AppLockTimeout.immediately);
        when(() => settings.read()).thenAnswer((_) async => immediately);
        final states = <AppLockState>[];
        final bloc = startUnlocked(async, states);

        lifecycle.leave();
        lifecycle.comeBack();
        async.flushMicrotasks();

        expect(bloc.state, const AppLockLocked(settings: immediately));
      });
    });

    test('a system sheet over the app, which only makes it inactive, does not lock', () {
      fakeAsync((async) {
        const immediately = AppLockSettings(enabled: true, timeout: AppLockTimeout.immediately);
        when(() => settings.read()).thenAnswer((_) async => immediately);
        final states = <AppLockState>[];
        final bloc = startUnlocked(async, states);

        lifecycle.go(AppLifecycleState.inactive);
        async.elapse(const Duration(minutes: 20));
        lifecycle.go(AppLifecycleState.resumed);
        async.flushMicrotasks();

        expect(bloc.state, const AppLockUnlocked(settings: immediately));
      });
    });

    test('measures the background by the wall clock, which a suspended timer would not', () {
      fakeAsync((async) {
        final states = <AppLockState>[];
        final bloc = startUnlocked(async, states);

        lifecycle.leave();
        // The clock moves while no timer runs, as on a suspended phone.
        async.elapse(const Duration(minutes: 6));
        expect(bloc.state, const AppLockUnlocked(settings: _on5));
        lifecycle.comeBack();
        async.flushMicrotasks();

        expect(bloc.state, const AppLockLocked(settings: _on5));
      });
    });

    test('never locks while signed out', () {
      fakeAsync((async) {
        final states = <AppLockState>[];
        final bloc = start(async, states);
        states.clear();

        lifecycle.leave();
        async.elapse(const Duration(minutes: 30));
        lifecycle.comeBack();
        async.flushMicrotasks();

        expect(bloc.state, const AppLockUnlocked(settings: _on5));
        expect(states, isEmpty);
      });
    });

    test('a sign-out while in the background leaves nothing to lock on the return', () {
      fakeAsync((async) {
        final states = <AppLockState>[];
        final bloc = startUnlocked(async, states);

        lifecycle.leave();
        bloc.add(const AppLockSignedOut());
        async.elapse(const Duration(minutes: 6));
        lifecycle.comeBack();
        async.flushMicrotasks();

        expect(bloc.state, const AppLockUnlocked(settings: _on5));
      });
    });

    test('when the resume is also past the idle period, the idle sign-out wins and no lock shows', () {
      fakeAsync((async) {
        final states = <AppLockState>[];
        final bloc = startUnlocked(async, states, idleTimeout: const Duration(minutes: 15));

        lifecycle.leave();
        async.elapse(const Duration(minutes: 15));
        lifecycle.comeBack();
        async.flushMicrotasks();
        expect(bloc.state, const AppLockUnlocked(settings: _on5));

        // The idle sign-out that IdleTimeoutObserver fires on the same resume.
        bloc.add(const AppLockSignedOut());
        async.flushMicrotasks();
        expect(states.where((state) => state.coversApp), isEmpty);
      });
    });

    test('without an idle period the long background locks', () {
      fakeAsync((async) {
        final states = <AppLockState>[];
        final bloc = start(async, states, idleTimeout: null)..add(const AppLockSignedIn());
        async.flushMicrotasks();

        lifecycle.leave();
        async.elapse(const Duration(hours: 2));
        lifecycle.comeBack();
        async.flushMicrotasks();

        expect(bloc.state, const AppLockLocked(settings: _on5));
      });
    });

    test('a sign-out removes the lock screen', () {
      fakeAsync((async) {
        final states = <AppLockState>[];
        final bloc = start(async, states)..add(const AppLockSessionRestored());
        async.flushMicrotasks();
        expect(bloc.state.coversApp, isTrue);

        bloc.add(const AppLockSignedOut());
        async.flushMicrotasks();

        expect(bloc.state, const AppLockUnlocked(settings: _on5));
      });
    });
  });

  group('unlock', () {
    AppLockBloc locked(FakeAsync async, List<AppLockState> states) {
      final bloc = start(async, states)..add(const AppLockSessionRestored());
      async.flushMicrotasks();
      states.clear();
      return bloc;
    }

    test('the prompt opens the app', () {
      fakeAsync((async) {
        final states = <AppLockState>[];
        locked(async, states).add(const AppLockUnlockRequested(_prompt));
        async.flushMicrotasks();

        expect(states, const [AppLockAuthenticating(settings: _on5), AppLockUnlocked(settings: _on5)]);
        verify(() => authenticator.authenticate(_prompt)).called(1);
      });
    });

    test('a cancelled prompt keeps the app locked and is not retried', () {
      fakeAsync((async) {
        when(() => authenticator.authenticate(any())).thenAnswer((_) async => const DeviceAuthCancelled());
        final states = <AppLockState>[];
        final bloc = locked(async, states)..add(const AppLockUnlockRequested(_prompt));
        async.flushMicrotasks();
        async.elapse(const Duration(minutes: 1));

        expect(states, const [AppLockAuthenticating(settings: _on5), AppLockLocked(settings: _on5)]);
        expect(bloc.state.coversApp, isTrue);
        verify(() => authenticator.authenticate(any())).called(1);
      });
    });

    test('a failed prompt keeps the app locked and says so', () {
      fakeAsync((async) {
        when(() => authenticator.authenticate(any())).thenAnswer((_) async => const DeviceAuthFailed());
        final states = <AppLockState>[];
        locked(async, states).add(const AppLockUnlockRequested(_prompt));
        async.flushMicrotasks();

        expect(states.last, const AppLockLocked(settings: _on5, failure: AppLockFailure.failed));
        verify(() => authenticator.authenticate(any())).called(1);
      });
    });

    test('too many attempts keep the app locked and say so', () {
      fakeAsync((async) {
        when(() => authenticator.authenticate(any())).thenAnswer((_) async => const DeviceAuthFailed(lockedOut: true));
        final states = <AppLockState>[];
        locked(async, states).add(const AppLockUnlockRequested(_prompt));
        async.flushMicrotasks();

        expect(states.last, const AppLockLocked(settings: _on5, failure: AppLockFailure.lockedOut));
      });
    });

    test('a prompt that throws keeps the app locked as a failure', () {
      fakeAsync((async) {
        when(() => authenticator.authenticate(any())).thenThrow(StateError('no activity'));
        final states = <AppLockState>[];
        locked(async, states).add(const AppLockUnlockRequested(_prompt));
        async.flushMicrotasks();

        expect(states.last, const AppLockLocked(settings: _on5, failure: AppLockFailure.failed));
      });
    });

    test('a second unlock while the prompt is open is dropped', () {
      fakeAsync((async) {
        final answer = Completer<DeviceAuthResult>();
        when(() => authenticator.authenticate(any())).thenAnswer((_) => answer.future);
        final states = <AppLockState>[];
        final bloc = locked(async, states)
          ..add(const AppLockUnlockRequested(_prompt))
          ..add(const AppLockUnlockRequested(_prompt));
        async.flushMicrotasks();
        bloc.add(const AppLockUnlockRequested(_prompt));
        async.flushMicrotasks();

        answer.complete(const DeviceAuthSucceeded());
        async.flushMicrotasks();

        verify(() => authenticator.authenticate(any())).called(1);
        expect(states, const [AppLockAuthenticating(settings: _on5), AppLockUnlocked(settings: _on5)]);
      });
    });

    test('an unlock while not locked does nothing', () {
      fakeAsync((async) {
        final states = <AppLockState>[];
        startUnlocked(async, states).add(const AppLockUnlockRequested(_prompt));
        async.flushMicrotasks();

        verifyNever(() => authenticator.authenticate(any()));
        expect(states, isEmpty);
      });
    });

    test('the device leaving for the PIN screen during the prompt does not lock again on the return', () {
      fakeAsync((async) {
        const immediately = AppLockSettings(enabled: true, timeout: AppLockTimeout.immediately);
        when(() => settings.read()).thenAnswer((_) async => immediately);
        final answer = Completer<DeviceAuthResult>();
        when(() => authenticator.authenticate(any())).thenAnswer((_) => answer.future);
        final states = <AppLockState>[];
        final bloc = locked(async, states)..add(const AppLockUnlockRequested(_prompt));
        async.flushMicrotasks();

        lifecycle.leave();
        async.elapse(const Duration(seconds: 10));
        answer.complete(const DeviceAuthSucceeded());
        async.flushMicrotasks();
        lifecycle.comeBack();
        async.flushMicrotasks();

        expect(bloc.state, const AppLockUnlocked(settings: immediately));
      });
    });

    test('an answer that comes after a sign-out is dropped', () {
      fakeAsync((async) {
        final answer = Completer<DeviceAuthResult>();
        when(() => authenticator.authenticate(any())).thenAnswer((_) => answer.future);
        final states = <AppLockState>[];
        final bloc = locked(async, states)..add(const AppLockUnlockRequested(_prompt));
        async.flushMicrotasks();
        bloc.add(const AppLockSignedOut());
        async.flushMicrotasks();

        answer.complete(const DeviceAuthCancelled());
        async.flushMicrotasks();

        expect(bloc.state, const AppLockUnlocked(settings: _on5));
      });
    });
  });

  group('no screen lock', () {
    test('a lock on a device without a screen lock offers only Sign out', () {
      fakeAsync((async) {
        when(() => authenticator.canAuthenticate()).thenAnswer((_) async => false);
        final states = <AppLockState>[];
        final bloc = start(async, states)..add(const AppLockSessionRestored());
        async.flushMicrotasks();

        expect(bloc.state, const AppLockUnavailable(settings: _on5, reason: AppLockUnavailableReason.noScreenLock));
        expect(bloc.state.coversApp, isTrue);
      });
    });

    test('a prompt that finds no screen lock offers only Sign out', () {
      fakeAsync((async) {
        when(() => authenticator.authenticate(any())).thenAnswer((_) async => const DeviceAuthNoScreenLock());
        final states = <AppLockState>[];
        final bloc = start(async, states)..add(const AppLockSessionRestored());
        async.flushMicrotasks();
        bloc.add(const AppLockUnlockRequested(_prompt));
        async.flushMicrotasks();

        expect(bloc.state, const AppLockUnavailable(settings: _on5, reason: AppLockUnavailableReason.noScreenLock));
      });
    });

    test('a failed check keeps the lock screen with Unlock', () {
      fakeAsync((async) {
        when(() => authenticator.canAuthenticate()).thenThrow(StateError('no activity'));
        final states = <AppLockState>[];
        final bloc = start(async, states)..add(const AppLockSessionRestored());
        async.flushMicrotasks();

        expect(bloc.state, const AppLockLocked(settings: _on5));
      });
    });

    test('coming back after setting a screen lock offers Unlock', () {
      fakeAsync((async) {
        when(() => authenticator.canAuthenticate()).thenAnswer((_) async => false);
        final states = <AppLockState>[];
        final bloc = start(async, states)..add(const AppLockSessionRestored());
        async.flushMicrotasks();

        lifecycle.leave();
        when(() => authenticator.canAuthenticate()).thenAnswer((_) async => true);
        lifecycle.comeBack();
        async.flushMicrotasks();

        expect(bloc.state, const AppLockLocked(settings: _on5));
      });
    });
  });

  group('required by the build', () {
    test('locks a cold start even with the stored switch off', () {
      fakeAsync((async) {
        when(() => settings.read()).thenAnswer((_) async => AppLockSettings.defaults);
        final states = <AppLockState>[];
        final bloc = start(async, states, lockRequired: true)..add(const AppLockSessionRestored());
        async.flushMicrotasks();

        expect(bloc.state, const AppLockLocked(settings: AppLockSettings.defaults));
      });
    });

    test('a turned-off switch from the settings does not turn the lock off', () {
      fakeAsync((async) {
        final states = <AppLockState>[];
        final bloc = start(async, states, lockRequired: true)..add(const AppLockSignedIn());
        async.flushMicrotasks();

        bloc.add(const AppLockSettingsChanged(AppLockSettings.defaults));
        async.flushMicrotasks();

        expect(bloc.state, const AppLockUnlocked(settings: AppLockSettings.defaults));
      });
    });

    test('a sign-in on a device without a screen lock offers only Sign out', () {
      fakeAsync((async) {
        when(() => authenticator.canAuthenticate()).thenAnswer((_) async => false);
        final states = <AppLockState>[];
        final bloc = start(async, states, lockRequired: true)..add(const AppLockSignedIn());
        async.flushMicrotasks();

        expect(bloc.state, const AppLockUnavailable(settings: _on5, reason: AppLockUnavailableReason.noScreenLock));
      });
    });

    test('a sign-in on a device without a screen lock opens when the lock is only the user\'s choice', () {
      fakeAsync((async) {
        when(() => authenticator.canAuthenticate()).thenAnswer((_) async => false);
        final states = <AppLockState>[];
        final bloc = start(async, states)..add(const AppLockSignedIn());
        async.flushMicrotasks();

        expect(bloc.state, const AppLockUnlocked(settings: _on5));
      });
    });
  });

  group('recent-apps preview', () {
    test('hides the preview through the platform switch while the lock is on, and shows it once off', () {
      fakeAsync((async) {
        final states = <AppLockState>[];
        final bloc = startUnlocked(async, states);
        verify(() => recents.setHidden(true)).called(1);

        bloc.add(const AppLockSettingsChanged(AppLockSettings.defaults));
        async.flushMicrotasks();
        verify(() => recents.setHidden(false)).called(1);
      });
    });

    test('leaves the preview alone while the lock is off', () {
      fakeAsync((async) {
        when(() => settings.read()).thenAnswer((_) async => AppLockSettings.defaults);
        final states = <AppLockState>[];
        start(async, states);
        lifecycle.leave();
        lifecycle.comeBack();
        async.flushMicrotasks();

        verifyNever(() => recents.setHidden(any()));
        expect(capturePlatform.calls, isEmpty);
      });
    });

    test('with the platform switch in place takes no screen capture lease in the background', () {
      fakeAsync((async) {
        final states = <AppLockState>[];
        startUnlocked(async, states);

        lifecycle.leave();
        async.flushMicrotasks();

        expect(capture.leases, 0);
        expect(capturePlatform.calls, isEmpty);
      });
    });

    test('without the platform switch, before Android 13, holds a capture lease while away', () {
      fakeAsync((async) {
        when(() => recents.setHidden(any())).thenAnswer((_) async => false);
        final states = <AppLockState>[];
        startUnlocked(async, states);

        lifecycle.go(AppLifecycleState.inactive);
        async.flushMicrotasks();
        expect(capture.leases, 1);
        lifecycle.go(AppLifecycleState.hidden);
        lifecycle.go(AppLifecycleState.paused);
        async.flushMicrotasks();
        expect(capture.leases, 1);

        lifecycle.comeBack();
        async.flushMicrotasks();
        expect(capture.leases, 0);
        expect(capturePlatform.calls, ['on', 'off']);
      });
    });

    test('a failed platform switch is logged and the capture lease covers the preview', () {
      fakeAsync((async) {
        when(() => recents.setHidden(any())).thenThrow(StateError('channel failed'));
        final states = <AppLockState>[];
        startUnlocked(async, states);

        lifecycle.leave();
        async.flushMicrotasks();

        expect(capture.leases, 1);
      });
    });

    test('turning the lock off while away gives the lease back', () {
      fakeAsync((async) {
        when(() => recents.setHidden(any())).thenAnswer((_) async => false);
        final states = <AppLockState>[];
        final bloc = startUnlocked(async, states);
        lifecycle.go(AppLifecycleState.inactive);
        async.flushMicrotasks();
        expect(capture.leases, 1);

        bloc.add(const AppLockSettingsChanged(AppLockSettings.defaults));
        async.flushMicrotasks();

        expect(capture.leases, 0);
      });
    });

    test('closing the bloc gives the lease back', () {
      fakeAsync((async) {
        when(() => recents.setHidden(any())).thenAnswer((_) async => false);
        final states = <AppLockState>[];
        final bloc = startUnlocked(async, states);
        lifecycle.go(AppLifecycleState.inactive);
        async.flushMicrotasks();

        bloc.close();
        async.flushMicrotasks();

        expect(capture.leases, 0);
      });
    });
  });
}
