@Tags(['widget'])
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/app/app.dart';
import 'package:libredb_mobile/app/di/mock_sign_in_dependencies.dart';
import 'package:libredb_mobile/features/onboarding/data/repositories/onboarding_seen_preferences.dart';
import 'package:libredb_mobile/infrastructure/storage/local_storage.dart';

import '../support/dart_code.dart';
import '../support/test_env.dart';

/// What a launch stores before the user has done anything, and what the introduction is allowed to read into that.
///
/// `OnboardingSeenPreferences.read()` treats a stored preference as proof this device has used the app before, which
/// is how a user who upgrades while signed out is spared an introduction to software they know. Every key a *launch*
/// writes has to be left out of that, because a brand-new device holds it too.
///
/// This is not hypothetical. The first version of that rule read every key, `AppBootstrap` writes the default palette
/// on a fresh install, and the result was that **no new user would ever have seen the introduction** — with the whole
/// suite green, because every other test starts on a device that has already seen it. Only running the app on a
/// device caught it. These two tests are what stands in for that device from now on.
void main() {
  // The source-level half, and the one that would have caught the defect: a launch-time write this store does not
  // know about fails here, whether or not any test happens to exercise that path.
  test('every key AppBootstrap stores at launch is left out of the introduction signal', () {
    final source = codeOnly(File('lib/app/bootstrap/app_bootstrap.dart').readAsStringSync());
    final saved = RegExp(r'save\(\s*StorageKeys\.(\w+)\.key').allMatches(source).map((m) => m.group(1)!).toSet();

    expect(saved, isNotEmpty, reason: 'the regex stopped matching how the bootstrap stores a key — fix the regex');

    final excluded = OnboardingSeenPreferences.keysWrittenAtLaunch.map((key) => key.name).toSet();
    expect(
      saved.difference(excluded),
      isEmpty,
      reason:
          'AppBootstrap writes these at launch, so a brand-new device holds them before the introduction is decided. '
          'Reading them as earlier use takes the introduction away from every new user, and no other test turns red '
          'when it happens. Add them to OnboardingSeenPreferences.keysWrittenAtLaunch, or stop writing them at launch.',
    );
  });

  // The runtime half: everything above the bootstrap stays quiet too.
  testWidgets('App itself stores nothing before the introduction is decided', (tester) async {
    await TestEnv.onboardingUnseen();
    addTearDown(tester.view.reset);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;

    await tester.pumpWidget(App(dependencies: MockSignInDependencies(), language: 'en'));
    await tester.pumpAndSettle();
    // Past the mocked liveness answers, so anything they trigger has landed too.
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    final storage = AppLocalStorage();
    final written = <String>[];
    for (final key in StorageKeys.values) {
      if (await storage.read(key.key) != null) written.add(key.key);
    }

    expect(written, isEmpty, reason: 'written by App, above the bootstrap, before the introduction was decided');
  });
}
