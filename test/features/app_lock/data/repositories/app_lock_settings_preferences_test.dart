import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/features/app_lock/data/repositories/app_lock_settings_preferences.dart';
import 'package:libredb_mobile/features/app_lock/domain/entities/app_lock_settings.dart';
import 'package:libredb_mobile/infrastructure/storage/local_storage.dart';

void main() {
  test('reads the defaults, off and five minutes, on a device that stored nothing', () async {
    expect(await AppLockSettingsPreferences().read(), AppLockSettings.defaults);
    expect(AppLockSettings.defaults, const AppLockSettings(enabled: false, timeout: AppLockTimeout.fiveMinutes));
  });

  test('keeps the settings as device preferences, outliving the session, and reads them back', () async {
    await AppLockSettingsPreferences().write(
      const AppLockSettings(enabled: true, timeout: AppLockTimeout.fifteenMinutes),
    );

    expect(
      await AppLockSettingsPreferences().read(),
      const AppLockSettings(enabled: true, timeout: AppLockTimeout.fifteenMinutes),
    );
    expect(await AppLocalStorage().read(StorageKeys.appLockEnabled.key), true);
    expect(await AppLocalStorage().read(StorageKeys.appLockTimeout.key), 'fifteenMinutes');
    expect(StorageKeys.appLockEnabled.key, 'app_lock_enabled');
    expect(StorageKeys.appLockTimeout.key, 'app_lock_timeout');
    expect(StorageKeys.appLockEnabled.scope, StorageScope.device);
    expect(StorageKeys.appLockTimeout.scope, StorageScope.device);
  });

  test('reads every timeout back', () async {
    for (final timeout in AppLockTimeout.values) {
      await AppLockSettingsPreferences().write(AppLockSettings(enabled: false, timeout: timeout));

      expect((await AppLockSettingsPreferences().read()).timeout, timeout);
    }
  });

  test('a stored switch without a timeout reads the default timeout', () async {
    await AppLocalStorage().save(StorageKeys.appLockEnabled.key, true);

    expect(
      await AppLockSettingsPreferences().read(),
      const AppLockSettings(enabled: true, timeout: AppLockTimeout.fiveMinutes),
    );
  });

  test('throws a FormatException for a stored switch that is not a bool', () async {
    await AppLocalStorage().save(StorageKeys.appLockEnabled.key, 'yes');

    expect(AppLockSettingsPreferences().read, throwsFormatException);
  });

  test('throws a FormatException for a stored timeout that is not a timeout', () async {
    await AppLocalStorage().save(StorageKeys.appLockTimeout.key, 'tenMinutes');

    expect(AppLockSettingsPreferences().read, throwsFormatException);
  });

  test('throws a FormatException for a stored timeout that is not a string', () async {
    await AppLocalStorage().save(StorageKeys.appLockTimeout.key, 5);

    expect(AppLockSettingsPreferences().read, throwsFormatException);
  });

  test('throws when the device refuses the write', () async {
    expect(
      () => AppLockSettingsPreferences(storage: _RefusingStorage()).write(AppLockSettings.defaults),
      throwsStateError,
    );
  });
}

class _RefusingStorage implements AppLocalStorage {
  @override
  Future<bool> save(String key, dynamic value) async => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
