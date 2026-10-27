import 'package:libredb_mobile/core/logging/app_logger.dart';
import 'package:libredb_mobile/features/onboarding/domain/repositories/onboarding_seen_store.dart';
import 'package:libredb_mobile/infrastructure/storage/local_storage.dart';

/// [IOnboardingSeenStore] over the device's preferences, under [StorageKeys.onboardingSeen].
class OnboardingSeenPreferences implements IOnboardingSeenStore {
  OnboardingSeenPreferences();

  /// The keys a launch stores before anyone has done anything, so holding one is no proof the app has been used.
  ///
  /// `AppBootstrap` writes the default palette on a device that has none. Nothing else is written at launch — the
  /// brightness is deliberately left unset so the theme follows the system, and the language is stored only when the
  /// user picks one.
  ///
  /// `first_run_writes_nothing_test.dart` reads `app_bootstrap.dart` and fails if it writes a key that is not in this
  /// set, so a future launch-time default cannot quietly turn every new device into a returning one.
  static const keysWrittenAtLaunch = {StorageKeys.theme};

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
  /// [keysWrittenAtLaunch] are left out, because a brand-new device holds them before the introduction is decided and
  /// counting them as earlier use takes the introduction away from every new user. That is not hypothetical: it is
  /// what the first version of this rule did, and only running the app on a device caught it.
  @override
  Future<bool> read() async {
    try {
      final storage = AppLocalStorage();
      for (final key in StorageKeys.values) {
        if (keysWrittenAtLaunch.contains(key)) continue;
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
