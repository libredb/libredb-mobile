@Tags(['widget'])
library;

import 'package:flutter/material.dart';
import 'package:libredb_mobile/app/di/local_sign_in_dependencies.dart';
import 'package:libredb_mobile/app/router/app_routes_constants.dart';
import 'package:libredb_mobile/app/shell/sign_out_progress_barrier.dart';
import 'package:libredb_mobile/app/shell/top_bar/top_bar_widget.dart';
import 'package:libredb_mobile/features/auth/presentation/pages/login_page.dart';
import 'package:libredb_mobile/features/settings/presentation/pages/settings_screen.dart';
import 'package:libredb_mobile/app/app.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../support/test_env.dart';
import '../../../support/user_menu.dart';

void main() {
  GoRouter routerOf(WidgetTester tester) =>
      tester.widget<MaterialApp>(find.byType(MaterialApp)).routerConfig! as GoRouter;

  // The real app, signed in, on the connection list, after the mock API has answered.
  Future<void> pumpSignedIn(
    WidgetTester tester, {
    Size size = const Size(1600, 1600),
    String language = 'en',
    double textScale = 1.0,
  }) async {
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    TestEnv.authenticate();

    await tester.pumpWidget(App(dependencies: LocalSignInDependencies(), language: language));
    await tester.pumpAndSettle();
  }

  Finder userMenu() => find.descendant(of: find.byType(TopBarWidget), matching: find.byType(PopupMenuButton<String>));

  group('TopBarWidget - user menu', () {
    testWidgets('Settings opens /settings in place of the connection list', (tester) async {
      await pumpSignedIn(tester);

      await selectFromUserMenu(tester, Icons.settings_outlined);

      expect(routerOf(tester).state.uri.path, ApplicationRoutesConstants.settings);
      expect(find.byType(SettingsScreen), findsOneWidget);
      expect(routerOf(tester).canPop(), isFalse, reason: 'a menu entry replaces the page instead of stacking on it');
    });

    testWidgets('Logout signs the user out and opens the login page with no signed-in page to go back to', (
      tester,
    ) async {
      await pumpSignedIn(tester);

      await selectFromUserMenu(tester, Icons.logout);
      await tester.tap(find.widgetWithText(FilledButton, 'Yes'));
      await tester.pumpAndSettle();

      expect(routerOf(tester).state.uri.path, ApplicationRoutesConstants.login);
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(routerOf(tester).canPop(), isFalse);
    });
  });

  group('TopBarWidget - sign-out progress', () {
    testWidgets('the signed-in shell sits under the sign-out progress barrier', (tester) async {
      await pumpSignedIn(tester);

      expect(
        find.ancestor(of: find.byType(TopBarWidget), matching: find.byType(SignOutProgressBarrier)),
        findsOneWidget,
      );
    });
  });

  group('TopBarWidget - Turkish', () {
    testWidgets('the user menu shows its entries in Turkish', (tester) async {
      await pumpSignedIn(tester, language: 'tr');

      await tester.tap(userMenu());
      await tester.pumpAndSettle();

      for (final label in ['Ayarlar', 'Çıkış Yap']) {
        expect(find.widgetWithText(PopupMenuItem<String>, label), findsOneWidget, reason: label);
      }
    });
  });

  group('TopBarWidget - phone width', () {
    // The narrowest phones, at the default text size and with the system text size raised to 130 percent, in both app
    // languages.
    for (final language in const ['en', 'tr']) {
      for (final textScale in const [1.0, 1.3]) {
        for (final size in const [Size(320, 568), Size(360, 640), Size(375, 667)]) {
          testWidgets('the signed-in top bar fits a ${size.width.toInt()}x${size.height.toInt()} phone at text scale '
              '$textScale in $language', (tester) async {
            await pumpSignedIn(tester, size: size, language: language, textScale: textScale);

            expect(tester.takeException(), isNull);
            expect(
              tester.getRect(userMenu()).right,
              lessThanOrEqualTo(tester.getRect(find.byType(TopBarWidget)).right),
            );
          });
        }
      }
    }

    // A screen reader user has to know what the bare user menu icon does, in the language of the app.
    for (final language in const ['en', 'tr']) {
      testWidgets('the user menu button is announced with the menu tooltip in $language', (tester) async {
        final semantics = tester.ensureSemantics();
        await pumpSignedIn(tester, size: const Size(360, 640), language: language);

        final label = MaterialLocalizations.of(tester.element(userMenu())).showMenuTooltip;
        final button = find.descendant(of: userMenu(), matching: find.byType(IconButton));
        expect(tester.getSemantics(button), isSemantics(tooltip: label, isButton: true, hasTapAction: true));
        semantics.dispose();
      });
    }

    // A page title much longer than any of the app's, on the narrowest phone.
    testWidgets('a long page title is shortened instead of overflowing a 320 px bar', (tester) async {
      addTearDown(tester.view.reset);
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      const title = 'A page title far longer than the narrowest phone has room for';

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.delegate.supportedLocales,
          home: const Scaffold(body: TopBarWidget(title: title)),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(tester.getRect(userMenu()).right, lessThanOrEqualTo(320));
      expect(find.text(title), findsOneWidget);
    });
  });
}
