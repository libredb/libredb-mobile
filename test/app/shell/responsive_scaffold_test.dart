@Tags(['widget'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:libredb_mobile/app/di/mock_sign_in_dependencies.dart';
import 'package:libredb_mobile/app/router/app_routes_constants.dart';
import 'package:libredb_mobile/app/shell/profile/profile_sheet.dart';
import 'package:libredb_mobile/app/shell/responsive_scaffold.dart';
import 'package:libredb_mobile/app/shell/top_bar/top_bar_widget.dart';
import 'package:libredb_mobile/app/app.dart';
import 'package:libredb_mobile/core/testing/app_key_constants.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/shared/models/session_target.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:libredb_mobile/shared/widgets/statement_capture.dart';

import '../../support/test_env.dart';

void main() {
  // The real app, signed in, on the connection list, on a device whose system bars cover [insets] of the screen.
  Future<void> pumpSignedIn(WidgetTester tester, {required Size size, required FakeViewPadding insets}) async {
    addTearDown(tester.view.reset);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    tester.view.padding = insets;
    tester.view.viewPadding = insets;
    TestEnv.authenticate();

    await tester.pumpWidget(App(dependencies: MockSignInDependencies(), language: 'en'));
    await tester.pumpAndSettle();
    expect(find.byType(ResponsiveScaffold), findsOneWidget);
  }

  Finder avatar() => find.byKey(profileButtonKey);

  // An Android phone with a 48 px status bar, as on an API 36 emulator.
  const statusBar = FakeViewPadding(top: 48);

  group('ResponsiveScaffold - status bar', () {
    for (final (layout, size) in const [
      ('phone', Size(412, 915)),
      ('tablet', Size(800, 1280)),
      ('desktop', Size(1280, 800)),
    ]) {
      testWidgets('the $layout top bar starts below the status bar and its avatar takes a tap at its top', (
        tester,
      ) async {
        await pumpSignedIn(tester, size: size, insets: statusBar);

        expect(tester.getRect(find.byType(TopBarWidget)).top, greaterThanOrEqualTo(48));
        final button = tester.getRect(avatar());
        expect(button.top, greaterThanOrEqualTo(48));

        await tester.tapAt(Offset(button.center.dx, button.top + 2));
        await tester.pumpAndSettle();

        expect(find.byType(ProfileSheet), findsOneWidget);
      });
    }
  });

  group('ResponsiveScaffold - landscape side insets', () {
    // The insets of a device on its side: the status bar on top, the camera cutout and the navigation bar on the
    // sides. Since #419 a phone cannot be turned, so what reaches this is a tablet or a foldable, where the platform
    // ignores the app's portrait lock, and a window the system sizes; the insets and the sizes are the ones a device
    // on its side reports, which is why they are kept.
    const landscape = FakeViewPadding(left: 48, top: 24, right: 48);

    for (final size in const [Size(915, 412), Size(740, 360)]) {
      testWidgets('the top bar stays clear of the cutout and the navigation bar at ${size.width.toInt()} px', (
        tester,
      ) async {
        await pumpSignedIn(tester, size: size, insets: landscape);

        final topBar = tester.getRect(find.byType(TopBarWidget));
        expect(topBar.left, greaterThanOrEqualTo(48));
        expect(topBar.top, greaterThanOrEqualTo(24));
        expect(topBar.right, lessThanOrEqualTo(size.width - 48));
      });
    }
  });

  // The real app, signed in on a phone, on [location].
  Future<void> pumpPhoneOn(WidgetTester tester, String location, {required String language}) async {
    addTearDown(tester.view.reset);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    TestEnv.authenticate();

    await tester.pumpWidget(App(dependencies: MockSignInDependencies(), language: language));
    await tester.pumpAndSettle();
    (tester.widget<MaterialApp>(find.byType(MaterialApp)).routerConfig! as GoRouter).go(location);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
  }

  Finder titleInTopBar(String title) => find.descendant(of: find.byType(TopBarWidget), matching: find.text(title));

  group('ResponsiveScaffold - page title', () {
    for (final (location, title) in const [
      (ApplicationRoutesConstants.connectionList, 'Bağlantılar'),
      (ApplicationRoutesConstants.browse, 'Gözat'),
      (ApplicationRoutesConstants.sql, 'SQL'),
      (ApplicationRoutesConstants.settings, 'Ayarlar'),
    ]) {
      testWidgets('shows $title for $location in Turkish', (tester) async {
        await pumpPhoneOn(tester, location, language: 'tr');

        expect(titleInTopBar(title), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('ResponsiveScaffold - a compact height', () {
    // The Android 13 emulator held sideways, as #177 measured it: 829 by 393 with a 24 px status bar and gesture bar.
    // After #419 no phone reports this; a split-screen view, a foldable and a tablet still do, and the compact height
    // class they land in is the same one, so the measurement stands.
    const sideways = Size(829, 393);
    const statusBar = FakeViewPadding(top: 24, bottom: 24);

    Future<void> pumpOn(WidgetTester tester, String location, {Size size = sideways}) async {
      await pumpSignedIn(tester, size: size, insets: statusBar);
      (tester.widget<MaterialApp>(find.byType(MaterialApp)).routerConfig! as GoRouter).go(location);
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
    }

    testWidgets('a tab page shows the tabs in a navigation rail at the side instead of the bottom bar', (tester) async {
      await pumpOn(tester, ApplicationRoutesConstants.connectionList);

      expect(find.byType(NavigationBar), findsNothing);
      final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
      expect(rail.destinations.map((destination) => (destination.label as Text).data), [
        'Connections',
        'Browse',
        'SQL',
      ]);
      expect(rail.selectedIndex, 0);
      expect(
        tester.getRect(find.byType(NavigationRail)).right,
        lessThanOrEqualTo(tester.getRect(find.byType(TopBarWidget)).left),
      );
    });

    testWidgets('a tap on the rail opens the tab in place of the page', (tester) async {
      await pumpOn(tester, ApplicationRoutesConstants.connectionList);

      await tester.tap(find.descendant(of: find.byType(NavigationRail), matching: find.text('SQL')));
      await tester.pumpAndSettle();

      final router = tester.widget<MaterialApp>(find.byType(MaterialApp)).routerConfig! as GoRouter;
      expect(router.state.uri.path, ApplicationRoutesConstants.sql);
      expect(router.canPop(), isFalse);
      expect(tester.widget<NavigationRail>(find.byType(NavigationRail)).selectedIndex, 2);
    });

    testWidgets('the rail stays clear of a camera cutout on the left', (tester) async {
      await pumpSignedIn(tester, size: sideways, insets: const FakeViewPadding(left: 48, top: 24, right: 48));

      expect(tester.getRect(find.byType(NavigationRail)).left, greaterThanOrEqualTo(48));
      expect(tester.getRect(find.byType(TopBarWidget)).right, lessThanOrEqualTo(sideways.width - 48));
    });

    testWidgets('the rail scrolls rather than overflow with the keyboard up, and its tabs still open', (tester) async {
      // The SQL editor, where a phone held sideways types with the keyboard up (#176).
      await pumpOn(tester, ApplicationRoutesConstants.sql);

      tester.view.viewInsets = const FakeViewPadding(bottom: 255);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final browse = find.descendant(of: find.byType(NavigationRail), matching: find.text('Browse'));
      await tester.dragUntilVisible(browse, find.byType(NavigationRail), const Offset(0, 50));
      await tester.tap(browse);
      await tester.pumpAndSettle();

      final router = tester.widget<MaterialApp>(find.byType(MaterialApp)).routerConfig! as GoRouter;
      expect(router.state.uri.path, ApplicationRoutesConstants.browse);
    });

    testWidgets('the connection list keeps the statement capture note with the keyboard up, and overflows nothing', (
      tester,
    ) async {
      await pumpOn(tester, ApplicationRoutesConstants.connectionList);
      expect(find.byType(StatementCaptureNote), findsOneWidget, reason: 'the mock policy records statements in full');

      await tester.showKeyboard(find.byType(TextField));
      tester.view.viewInsets = const FakeViewPadding(bottom: 255);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final note = tester.getRect(find.byType(StatementCaptureNote));
      expect(note.top, greaterThanOrEqualTo(tester.getRect(find.byType(TopBarWidget)).bottom));
      expect(note.bottom, lessThanOrEqualTo(393 - 255));
      expect(tester.testTextInput.isVisible, isTrue);
    });

    testWidgets('a page that is no tab shows no rail', (tester) async {
      await pumpOn(tester, ApplicationRoutesConstants.settings);

      expect(find.byType(NavigationRail), findsNothing);
      expect(find.byType(NavigationBar), findsNothing);
    });

    testWidgets('a portrait phone keeps the bottom bar, also with the keyboard up', (tester) async {
      await pumpOn(tester, ApplicationRoutesConstants.connectionList, size: const Size(393, 829));
      expect(find.byType(NavigationBar), findsOneWidget);

      tester.view.viewInsets = const FakeViewPadding(bottom: 400);
      await tester.pumpAndSettle();

      expect(find.byType(NavigationRail), findsNothing);
    });
  });

  // The Platform shell's frame: Home, Connections and Audit are its tabs, and settings is no tab though it is under
  // /platform.
  group('ResponsiveScaffold - Platform', () {
    Future<GoRouter> pumpPlatformFrame(
      WidgetTester tester,
      String location, {
      Size size = const Size(390, 844),
      Locale locale = const Locale('en'),
    }) async {
      addTearDown(tester.view.reset);
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      Widget page(String name) => Center(child: Text('page $name'));
      final router = GoRouter(
        initialLocation: location,
        routes: [
          ShellRoute(
            builder: (context, state, child) =>
                ResponsiveScaffold(target: SessionTarget.platform, activeRoute: state.uri.path, child: child),
            routes: [
              GoRoute(path: ApplicationRoutesConstants.platformHome, builder: (_, _) => page('home')),
              GoRoute(path: ApplicationRoutesConstants.platformConnections, builder: (_, _) => page('connections')),
              GoRoute(
                path: ApplicationRoutesConstants.platformConnectionGrants,
                builder: (_, state) => page('grants ${state.pathParameters['id']}'),
              ),
              GoRoute(path: ApplicationRoutesConstants.platformSettings, builder: (_, _) => page('settings')),
              GoRoute(path: ApplicationRoutesConstants.platformAudit, builder: (_, _) => page('audit')),
              GoRoute(path: ApplicationRoutesConstants.platformAuditEvent, builder: (_, _) => page('audit event')),
            ],
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
          locale: locale,
          localizationsDelegates: const [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.delegate.supportedLocales,
        ),
      );
      await tester.pumpAndSettle();
      return router;
    }

    List<String?> bottomLabels(WidgetTester tester) => tester
        .widget<NavigationBar>(find.byType(NavigationBar))
        .destinations
        .map((destination) => (destination as NavigationDestination).label)
        .toList();

    testWidgets('/platform shows exactly the tabs Home, Connections and Audit, with Home selected and no back arrow', (
      tester,
    ) async {
      await pumpPlatformFrame(tester, ApplicationRoutesConstants.platformHome);

      expect(bottomLabels(tester), ['Home', 'Connections', 'Audit']);
      expect(tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex, 0);
      expect(find.byType(BackButton), findsNothing);
      expect(titleInTopBar('Home'), findsOneWidget);
    });

    testWidgets('/platform/connections shows the bar with Connections selected', (tester) async {
      await pumpPlatformFrame(tester, ApplicationRoutesConstants.platformConnections);

      expect(tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex, 1);
      expect(find.byType(BackButton), findsNothing);
      expect(titleInTopBar('Connections'), findsOneWidget);
    });

    testWidgets('/platform/audit shows the bar with Audit selected', (tester) async {
      await pumpPlatformFrame(tester, ApplicationRoutesConstants.platformAudit);

      expect(tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex, 2);
      expect(find.byType(BackButton), findsNothing);
      expect(titleInTopBar('Audit'), findsOneWidget);
    });

    testWidgets('the Audit title follows the app language', (tester) async {
      await pumpPlatformFrame(tester, ApplicationRoutesConstants.platformAudit, locale: const Locale('tr'));

      expect(titleInTopBar('Denetim'), findsOneWidget);
    });

    testWidgets('the audit event page keeps Audit selected, with a back arrow that pops to the list', (tester) async {
      final router = await pumpPlatformFrame(tester, ApplicationRoutesConstants.platformAudit);
      router.push(ApplicationRoutesConstants.platformAuditEvent);
      await tester.pumpAndSettle();

      expect(tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex, 2);
      expect(find.byType(BackButton), findsOneWidget);
      expect(titleInTopBar('Audit'), findsOneWidget);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      expect(find.text('page audit'), findsOneWidget);
    });

    testWidgets('/platform/settings shows the back arrow and no bottom bar', (tester) async {
      await pumpPlatformFrame(tester, ApplicationRoutesConstants.platformSettings);

      expect(find.byType(NavigationBar), findsNothing);
      expect(find.byType(BackButton), findsOneWidget);
      expect(titleInTopBar('Settings'), findsOneWidget);
    });

    testWidgets('the back arrow of /platform/settings opened by a link goes to /platform', (tester) async {
      final router = await pumpPlatformFrame(tester, ApplicationRoutesConstants.platformSettings);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      expect(router.state.uri.path, ApplicationRoutesConstants.platformHome);
    });

    testWidgets('a page under the Connections tab keeps the bar and a back arrow that goes to the tab root', (
      tester,
    ) async {
      final router = await pumpPlatformFrame(tester, '/platform/connections/c1');

      expect(tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex, 1);
      expect(find.byType(BackButton), findsOneWidget);
      expect(titleInTopBar('Connections'), findsOneWidget);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      expect(router.state.uri.path, ApplicationRoutesConstants.platformConnections);
    });

    testWidgets('a page pushed under the Connections tab pops back to the page under it', (tester) async {
      final router = await pumpPlatformFrame(tester, ApplicationRoutesConstants.platformConnections);
      router.push('/platform/connections/c1');
      await tester.pumpAndSettle();
      expect(find.text('page grants c1'), findsOneWidget);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      expect(find.text('page connections'), findsOneWidget);
    });

    testWidgets('a tap on Connections opens it in place of Home', (tester) async {
      final router = await pumpPlatformFrame(tester, ApplicationRoutesConstants.platformHome);

      await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Connections')));
      await tester.pumpAndSettle();

      expect(router.state.uri.path, ApplicationRoutesConstants.platformConnections);
      expect(router.canPop(), isFalse);
    });

    testWidgets('a compact height shows exactly the three tabs in the rail', (tester) async {
      await pumpPlatformFrame(tester, ApplicationRoutesConstants.platformConnections, size: const Size(829, 393));

      expect(find.byType(NavigationBar), findsNothing);
      final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
      expect(rail.destinations.map((destination) => (destination.label as Text).data), [
        'Home',
        'Connections',
        'Audit',
      ]);
      expect(rail.selectedIndex, 1);
    });

    testWidgets('settings at a compact height shows no rail', (tester) async {
      await pumpPlatformFrame(tester, ApplicationRoutesConstants.platformSettings, size: const Size(829, 393));

      expect(find.byType(NavigationRail), findsNothing);
    });
  });
}
