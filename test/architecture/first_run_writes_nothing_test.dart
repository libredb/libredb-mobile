@Tags(['widget'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/app/app.dart';
import 'package:libredb_mobile/app/di/mock_sign_in_dependencies.dart';
import 'package:libredb_mobile/infrastructure/storage/local_storage.dart';

import '../support/test_env.dart';

/// A fresh first run stores nothing until the user does something.
///
/// `OnboardingSeenPreferences.read()` treats **any** stored preference as proof that this device has used the app
/// before, which is how a user who upgrades while signed out is spared an introduction to software they already know.
/// That reading is only sound while a genuinely fresh launch writes none of those keys before the introduction is
/// decided.
///
/// So this is the test that holds the other end of that rule. Write a default at launch — a language, a theme, a view
/// mode, an app-lock setting — and the introduction silently stops appearing for every new user, with every other
/// test in the repository still green, because they all start on a device that has already seen it. This one starts
/// on a device that has not.
void main() {
  testWidgets('a cold start writes no preference before the introduction is decided', (tester) async {
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

    expect(
      written,
      isEmpty,
      reason:
          'A default written at launch makes every device look like a returning one, and the introduction stops '
          'appearing for new users without a single other test turning red. If the write is deliberate, the rule in '
          'OnboardingSeenPreferences.read() has to change with it.',
    );
  });
}
