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
}
