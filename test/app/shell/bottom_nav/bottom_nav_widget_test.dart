@Tags(['widget'])
library;

import 'package:flutter/material.dart';
import 'package:libredb_mobile/app/di/mock_sign_in_dependencies.dart';
import 'package:libredb_mobile/app/router/app_routes_constants.dart';
import 'package:libredb_mobile/features/connections/presentation/pages/connection_list_page.dart';
import 'package:libredb_mobile/features/object_browser/presentation/pages/browse_page.dart';
import 'package:libredb_mobile/features/sql_editor/presentation/pages/sql_page.dart';
import 'package:libredb_mobile/app/app.dart';
import 'package:libredb_mobile/shared/models/session_target.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../support/test_env.dart';

void main() {
  GoRouter routerOf(WidgetTester tester) =>
      tester.widget<MaterialApp>(find.byType(MaterialApp)).routerConfig! as GoRouter;

  Finder inBottomNav(String label) => find.descendant(of: find.byType(NavigationBar), matching: find.text(label));

  // The real app on a phone, signed in, on [location].
  Future<void> pumpSignedInOnPhone(
    WidgetTester tester, {
    String location = ApplicationRoutesConstants.home,
    String language = 'en',
  }) async {
    addTearDown(tester.view.reset);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    TestEnv.authenticate();

    await tester.pumpWidget(App(dependencies: MockSignInDependencies(), language: language));
    await tester.pumpAndSettle();
    routerOf(tester).go(location);
    await tester.pumpAndSettle();
  }

  group('BottomNavWidget', () {
    testWidgets('shows the three tabs Connections, Browse and SQL, in that order', (tester) async {
      await pumpSignedInOnPhone(tester);

      final labels = tester
          .widget<NavigationBar>(find.byType(NavigationBar))
          .destinations
          .map((destination) => (destination as NavigationDestination).label)
          .toList();
      expect(labels, ['Connections', 'Browse', 'SQL']);
    });

    testWidgets('shows the tabs in Turkish', (tester) async {
      await pumpSignedInOnPhone(tester, language: 'tr');

      for (final label in ['Bağlantılar', 'Gözat', 'SQL']) {
        expect(inBottomNav(label), findsOneWidget, reason: label);
      }
    });

    for (final (label, location, page) in <(String, String, Type)>[
      ('Browse', ApplicationRoutesConstants.browse, BrowsePage),
      ('SQL', ApplicationRoutesConstants.sql, SqlPage),
    ]) {
      testWidgets('tapping $label opens $location in place of the connection list', (tester) async {
        await pumpSignedInOnPhone(tester);

        await tester.tap(inBottomNav(label));
        await tester.pumpAndSettle();

        expect(routerOf(tester).state.uri.path, location);
        expect(find.byType(page), findsOneWidget);
        expect(routerOf(tester).canPop(), isFalse, reason: 'a destination replaces the page instead of stacking on it');
      });
    }

    testWidgets('tapping Connections opens the connection list in place of Browse', (tester) async {
      await pumpSignedInOnPhone(tester, location: ApplicationRoutesConstants.browse);

      await tester.tap(inBottomNav('Connections'));
      await tester.pumpAndSettle();

      expect(routerOf(tester).state.uri.path, ApplicationRoutesConstants.connectionList);
      expect(find.byType(ConnectionListPage), findsOneWidget);
      expect(routerOf(tester).canPop(), isFalse, reason: 'a destination replaces the page instead of stacking on it');
    });

    for (final (location, index) in const [
      (ApplicationRoutesConstants.connectionList, 0),
      (ApplicationRoutesConstants.browse, 1),
      (ApplicationRoutesConstants.sql, 2),
    ]) {
      testWidgets('marks the destination of $location', (tester) async {
        await pumpSignedInOnPhone(tester, location: location);

        expect(tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex, index);
      });
    }

    for (final location in const [ApplicationRoutesConstants.browse, ApplicationRoutesConstants.sql]) {
      testWidgets('$location asks to pick a connection first and offers the connection list', (tester) async {
        await pumpSignedInOnPhone(tester, location: location);

        expect(find.text('Pick a connection first'), findsOneWidget);

        await tester.tap(find.widgetWithText(FilledButton, 'Connections'));
        await tester.pumpAndSettle();

        expect(routerOf(tester).state.uri.path, ApplicationRoutesConstants.connectionList);
      });
    }

    testWidgets('the settings page has no bottom navigation bar, since it is no tab', (tester) async {
      await pumpSignedInOnPhone(tester, location: ApplicationRoutesConstants.settings);

      expect(find.byType(NavigationBar), findsNothing);
    });
  });

  group('BottomNavWidget - Platform', () {
    testWidgets('the Platform shell on a phone shows exactly the tabs Home and Connections', (tester) async {
      addTearDown(tester.view.reset);
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      TestEnv.authenticate(target: SessionTarget.platform);

      await tester.pumpWidget(App(dependencies: MockSignInDependencies(), language: 'en'));
      await tester.pumpAndSettle();

      final labels = tester
          .widget<NavigationBar>(find.byType(NavigationBar))
          .destinations
          .map((destination) => (destination as NavigationDestination).label)
          .toList();
      expect(labels, ['Home', 'Connections']);
      expect(tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex, 0);
    });

    testWidgets('the Platform tabs in Turkish', (tester) async {
      addTearDown(tester.view.reset);
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      TestEnv.authenticate(target: SessionTarget.platform);

      await tester.pumpWidget(App(dependencies: MockSignInDependencies(), language: 'tr'));
      await tester.pumpAndSettle();

      expect(inBottomNav('Bağlantılar'), findsOneWidget);
      expect(inBottomNav('Gözat'), findsNothing);
    });
  });
}
