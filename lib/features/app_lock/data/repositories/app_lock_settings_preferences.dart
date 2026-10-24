import 'package:libredb_mobile/features/app_lock/domain/entities/app_lock_settings.dart';
import 'package:libredb_mobile/features/app_lock/domain/repositories/app_lock_settings_repository.dart';
import 'package:libredb_mobile/infrastructure/storage/local_storage.dart';

/// Keeps the app lock settings in the device preferences, under [StorageKeys.appLockEnabled] as a bool and
/// [StorageKeys.appLockTimeout] as the timeout's name.
///
/// Device settings: no sign-out removes them, and every account on the device shares them.
class AppLockSettingsPreferences implements IAppLockSettingsRepository {
  AppLockSettingsPreferences({AppLocalStorage? storage}) : _storage = storage ?? AppLocalStorage();

  final AppLocalStorage _storage;

  static final _enabledKey = StorageKeys.appLockEnabled.key;
  static final _timeoutKey = StorageKeys.appLockTimeout.key;

  @override
  Future<AppLockSettings> read() async {
    final enabled = await _storage.read(_enabledKey);
    if (enabled != null && enabled is! bool) {
      throw FormatException('$_enabledKey is not a bool: ${enabled.runtimeType}');
    }
    return AppLockSettings(
      enabled: enabled as bool? ?? AppLockSettings.defaults.enabled,
      timeout: _timeoutOf(await _storage.read(_timeoutKey)),
    );
  }

  static AppLockTimeout _timeoutOf(Object? stored) {
    if (stored == null) return AppLockSettings.defaults.timeout;
    if (stored is! String) throw FormatException('$_timeoutKey is not a string: ${stored.runtimeType}');
    for (final timeout in AppLockTimeout.values) {
      if (timeout.name == stored) return timeout;
    }
    throw FormatException('$_timeoutKey is not a timeout: $stored');
  }

  @override
  Future<void> write(AppLockSettings settings) async {
    if (!await _storage.save(_timeoutKey, settings.timeout.name)) {
      throw StateError('the device refused to store $_timeoutKey');
    }
    if (!await _storage.save(_enabledKey, settings.enabled)) {
      throw StateError('the device refused to store $_enabledKey');
    }
  }
}
