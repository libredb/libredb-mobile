import 'package:libredb_mobile/features/app_lock/domain/entities/app_lock_settings.dart';

/// The app lock settings of this device, the same for every account: a sign-out keeps them.
abstract interface class IAppLockSettingsRepository {
  /// The stored settings, or [AppLockSettings.defaults] when none are stored; throws a [FormatException] when a stored
  /// value cannot be read.
  Future<AppLockSettings> read();

  /// Stores [settings]; throws when the device refuses the write.
  Future<void> write(AppLockSettings settings);
}
