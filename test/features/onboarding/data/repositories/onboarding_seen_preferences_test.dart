import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/features/onboarding/data/repositories/onboarding_seen_preferences.dart';
import 'package:libredb_mobile/infrastructure/storage/local_storage.dart';

import '../../../../support/test_env.dart';

/// Whether this device has shown the introduction, which decides what a cold start opens on.
///
/// It is a device preference, not a session one. Onboarding runs **before** anyone signs in, so there is no account
/// to key it to; the next person to pick up the phone has seen it too, and a sign-out must not bring it back.
void main() {
  late OnboardingSeenPreferences store;

  // Every test in the repository starts on a device that has already shown the introduction (the bootstrap sets the
  // flag, so assertions written before the introduction existed stay true). This file is about the store itself, so
  // it starts where a store starts: on a device that has shown nothing.
  setUp(() async {
    await TestEnv.onboardingUnseen();
    store = OnboardingSeenPreferences();
  });

  group('read', () {
    test('is false on a device that has never shown it', () async {
      expect(await store.read(), isFalse);
    });

    test('is true once it has been marked', () async {
      await store.write();
      expect(await store.read(), isTrue);
    });

    test('is false again after the stored value is cleared, as a reinstall leaves it', () async {
      await store.write();
      await AppLocalStorage().clear();
      expect(await store.read(), isFalse);
    });

    test('is true rather than false when the stored value is not a bool', () async {
      // A value written by an older version, or by something else, must not trap a returning user in the
      // introduction on every launch. Anything present at this key means it has been shown.
      await AppLocalStorage().save(StorageKeys.onboardingSeen.key, 'yes');
      expect(await store.read(), isTrue);
    });
  });

  group('write', () {
    test('is idempotent, because a second pass through the flow is not an error', () async {
      await store.write();
      await store.write();
      expect(await store.read(), isTrue);
    });

    test('stores under the key the registry classifies', () async {
      await store.write();
      expect(await AppLocalStorage().read(StorageKeys.onboardingSeen.key), isNotNull);
    });
  });

  test('the key belongs to the device, so a sign-out does not bring the introduction back', () {
    expect(StorageKeys.onboardingSeen.scope, StorageScope.device);
  });

  /// A device that used the app before this flag existed has no first run left to introduce.
  ///
  /// The flag only started being written in the milestone that added the introduction. Every device that had the app
  /// before that has no value under the key, so reading the key alone answers "never shown" for a user who has been
  /// using the app for months. A signed-in user never reaches the introduction — the redirect's authenticated branch
  /// returns first — but one who upgrades while signed out does, and is introduced to an app they know.
  ///
  /// Any other LibreDB preference is proof of that earlier use. It is only safe to read it that way because a
  /// genuinely fresh first run writes nothing before the introduction is decided, which `first_run_writes_nothing`
  /// in `test/architecture/` pins rather than assumes.
  group('a device that was used before the flag existed', () {
    for (final key in [
      StorageKeys.activeConnection,
      StorageKeys.connectionFavorites,
      StorageKeys.language,
      StorageKeys.appLockEnabled,
    ]) {
      test('${key.key} counts as the introduction having been shown', () async {
        await AppLocalStorage().save(key.key, 'something');

        expect(await store.read(), isTrue);
      });
    }

    test('an empty device is still a first run', () async {
      expect(await store.read(), isFalse);
    });

    // AppBootstrap writes the default palette before anything else on a fresh install (app_bootstrap.dart), so on a
    // brand-new device this key is already set when the introduction is decided. Counting it as earlier use takes the
    // introduction away from every new user — which is exactly what it did, and only the emulator caught it.
    test('a device holding only the palette the bootstrap writes at launch is still a first run', () async {
      await AppLocalStorage().save(StorageKeys.theme.key, 'classic');

      expect(await store.read(), isFalse);
    });

    test('but a palette beside something the user did is earlier use', () async {
      await AppLocalStorage().save(StorageKeys.theme.key, 'classic');
      await AppLocalStorage().save(StorageKeys.activeConnection.key, 'seed:pg');

      expect(await store.read(), isTrue);
    });

    test('and the flag itself still answers on a device that holds nothing else', () async {
      await store.write();

      expect(await store.read(), isTrue);
    });
  });
}
