import 'package:libredb_mobile/core/logging/app_logger.dart';
import 'package:libredb_mobile/features/onboarding/domain/repositories/onboarding_seen_store.dart';
import 'package:libredb_mobile/infrastructure/storage/local_storage.dart';

/// [IOnboardingSeenStore] over the device's preferences, under [StorageKeys.onboardingSeen].
class OnboardingSeenPreferences implements IOnboardingSeenStore {
  OnboardingSeenPreferences();

  static final _log = AppLogger.getLogger('OnboardingSeenPreferences');

  /// Whether this device has anything left to introduce.
  ///
  /// True when the key holds anything — the value itself is not read, so a value an older version or something else
  /// wrote still counts. Showing the introduction twice is worse than not showing it: a returning user meets
  /// something they have already read and nothing tells them why.
  ///
  /// True as well when **any other** preference is stored. This key only started being written in the milestone that
  /// added the introduction, so every device that had the app before that holds nothing under it — and answering
  /// "never shown" there introduces the app to someone who has been using it for months. A signed-in user never
  /// reaches the introduction, because the redirect returns on the authenticated branch first; one who upgrades
  /// while signed out does.
  ///
  /// Reading the other keys this way is only sound because a genuinely fresh first run writes none of them before
  /// the introduction is decided. That is measured, not assumed: `first_run_writes_nothing_test.dart` fails if a
  /// future change writes a default at launch, which would otherwise take the introduction away from every new user
  /// and do it silently.
  @override
  Future<bool> read() async {
    try {
      final storage = AppLocalStorage();
      for (final key in StorageKeys.values) {
        if (await storage.read(key.key) != null) return true;
      }
      return false;
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
