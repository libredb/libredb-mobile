@Tags(['widget'])
library;

import 'package:flutter/material.dart';
import 'package:libredb_mobile/app/di/local_sign_in_dependencies.dart';
import 'package:libredb_mobile/app/analytics/analytics_route_observer.dart';
import 'package:libredb_mobile/app/app.dart';
import 'package:libredb_mobile/app/router/app_routes_constants.dart';
import 'package:libredb_mobile/shared/design_system/components/app_page_transition.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import '../../mocks/mock_classes.dart';
import '../../support/test_env.dart';

void main() {
  late MockAnalyticsService analytics;

  setUp(() => analytics = MockAnalyticsService());

  // Screen names logged since the previous verification, in order. Fails when none was logged.
  List<String> loggedScreens() => verify(
    () => analytics.logScreenView(
      screenName: captureAny(named: 'screenName'),
      screenClass: any(named: 'screenClass'),
    ),
  ).captured.cast<String>();

  void expectNoScreenView() => verifyNever(
    () => analytics.logScreenView(
      screenName: any(named: 'screenName'),
      screenClass: any(named: 'screenClass'),
    ),
  );

  group('AnalyticsRouteObserver', () {
    testWidgets('sends no screen class, since a route type name is renamed in an obfuscated build', (tester) async {
      await tester.pumpWidget(
        MaterialApp(navigatorObservers: [AnalyticsRouteObserver(analytics)], home: const Text('home')),
      );

      verify(() => analytics.logScreenView(screenName: '/')).called(1);
      verifyNever(
        () => analytics.logScreenView(
          screenName: any(named: 'screenName'),
          screenClass: any(named: 'screenClass', that: isNotNull),
        ),
      );
    });

    testWidgets('does not log a screen view when a popup menu closes', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          navigatorObservers: [AnalyticsRouteObserver(analytics)],
          home: Scaffold(
            body: PopupMenuButton<String>(
              itemBuilder: (_) => const [PopupMenuItem(value: 'edit', child: Text('Edit'))],
            ),
          ),
        ),
      );
      expect(loggedScreens(), ['/']);

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();

      expectNoScreenView();
    });

    testWidgets('names an unnamed route by its path pattern, never by parameter values', (tester) async {
      final router = GoRouter(
        initialLocation: '/item/42',
        observers: [AnalyticsRouteObserver(analytics)],
        routes: [
          ShellRoute(
            pageBuilder: (context, state, child) => appPlatformPage(state: state, child: child),
            routes: [
              GoRoute(
                path: '/item/:id',
                pageBuilder: (context, state) =>
                    appTransitionPage(state: state, child: Text('item ${state.pathParameters['id']}')),
              ),
            ],
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      expect(find.text('item 42'), findsOneWidget);
      expect(loggedScreens(), ['/item/:id']);
    });

    testWidgets('does not log a named dialog as a screen', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          navigatorObservers: [AnalyticsRouteObserver(analytics)],
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                routeSettings: const RouteSettings(name: 'confirm'),
                builder: (_) => const Text('Confirm'),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      );
      expect(loggedScreens(), ['/']);

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expectNoScreenView();
    });
  });

  group('AnalyticsRouteObserver in the app router', () {
    void setDesktopViewport(WidgetTester tester) {
      addTearDown(tester.view.reset);
      tester.view.physicalSize = const Size(1600, 1600);
      tester.view.devicePixelRatio = 1.0;
    }

    GoRouter routerFromApp(WidgetTester tester) {
      final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
      return materialApp.routerConfig! as GoRouter;
    }

    Future<GoRouter> startAuthenticated(WidgetTester tester) async {
      setDesktopViewport(tester);
      TestEnv.authenticate();
      await tester.pumpWidget(App(dependencies: LocalSignInDependencies(), language: 'en', analytics: analytics));
      await tester.pumpAndSettle();
      return routerFromApp(tester);
    }

    testWidgets('logs the login page once on an unauthenticated start', (tester) async {
      setDesktopViewport(tester);
      await tester.pumpWidget(App(dependencies: LocalSignInDependencies(), language: 'en', analytics: analytics));
      await tester.pumpAndSettle();

      expect(loggedScreens(), ['login']);
    });

    testWidgets('logs the connection list once when an authenticated session starts', (tester) async {
      await startAuthenticated(tester);

      expect(loggedScreens(), ['connectionList']);
    });

    // Shell routes are named like root routes: the route name, else the path pattern, never parameter values.
    for (final (location, screenName) in const [(ApplicationRoutesConstants.settings, 'settings')]) {
      testWidgets('logs the shell route $location once as $screenName', (tester) async {
        final router = await startAuthenticated(tester);
        clearInteractions(analytics);

        router.go(location);
        await tester.pumpAndSettle();

        expect(loggedScreens(), [screenName]);
      });
    }

    testWidgets('logs the revealed shell route once when a pushed route pops', (tester) async {
      final router = await startAuthenticated(tester);
      router.go(ApplicationRoutesConstants.settings);
      await tester.pumpAndSettle();
      clearInteractions(analytics);

      router.push(ApplicationRoutesConstants.connectionList);
      await tester.pumpAndSettle();
      expect(loggedScreens(), ['connectionList']);

      router.pop();
      await tester.pumpAndSettle();
      expect(loggedScreens(), ['settings']);
    });

    testWidgets('logs the not-found page once', (tester) async {
      final router = await startAuthenticated(tester);
      clearInteractions(analytics);

      router.go('/does-not-exist');
      await tester.pumpAndSettle();

      expect(loggedScreens(), ['/not-found']);
    });
  });
}
