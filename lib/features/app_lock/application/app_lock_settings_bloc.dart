import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/core/logging/app_logger.dart';
import 'package:libredb_mobile/features/app_lock/domain/entities/app_lock_settings.dart';
import 'package:libredb_mobile/features/app_lock/domain/repositories/app_lock_settings_repository.dart';
import 'package:libredb_mobile/features/app_lock/domain/services/device_authenticator.dart';
import 'package:libredb_mobile/shared/utils/event_transformers.dart';

part 'app_lock_settings_event.dart';
part 'app_lock_settings_state.dart';

/// The app lock section of the settings: whether the device can lock, and storing a change of the switch or the
/// timeout; turning the lock on first asks the system prompt.
class AppLockSettingsBloc extends Bloc<AppLockSettingsEvent, AppLockSettingsState> {
  AppLockSettingsBloc({required this._repository, required this._authenticator})
    : super(const AppLockSettingsChecking()) {
    on<AppLockSettingsOpened>(_onOpened);
    // A change waits for the prompt and the write, so a second tap meanwhile would open a second prompt.
    on<AppLockSettingsChangeRequested>(_onChangeRequested, transformer: EventTransformers.dropConcurrent());
  }

  static final _log = AppLogger.getLogger('AppLockSettingsBloc');

  final IAppLockSettingsRepository _repository;
  final IDeviceAuthenticator _authenticator;

  bool get _canAuthenticate => switch (state) {
    AppLockSettingsChecked(:final canAuthenticate) => canAuthenticate,
    AppLockSettingsChecking() => false,
  };

  Future<void> _onOpened(AppLockSettingsOpened event, Emitter<AppLockSettingsState> emit) async {
    bool canAuthenticate;
    try {
      canAuthenticate = await _authenticator.canAuthenticate();
    } catch (e) {
      _log.error('checking whether the device can authenticate failed: {}', [e]);
      canAuthenticate = false;
    }
    emit(AppLockSettingsReady(canAuthenticate: canAuthenticate));
  }

  Future<void> _onChangeRequested(AppLockSettingsChangeRequested event, Emitter<AppLockSettingsState> emit) async {
    var canAuthenticate = _canAuthenticate;
    emit(AppLockSettingsSaving(canAuthenticate: canAuthenticate));
    if (event.next.enabled && !event.current.enabled) {
      final DeviceAuthResult result;
      try {
        result = await _authenticator.authenticate(event.prompt);
      } catch (e) {
        _log.error('the device prompt threw: {}', [e]);
        emit(AppLockSettingsReady(canAuthenticate: canAuthenticate));
        return;
      }
      switch (result) {
        case DeviceAuthSucceeded():
          break;
        case DeviceAuthCancelled() || DeviceAuthFailed():
          emit(AppLockSettingsReady(canAuthenticate: canAuthenticate));
          return;
        case DeviceAuthNoScreenLock():
          emit(const AppLockSettingsReady(canAuthenticate: false));
          return;
      }
      canAuthenticate = true;
    }
    try {
      await _repository.write(event.next);
    } catch (e) {
      _log.error('storing the app lock settings failed: {}', [e]);
      emit(AppLockSettingsFailure(canAuthenticate: canAuthenticate, errorCode: AppErrorCode.settingsAppLockNotSaved));
      return;
    }
    emit(AppLockSettingsSaved(canAuthenticate: canAuthenticate, settings: event.next));
  }
}
