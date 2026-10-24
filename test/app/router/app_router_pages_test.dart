@Tags(['widget'])
library;

import 'package:flutter/material.dart';
import 'package:libredb_mobile/app/di/local_sign_in_dependencies.dart';
import 'package:libredb_mobile/app/app.dart';
import 'package:libredb_mobile/app/router/app_routes_constants.dart';
import 'package:libredb_mobile/app/router/not_found_page.dart';
import 'package:libredb_mobile/features/auth/presentation/pages/login_page.dart';
import 'package:libredb_mobile/features/connections/presentation/pages/connection_list_page.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:logger/logger.dart' show Level, Logger, OutputEvent;

import '../../support/test_env.dart';

/// go_router 18 only recognizes material_ui's `MaterialApp`. Under the SDK `MaterialApp.router` used by this app, a
/// `builder:` route silently becomes a `NoTransitionPage` (no transition, no iOS back swipe) and an unknown location
/// renders go_router's unstyled widgets-only error screen. These tests pin the Material page behavior.
void main() {
  void setDesktopViewport(WidgetTester tester) {
    addTearDown(tester.view.reset);
    tester.view.physicalSize = const Size(1600, 1600);
    tester.view.devicePixelRatio = 1.0;
  }

  GoRouter routerFromApp(WidgetTester tester) {
    final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    return materialApp.routerConfig! as GoRouter;
  }

  // The first Navigator in the tree is go_router's root navigator.
  List<Page<Object?>> rootPages(WidgetTester tester) => tester.widget<Navigator>(find.byType(Navigator).first).pages;

  group('AppRouterFactory pages', () {
    testWidgets('builds public routes as Material pages', (tester) async {
      setDesktopViewport(tester);
      await tester.pumpWidget(App(dependencies: LocalSignInDependencies(), language: 'en'));
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(rootPages(tester).last, isA<MaterialPage<void>>());
    });

    testWidgets('animates pushed public routes', (tester) async {
      setDesktopViewport(tester);
      await tester.pumpWidget(App(dependencies: LocalSignInDependencies(), language: 'en'));
      await tester.pumpAndSettle();

      // The login page is the only public route, so it is pushed over itself.
      routerFromApp(tester).push(ApplicationRoutesConstants.login);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final route = ModalRoute.of(tester.element(find.byType(LoginScreen).last))!;
      expect(route.transitionDuration, greaterThan(Duration.zero));
      expect(route.animation!.value, lessThan(1.0));

      await tester.pumpAndSettle();
      expect(rootPages(tester).last, isA<MaterialPage<void>>());
    });

    testWidgets('pops a pushed public route with the iOS back swipe', (tester) async {
      setDesktopViewport(tester);
      await tester.pumpWidget(App(dependencies: LocalSignInDependencies(), language: 'en'));
      await tester.pumpAndSettle();

      routerFromApp(tester).push(ApplicationRoutesConstants.login);
      await tester.pumpAndSettle();
      expect(rootPages(tester), hasLength(2));

      // A fast drag across 75% of the width, so the pop never hinges on the 50% threshold.
      await tester.timedDragFrom(const Offset(5, 400), const Offset(1200, 0), const Duration(milliseconds: 150));
      await tester.pumpAndSettle();

      expect(rootPages(tester), hasLength(1));
      expect(find.byType(LoginScreen), findsOneWidget);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('builds the authenticated shell as a Material page', (tester) async {
      setDesktopViewport(tester);
      TestEnv.authenticate();
      await tester.pumpWidget(App(dependencies: LocalSignInDependencies(), language: 'en'));
      await tester.pumpAndSettle();

      expect(routerFromApp(tester).state.uri.path, ApplicationRoutesConstants.home);
      expect(rootPages(tester).last, isA<MaterialPage<void>>());
    });

    testWidgets('renders a Material not-found page for unknown locations', (tester) async {
      setDesktopViewport(tester);
      TestEnv.authenticate();
      await tester.pumpWidget(App(dependencies: LocalSignInDependencies(), language: 'en'));
      await tester.pumpAndSettle();

      routerFromApp(tester).go('/does-not-exist');
      await tester.pumpAndSettle();

      expect(rootPages(tester).last, isA<MaterialPage<void>>());
      expect(find.ancestor(of: find.text('Page Not Found'), matching: find.byType(Scaffold)), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'Home'));
      await tester.pumpAndSettle();

      expect(routerFromApp(tester).state.uri.path, ApplicationRoutesConstants.home);
    });

    testWidgets('shows the not-found page in Turkish', (tester) async {
      setDesktopViewport(tester);
      TestEnv.authenticate();
      await tester.pumpWidget(App(dependencies: LocalSignInDependencies(), language: 'tr'));
      await tester.pumpAndSettle();

      routerFromApp(tester).go('/does-not-exist');
      await tester.pumpAndSettle();

      expect(find.text('Sayfa Bulunamadı'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Ana Sayfa'), findsOneWidget);
    });

    // The page showed go_router's error text, such as "GoException: no routes for location: /does-not-exist", in
    // English in every language.
    testWidgets('says that the page was not found and logs the location that matched no route', (tester) async {
      final warnings = <String>[];
      void record(OutputEvent event) {
        if (event.level == Level.warning) warnings.addAll(event.lines);
      }

      Logger.addOutputListener(record);
      addTearDown(() => Logger.removeOutputListener(record));
      setDesktopViewport(tester);
      TestEnv.authenticate();
      await tester.pumpWidget(App(dependencies: LocalSignInDependencies(), language: 'tr'));
      await tester.pumpAndSettle();

      routerFromApp(tester).go('/does-not-exist');
      await tester.pumpAndSettle();

      expect(find.text('İstediğiniz sayfa bulunamadı.'), findsOneWidget);
      expect(find.textContaining('GoException'), findsNothing);
      expect(warnings, contains(allOf(contains('/does-not-exist'), contains('no routes for location'))));
    });

    // The root page outside the shell, the not-found page, enters without a transition. While a root page that replaces
    // the shell is still entering, the root navigator keeps the exiting shell page mounted, and a shell page that comes
    // back in that window builds the shell Navigator a second time with the same GlobalKey: "Duplicate GlobalKey
    // detected in widget tree" (flutter/flutter#148768). Once a go_router or Flutter release fixes that, the entering
    // transition can return.
    for (final (label, location, page) in [('the not-found page', '/does-not-exist', NotFoundPage)]) {
      testWidgets('returns to the shell 16 ms after leaving it for $label', (tester) async {
        setDesktopViewport(tester);
        TestEnv.authenticate();
        await tester.pumpWidget(App(dependencies: LocalSignInDependencies(), language: 'en'));
        await tester.pumpAndSettle();
        final router = routerFromApp(tester);

        router.go(location);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 16));
        router.go(ApplicationRoutesConstants.home);
        await tester.pumpAndSettle();

        expect(router.state.uri.path, ApplicationRoutesConstants.home);
        expect(find.byType(ConnectionListPage), findsOneWidget);
      });

      testWidgets('returns to the shell after $label has settled', (tester) async {
        setDesktopViewport(tester);
        TestEnv.authenticate();
        await tester.pumpWidget(App(dependencies: LocalSignInDependencies(), language: 'en'));
        await tester.pumpAndSettle();
        final router = routerFromApp(tester);

        router.go(location);
        await tester.pumpAndSettle();
        expect(find.byType(page), findsOneWidget);
        router.go(ApplicationRoutesConstants.home);
        await tester.pumpAndSettle();

        expect(router.state.uri.path, ApplicationRoutesConstants.home);
        expect(find.byType(ConnectionListPage), findsOneWidget);
      });

      testWidgets('shows $label without an entering transition', (tester) async {
        setDesktopViewport(tester);
        TestEnv.authenticate();
        await tester.pumpWidget(App(dependencies: LocalSignInDependencies(), language: 'en'));
        await tester.pumpAndSettle();

        routerFromApp(tester).go(location);
        await tester.pump();

        // A page that animates in is still offstage on this frame.
        final route = ModalRoute.of(tester.element(find.byType(page, skipOffstage: false)))!;
        expect(route.animation!.value, 1.0);
        expect(route.transitionDuration, Duration.zero);
        // The page still leaves with the Material transition.
        expect(route.reverseTransitionDuration, greaterThan(Duration.zero));
        expect(rootPages(tester).last, isA<MaterialPage<void>>());
      });
    }

    testWidgets('declares every route with a pageBuilder', (tester) async {
      setDesktopViewport(tester);
      await tester.pumpWidget(App(dependencies: LocalSignInDependencies(), language: 'en'));
      await tester.pumpAndSettle();

      void expectPageBuilder(RouteBase route) {
        if (route is GoRoute) {
          expect(
            route.builder,
            isNull,
            reason: 'GoRoute ${route.path} uses builder:, which go_router 18 renders as a NoTransitionPage',
          );
        } else if (route is ShellRoute) {
          expect(
            route.builder,
            isNull,
            reason: 'ShellRoute uses builder:, which go_router 18 renders as a NoTransitionPage',
          );
        } else if (route is StatefulShellRoute) {
          expect(
            route.builder,
            isNull,
            reason: 'StatefulShellRoute uses builder:, which go_router 18 renders as a NoTransitionPage',
          );
        }
        route.routes.forEach(expectPageBuilder);
      }

      routerFromApp(tester).configuration.routes.forEach(expectPageBuilder);
    });
  });
}
