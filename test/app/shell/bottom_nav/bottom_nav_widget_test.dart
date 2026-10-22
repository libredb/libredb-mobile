@Tags(['widget'])
library;

import 'package:flutter/material.dart';
import 'package:libredb_mobile/app/router/app_routes_constants.dart';
import 'package:libredb_mobile/features/connections/presentation/pages/connection_list_page.dart';
import 'package:libredb_mobile/features/settings/presentation/pages/settings_screen.dart';
import 'package:libredb_mobile/app/app.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../support/test_env.dart';

void main() {
  GoRouter routerOf(WidgetTester tester) =>
      tester.widget<MaterialApp>(find.byType(MaterialApp)).routerConfig! as GoRouter;

  Finder inBottomNav(String label) => find.descendant(of: find.byType(NavigationBar), matching: find.text(label));

  // The real app on a phone, signed in, on [location].
  Future<void> pumpSignedInOnPhone(WidgetTester tester, {String location = ApplicationRoutesConstants.home}) async {
    addTearDown(tester.view.reset);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    TestEnv.authenticate();

    await tester.pumpWidget(const App(language: 'en'));
    await tester.pumpAndSettle();
    routerOf(tester).go(location);
    await tester.pumpAndSettle();
  }

  group('BottomNavWidget', () {
    testWidgets('tapping Settings opens /settings in place of the connection list', (tester) async {
      await pumpSignedInOnPhone(tester);

      await tester.tap(inBottomNav('Settings'));
      await tester.pumpAndSettle();

      expect(routerOf(tester).state.uri.path, ApplicationRoutesConstants.settings);
      expect(find.byType(SettingsScreen), findsOneWidget);
      expect(routerOf(tester).canPop(), isFalse, reason: 'a destination replaces the page instead of stacking on it');
    });

    testWidgets('tapping Connections opens the connection list in place of settings', (tester) async {
      await pumpSignedInOnPhone(tester, location: ApplicationRoutesConstants.settings);

      await tester.tap(inBottomNav('Connections'));
      await tester.pumpAndSettle();

      expect(routerOf(tester).state.uri.path, ApplicationRoutesConstants.connectionList);
      expect(find.byType(ConnectionListPage), findsOneWidget);
      expect(routerOf(tester).canPop(), isFalse, reason: 'a destination replaces the page instead of stacking on it');
    });

    testWidgets('marks the destination of the open page', (tester) async {
      await pumpSignedInOnPhone(tester, location: ApplicationRoutesConstants.settings);

      expect(tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex, 1);
    });
  });
}
