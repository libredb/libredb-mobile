@Tags(['widget'])
library;

import 'package:flutter/material.dart';
import 'package:libredb_mobile/app/app.dart';
import 'package:libredb_mobile/app/di/mock_sign_in_dependencies.dart';
import 'package:libredb_mobile/infrastructure/storage/local_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_env.dart';

/// Issue #409: while the user has picked no language, the app follows the phone — not only at the first launch.
///
/// A Turkish speaker who installs the app on an English phone, then switches the phone to Turkish and comes back,
/// used to stay in English until the process was killed: the phone was read once at bootstrap, and Android does not
/// recreate the activity on a language change (`android:configChanges` carries `locale`). These two tests are about
/// the running app, so each flips the phone's languages under a mounted tree.
void main() {
  Finder inBottomNav(String label) => find.descendant(of: find.byType(NavigationBar), matching: find.text(label));

  // The real app on a signed-in phone, in [language]: what AppBootstrap resolved from the phone at startup.
  Future<void> pumpApp(WidgetTester tester, {String language = 'en'}) async {
    addTearDown(tester.view.reset);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    TestEnv.authenticate();

    await tester.pumpWidget(App(dependencies: MockSignInDependencies(), language: language));
    await tester.pumpAndSettle();
  }

  Future<void> setPhoneLanguages(WidgetTester tester, List<Locale> locales) async {
    tester.platformDispatcher.localesTestValue = locales;
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    await tester.pumpAndSettle();
  }

  group('the phone language while the app is running', () {
    testWidgets('moves the app to Turkish when the phone goes Turkish and no language is stored', (tester) async {
      await pumpApp(tester);
      expect(inBottomNav('Connections'), findsOneWidget, reason: 'the English phone it started on');

      await setPhoneLanguages(tester, const [Locale('tr', 'TR')]);

      expect(inBottomNav('Bağlantılar'), findsOneWidget);
      expect(inBottomNav('Connections'), findsNothing);
    });

    testWidgets('leaves the app in the language the user picked when the phone goes Turkish', (tester) async {
      await AppLocalStorage().save(StorageKeys.language.key, 'en');
      await pumpApp(tester);
      expect(inBottomNav('Connections'), findsOneWidget);

      await setPhoneLanguages(tester, const [Locale('tr', 'TR')]);

      expect(inBottomNav('Connections'), findsOneWidget);
      expect(inBottomNav('Bağlantılar'), findsNothing);
    });
  });
}
