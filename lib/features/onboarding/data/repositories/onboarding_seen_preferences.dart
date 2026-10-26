import 'package:libredb_mobile/core/logging/app_logger.dart';
import 'package:libredb_mobile/features/onboarding/domain/repositories/onboarding_seen_store.dart';
import 'package:libredb_mobile/infrastructure/storage/local_storage.dart';

/// [IOnboardingSeenStore] over the device's preferences, under [StorageKeys.onboardingSeen].
class OnboardingSeenPreferences implements IOnboardingSeenStore {
  OnboardingSeenPreferences();

  static final _log = AppLogger.getLogger('OnboardingSeenPreferences');

  /// Whether anything is stored at the key.
  ///
  /// The value itself is not read. Anything present means the introduction has been shown, including a value an
  /// older version or something else wrote: showing it again is worse than not showing it, because a returning user
  /// meets an introduction they have already read and nothing tells them why.
  @override
  Future<bool> read() async {
    try {
      return await AppLocalStorage().read(StorageKeys.onboardingSeen.key) != null;
    } catch (error) {
      // A device that refuses to answer is treated as having shown it, for the same reason.
      _log.warn('read: the device refused to answer, treating the introduction as shown: {}', [error]);
      return true;
    }
  }

  @override
  Future<void> write() async {
    try {
      await AppLocalStorage().save(StorageKeys.onboardingSeen.key, true);
    } catch (error) {
      // The caller has already moved on: a change the device refuses to store still applies on screen, and the cost
      // of losing this one is that the introduction appears once more.
      _log.warn('write: the device refused to store that the introduction was shown: {}', [error]);
    }
  }
}
