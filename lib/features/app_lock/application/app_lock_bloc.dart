import 'dart:async';

import 'package:clock/clock.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:libredb_mobile/core/logging/app_logger.dart';
import 'package:libredb_mobile/core/security/screen_capture_protection.dart';
import 'package:libredb_mobile/features/app_lock/domain/entities/app_lock_settings.dart';
import 'package:libredb_mobile/features/app_lock/domain/repositories/app_lock_settings_repository.dart';
import 'package:libredb_mobile/features/app_lock/domain/services/device_authenticator.dart';
import 'package:libredb_mobile/features/app_lock/domain/services/recents_preview.dart';
import 'package:libredb_mobile/shared/utils/app_lifecycle_source.dart';
import 'package:libredb_mobile/shared/utils/event_transformers.dart';

part 'app_lock_event.dart';
part 'app_lock_state.dart';

/// The app lock: asks for the device's biometrics or screen lock on a cold start that restores a session and on a
/// resume after at least the chosen time in the background, and never while nobody is signed in.
///
/// The time in the background is measured by the wall clock between the app leaving the screen (`hidden` or `paused`)
/// and its return, as `IdleTimeoutObserver` measures it, since a timer does not run while the phone suspends the app.
/// When that time also reaches [idleTimeout], the idle sign-out that the same resume fires wins and no lock shows.
///
/// While the lock is on, the recent-apps preview hides the app: through [IRecentsPreview] where the platform has a
/// switch (Android 13 and later), else through a lease of the screen capture protection held while the app is away.
class AppLockBloc extends Bloc<AppLockEvent, AppLockState> {
  AppLockBloc({
    required this._settingsRepository,
    required this._authenticator,
    required IAppLifecycleSource lifecycle,
    required this._recentsPreview,
    required this._captureProtection,
    required this._lockRequired,
    required this._idleTimeout,
  }) : super(const AppLockStarting()) {
    // One at a time and in order, so a session or lifecycle event never acts on settings not read yet.
    on<_AppLockControlEvent>(_onControl, transformer: EventTransformers.queue());
    on<AppLockUnlockRequested>(_onUnlockRequested, transformer: EventTransformers.dropConcurrent());
    _lastLifecycle = lifecycle.current;
    _lifecycle = lifecycle.changes.listen((state) => add(_AppLockLifecycleChanged(state)));
  }

  static final _log = AppLogger.getLogger('AppLockBloc');

  final IAppLockSettingsRepository _settingsRepository;
  final IDeviceAuthenticator _authenticator;
  final IRecentsPreview _recentsPreview;
  final ScreenCaptureProtection _captureProtection;

  /// The build's `APP_LOCK_REQUIRED`: the lock is on whatever the stored switch says.
  final bool _lockRequired;

  /// The idle period after which `IdleTimeoutObserver` signs the user out, null when the build has none.
  final Duration? _idleTimeout;

  late final StreamSubscription<AppLifecycleState> _lifecycle;

  /// The lifecycle state before the one being handled.
  AppLifecycleState? _lastLifecycle;

  AppLockSettings _settings = AppLockSettings.defaults;
  bool _signedIn = false;

  /// When the app left the screen while signed in and open, null while it is on screen.
  DateTime? _backgroundedAt;

  /// Whether the platform switch hides the preview now, so no capture lease is needed.
  bool _previewHiddenByPlatform = false;

  /// Whether this bloc holds a lease of the screen capture protection, which covers the preview while away.
  bool _holdsLease = false;

  /// Whether the lock is on: the user turned it on, or the build requires it.
  bool get _isOn => _lockRequired || _settings.enabled;

  /// Off or unlocked, as the settings say, with nothing covering the app.
  AppLockSettled get _open => _isOn ? AppLockUnlocked(settings: _settings) : AppLockOff(settings: _settings);

  Future<void> _onControl(_AppLockControlEvent event, Emitter<AppLockState> emit) => switch (event) {
    AppLockStarted() => _onStarted(emit),
    AppLockSessionRestored() => _onSessionRestored(emit),
    AppLockSignedIn() => _onSignedIn(emit),
    AppLockSignedOut() => _onSignedOut(emit),
    AppLockSettingsChanged(:final settings) => _onSettingsChanged(settings, emit),
    _AppLockLifecycleChanged(:final state) => _onLifecycleChanged(state, emit),
  };

  Future<void> _onStarted(Emitter<AppLockState> emit) async {
    try {
      _settings = await _settingsRepository.read();
    } catch (e) {
      // The lock protects data, so settings that cannot be read keep it on rather than drop it.
      _log.error('the stored app lock settings cannot be read, so the lock stays on: {}', [e]);
      _settings = AppLockSettings.defaults.copyWith(enabled: true);
    }
    // A restore that arrived while the settings were read locks at once, with no open state between.
    if (_restorePending && _isOn) {
      emit(AppLockLocked(settings: _settings));
    } else {
      emit(_open);
    }
    // The preview shows by default, so only a lock that is on needs the switch. Off the queue, so a slow platform
    // answer never holds back the session event behind it.
    if (_isOn) _schedulePreview();
  }

  /// Whether a restored session waits in the queue, recorded when the event is added so the settings read can act on
  /// it.
  bool _restorePending = false;

  @override
  void onEvent(AppLockEvent event) {
    super.onEvent(event);
    switch (event) {
      case AppLockSessionRestored():
        _restorePending = true;
      case AppLockSignedIn() || AppLockSignedOut():
        _restorePending = false;
      case _:
        break;
    }
  }

  Future<void> _onSessionRestored(Emitter<AppLockState> emit) async {
    _restorePending = false;
    _signedIn = true;
    _backgroundedAt = null;
    if (!_isOn) return;
    _log.info('a cold start restored the session: locked');
    await _lock(emit);
  }

  Future<void> _onSignedIn(Emitter<AppLockState> emit) async {
    _signedIn = true;
    _backgroundedAt = null;
    if (!_lockRequired) return emit(_open);
    emit(AppLockChecking(settings: _settings));
    // A required lock cannot let anyone in on a device that cannot lock, nor on one it could not check.
    emit(switch (await _canAuthenticate()) {
      true => _open,
      false => AppLockUnavailable(settings: _settings, reason: AppLockUnavailableReason.noScreenLock),
      null => AppLockLocked(settings: _settings, failure: AppLockFailure.checkFailed),
    });
  }

  Future<void> _onSignedOut(Emitter<AppLockState> emit) async {
    _signedIn = false;
    _backgroundedAt = null;
    emit(_open);
  }

  Future<void> _onSettingsChanged(AppLockSettings settings, Emitter<AppLockState> emit) async {
    final wasOn = _isOn;
    _settings = settings;
    if (!_isOn) _backgroundedAt = null;
    emit(switch (state) {
      AppLockLocked(:final failure) when _isOn => AppLockLocked(settings: settings, failure: failure),
      AppLockAuthenticating() when _isOn => AppLockAuthenticating(settings: settings),
      AppLockUnavailable(:final reason) when _isOn => AppLockUnavailable(settings: settings, reason: reason),
      _ => _open,
    });
    if (wasOn != _isOn) _schedulePreview();
  }

  Future<void> _onLifecycleChanged(AppLifecycleState lifecycle, Emitter<AppLockState> emit) async {
    final previous = _lastLifecycle;
    _lastLifecycle = lifecycle;
    _coverPreview(lifecycle);
    if (isInBackground(lifecycle)) {
      // Counted from the moment the app leaves the screen, not from the `hidden` that Flutter also reports on the way
      // back. Only an open lock counts the time away: a lock screen stays, and the PIN screen of a prompt is not away.
      final leaving = !isInBackground(previous);
      if (leaving && _isOn && _signedIn && state is AppLockUnlocked) _backgroundedAt ??= clock.now();
      return;
    }
    if (lifecycle != AppLifecycleState.resumed) return;
    if (state is AppLockUnavailable) return _recheckScreenLock(emit);
    final backgroundedAt = _backgroundedAt;
    _backgroundedAt = null;
    if (backgroundedAt == null || state is! AppLockUnlocked) return;
    final away = clock.now().difference(backgroundedAt);
    final idleTimeout = _idleTimeout;
    if (idleTimeout != null && away >= idleTimeout) {
      _log.info('resumed after {}s away, past the idle period: the idle sign-out ends the session, no lock', [
        away.inSeconds,
      ]);
      return emit(AppLockIdleSigningOut(settings: _settings));
    }
    if (away < _settings.timeout.duration) return;
    _log.info('resumed after {}s away, past the {}s lock timeout: locked', [
      away.inSeconds,
      _settings.timeout.duration.inSeconds,
    ]);
    await _lock(emit);
  }

  /// Covers the app, then checks that the device can open the lock: one without a screen lock offers only Sign out.
  Future<void> _lock(Emitter<AppLockState> emit) async {
    emit(AppLockLocked(settings: _settings));
    final canAuthenticate = await _canAuthenticate();
    if (state is! AppLockLocked) return;
    switch (canAuthenticate) {
      case true:
        break;
      case false:
        emit(AppLockUnavailable(settings: _settings, reason: AppLockUnavailableReason.noScreenLock));
      case null:
        emit(AppLockLocked(settings: _settings, failure: AppLockFailure.checkFailed));
    }
  }

  /// Offers Unlock again once the user has set a screen lock and come back.
  Future<void> _recheckScreenLock(Emitter<AppLockState> emit) async {
    if (await _canAuthenticate() == true && state is AppLockUnavailable) emit(AppLockLocked(settings: _settings));
  }

  /// Whether the device can authenticate, or null when the check failed, which is logged and never opens the app.
  Future<bool?> _canAuthenticate() async {
    try {
      return await _authenticator.canAuthenticate();
    } catch (e) {
      _log.error('checking whether the device can authenticate failed: {}', [e]);
      return null;
    }
  }

  Future<void> _onUnlockRequested(AppLockUnlockRequested event, Emitter<AppLockState> emit) async {
    if (state is! AppLockLocked) return;
    emit(AppLockAuthenticating(settings: _settings));
    DeviceAuthResult result;
    try {
      result = await _authenticator.authenticate(event.prompt);
    } catch (e) {
      _log.error('the device prompt threw: {}', [e]);
      result = const DeviceAuthFailed();
    }
    // A sign-out meanwhile has removed the lock screen, which this answer must not bring back.
    if (state is! AppLockAuthenticating) return;
    emit(switch (result) {
      DeviceAuthSucceeded() => AppLockUnlocked(settings: _settings),
      DeviceAuthCancelled() => AppLockLocked(settings: _settings),
      DeviceAuthFailed(lockedOut: false) => AppLockLocked(settings: _settings, failure: AppLockFailure.failed),
      DeviceAuthFailed(lockedOut: true) => AppLockLocked(settings: _settings, failure: AppLockFailure.lockedOut),
      DeviceAuthNoScreenLock() => AppLockUnavailable(
        settings: _settings,
        reason: AppLockUnavailableReason.noScreenLock,
      ),
    });
  }

  /// The preview switches in flight, one after another, so they apply in the order the lock changed.
  Future<void> _previewQueue = Future<void>.value();

  void _schedulePreview() => _previewQueue = _previewQueue.then((_) => _applyPreview());

  /// Hides the preview through the platform switch while the lock is on, and shows it again once off.
  Future<void> _applyPreview() async {
    final hide = _isOn;
    try {
      _previewHiddenByPlatform = await _recentsPreview.setHidden(hide) && hide;
    } catch (e) {
      _log.error('the recent-apps preview switch failed, a capture lease covers the preview instead: {}', [e]);
      _previewHiddenByPlatform = false;
    }
    if (!hide || _previewHiddenByPlatform) _releaseLease();
  }

  /// Without the platform switch, holds a capture lease from the moment the app starts to leave the screen
  /// (`inactive`, before the system takes the preview) until it is back.
  void _coverPreview(AppLifecycleState lifecycle) {
    if (lifecycle == AppLifecycleState.resumed) return _releaseLease();
    if (!_isOn || _previewHiddenByPlatform || _holdsLease) return;
    _holdsLease = true;
    unawaited(_captureProtection.acquire());
  }

  void _releaseLease() {
    if (!_holdsLease) return;
    _holdsLease = false;
    unawaited(_captureProtection.release());
  }

  @override
  Future<void> close() async {
    _releaseLease();
    await _lifecycle.cancel();
    return super.close();
  }
}
