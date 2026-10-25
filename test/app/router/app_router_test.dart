@Tags(['widget'])
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:libredb_mobile/app/di/local_sign_in_dependencies.dart';
import 'package:libredb_mobile/app/app.dart';
import 'package:libredb_mobile/app/di/app_dependencies.dart';
import 'package:libredb_mobile/app/router/not_found_page.dart';
import 'package:libredb_mobile/app/session/session_cubit.dart';
import 'package:libredb_mobile/shared/models/session_target.dart';
import 'package:libredb_mobile/app/shell/app_shell.dart';
import 'package:libredb_mobile/app/shell/platform_shell.dart';
import 'package:libredb_mobile/features/platform_connections/presentation/pages/platform_connection_list_page.dart';
import 'package:libredb_mobile/features/platform_grants/presentation/pages/platform_connection_grants_page.dart';
import 'package:libredb_mobile/features/platform_home/presentation/pages/platform_home_page.dart';
import 'package:libredb_mobile/core/testing/app_key_constants.dart';
import 'package:libredb_mobile/features/auth/presentation/pages/login_page.dart';
import 'package:libredb_mobile/features/connections/presentation/pages/connection_list_page.dart';
import 'package:libredb_mobile/features/settings/presentation/pages/settings_screen.dart';
import 'package:libredb_mobile/infrastructure/auth/oidc/oidc_client.dart';
import 'package:libredb_mobile/infrastructure/config/auth_config.dart';
import 'package:libredb_mobile/infrastructure/config/environment.dart';
import 'package:libredb_mobile/infrastructure/http/token_rotation.dart';
import 'package:libredb_mobile/infrastructure/storage/secure_storage.dart';
import 'package:libredb_mobile/app/router/app_routes_constants.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import '../../mocks/mock_classes.dart';
import '../../support/test_env.dart';

/// The identity provider. The router tests never sign in through it.
class _IdleOidcClient implements IOidcClient {
  @override
  Future<OidcSignInOutcome> signIn() => throw UnimplementedError('these tests never sign in through the provider');

  @override
  Future<TokenRotationResult> refresh({
    required String refreshToken,
    required String idToken,
    required String accessToken,
    required DateTime accessTokenExpiresAt,
  }) => throw UnimplementedError('these tests store no expired session');

  @override
  Future<OidcLogoutOutcome> endProviderSession({String? idTokenHint}) =>
      throw UnimplementedError('these tests never log out');
}

/// The test config.
class _OidcDependencies extends AppDependencies {
  _OidcDependencies()
    : super(
        appConfig: const AppConfig.test(),
        authMode: OidcAuthMode(OidcSettings(issuer: Uri.parse('https://id.example.com'), clientId: 'app')),
      );

  @override
  IOidcClient createOidcClient(OidcSettings settings) => _IdleOidcClient();
}

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

  // A deep link starts the app on this location: GoRouter prefers the
  // platform's default route over its initialLocation.
  void startOn(WidgetTester tester, String location) {
    tester.platformDispatcher.defaultRouteNameTestValue = location;
    addTearDown(tester.platformDispatcher.clearDefaultRouteNameTestValue);
  }

  // The platform pushes a route the way iOS delivers a universal link or a custom scheme link: after the first frame,
  // also for the link that opened the app.
  Future<void> pushRouteFromPlatform(WidgetTester tester, String location) async {
    final message = SystemChannels.navigation.codec.encodeMethodCall(
      MethodCall('pushRouteInformation', <String, Object?>{'location': location, 'state': null}),
    );
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(SystemChannels.navigation.name, message, (_) {});
  }

  // Secure storage that answers the stored token read only when the returned completer completes. It holds nothing
  // else, so the startup step finds no expiry to refresh and reads the stored token.
  Completer<String?> storedTokenPending(MockISecureStorage secureStorage) {
    final storedToken = Completer<String?>();
    when(() => secureStorage.read(any())).thenAnswer(
      (invocation) => invocation.positionalArguments.first == SecureStorageKeys.jwtToken.key
          ? storedToken.future
          : Future<String?>.value(),
    );
    return storedToken;
  }

  // Pumps the authenticated shell frame by frame and returns the frames that built the login page, offstage ones
  // included. A fixed number of frames, instead of pumpAndSettle, so every frame is inspected.
  Future<List<int>> pumpShellRecordingLogin(WidgetTester tester) async {
    final loginFrames = <int>[];
    for (var frame = 0; frame < 30; frame++) {
      if (find.byType(LoginScreen, skipOffstage: false).evaluate().isNotEmpty) loginFrames.add(frame);
      await tester.pump(const Duration(milliseconds: 100));
    }
    return loginFrames;
  }

  group('AppRouterFactory', () {
    testWidgets('redirects unauthenticated users to login', (tester) async {
      setDesktopViewport(tester);
      await tester.pumpWidget(App(dependencies: LocalSignInDependencies(), language: 'en'));
      await tester.pumpAndSettle();

      final router = routerFromApp(tester);
      router.go(ApplicationRoutesConstants.settings);
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);
    });

    testWidgets('allows authenticated users to open settings', (tester) async {
      setDesktopViewport(tester);
      TestEnv.authenticate();
      await tester.pumpWidget(App(dependencies: LocalSignInDependencies(), language: 'en'));
      await tester.pumpAndSettle();

      final router = routerFromApp(tester);
      router.go(ApplicationRoutesConstants.settings);
      await tester.pumpAndSettle();

      expect(find.byType(SettingsScreen), findsOneWidget);
    });

    testWidgets('sends an authenticated user on the login page home when its returnUrl leaves the app', (tester) async {
      setDesktopViewport(tester);
      TestEnv.authenticate();
      await tester.pumpWidget(App(dependencies: LocalSignInDependencies(), language: 'en'));
      await tester.pumpAndSettle();

      final returnUrl = Uri.encodeQueryComponent('https://evil.example/settings');
      routerFromApp(tester).go('${ApplicationRoutesConstants.login}?returnUrl=$returnUrl');
      await tester.pumpAndSettle();

      expect(routerFromApp(tester).state.uri.toString(), ApplicationRoutesConstants.connectionList);
    });

    testWidgets('signed in, / opens the connection list', (tester) async {
      setDesktopViewport(tester);
      TestEnv.authenticate();
      await tester.pumpWidget(App(dependencies: LocalSignInDependencies(), language: 'en'));
      await tester.pumpAndSettle();
      routerFromApp(tester).go(ApplicationRoutesConstants.settings);
      await tester.pumpAndSettle();

      routerFromApp(tester).go('/');
      await tester.pumpAndSettle();

      expect(routerFromApp(tester).state.uri.path, ApplicationRoutesConstants.connectionList);
      expect(find.byType(ConnectionListPage), findsOneWidget);
    });

    testWidgets('a sign-in on the login page opens the shell on the connection list, with its tabs and avatar', (
      tester,
    ) async {
      setDesktopViewport(tester);
      await tester.pumpWidget(App(dependencies: LocalSignInDependencies(), language: 'en'));
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);

      // What a sign-in leaves behind: the stored session, and the session marked as signed in.
      TestEnv.authenticate();
      tester.element(find.byType(LoginScreen)).read<SessionCubit>().markAuthenticated(SessionTarget.studio);
      await tester.pumpAndSettle();

      expect(routerFromApp(tester).state.uri.path, ApplicationRoutesConstants.home);
      expect(find.byType(AppShell), findsOneWidget);
      expect(find.byType(ConnectionListPage), findsOneWidget);
      expect(tester.widget<NavigationBar>(find.byType(NavigationBar)).destinations, hasLength(3));
      expect(find.byKey(profileButtonKey), findsOneWidget);
    });

    testWidgets('signed out, / opens the login page with no returnUrl', (tester) async {
      setDesktopViewport(tester);
      startOn(tester, '/');
      await tester.pumpWidget(App(dependencies: LocalSignInDependencies(), language: 'en'));
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(routerFromApp(tester).state.uri.toString(), ApplicationRoutesConstants.login);
    });

    testWidgets('never builds the login page on an authenticated cold start', (tester) async {
      setDesktopViewport(tester);
      TestEnv.authenticate();
      final analytics = MockAnalyticsService();
      await tester.pumpWidget(App(dependencies: LocalSignInDependencies(), language: 'en', analytics: analytics));
      final loginFrames = await pumpShellRecordingLogin(tester);

      expect(loginFrames, isEmpty, reason: 'frames that built the login page');
      expect(routerFromApp(tester).state.uri.path, ApplicationRoutesConstants.connectionList);
      expect(find.byType(ConnectionListPage), findsOneWidget);
      verifyNever(
        () => analytics.logScreenView(
          screenName: any(named: 'screenName', that: equals('login')),
          screenClass: any(named: 'screenClass'),
        ),
      );
    });

    testWidgets('opens a deep link on an authenticated cold start', (tester) async {
      setDesktopViewport(tester);
      startOn(tester, ApplicationRoutesConstants.settings);
      TestEnv.authenticate();
      await tester.pumpWidget(App(dependencies: LocalSignInDependencies(), language: 'en'));
      final loginFrames = await pumpShellRecordingLogin(tester);

      expect(routerFromApp(tester).state.uri.path, ApplicationRoutesConstants.settings);
      expect(find.byType(SettingsScreen), findsOneWidget);
      expect(loginFrames, isEmpty, reason: 'frames that built the login page');
    });

    testWidgets('keeps a deep link as the login returnUrl on an unauthenticated cold start', (tester) async {
      setDesktopViewport(tester);
      startOn(tester, ApplicationRoutesConstants.settings);
      await tester.pumpWidget(App(dependencies: LocalSignInDependencies(), language: 'en'));
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(routerFromApp(tester).state.uri.queryParameters['returnUrl'], ApplicationRoutesConstants.settings);
    });

    testWidgets('opens a route the platform pushes while the stored session is restored', (tester) async {
      setDesktopViewport(tester);
      final secureStorage = MockISecureStorage();
      final storedToken = storedTokenPending(secureStorage);
      await tester.pumpWidget(
        App(dependencies: LocalSignInDependencies(), language: 'en', secureStorage: secureStorage),
      );
      await tester.pump();

      await pushRouteFromPlatform(tester, ApplicationRoutesConstants.settings);
      storedToken.complete('MOCK_TOKEN');
      await tester.pumpAndSettle();
      // The restored session loads the account, which the mock API answers after 500 ms.
      await tester.pump(const Duration(seconds: 1));

      expect(routerFromApp(tester).state.uri.toString(), ApplicationRoutesConstants.settings);
      expect(find.byType(SettingsScreen), findsOneWidget);
    });

    testWidgets('keeps a route the platform pushes while the stored session is restored as the login returnUrl', (
      tester,
    ) async {
      setDesktopViewport(tester);
      final secureStorage = MockISecureStorage();
      final storedToken = storedTokenPending(secureStorage);
      await tester.pumpWidget(
        App(dependencies: LocalSignInDependencies(), language: 'en', secureStorage: secureStorage),
      );
      await tester.pump();

      await pushRouteFromPlatform(tester, ApplicationRoutesConstants.settings);
      storedToken.complete(null);
      await tester.pumpAndSettle();

      expect(routerFromApp(tester).state.uri.toString(), '/login?returnUrl=%2Fsettings');
      expect(find.byType(LoginScreen), findsOneWidget);
    });
  });

  // A Platform session lives under /platform, a Studio session never reaches it, and neither reaches the other's
  // routes.
  group('AppRouterFactory - session targets', () {
    Future<GoRouter> startSignedIn(WidgetTester tester, SessionTarget target) async {
      setDesktopViewport(tester);
      TestEnv.authenticate(target: target);
      await tester.pumpWidget(App(dependencies: LocalSignInDependencies(), language: 'en'));
      await tester.pumpAndSettle();
      return routerFromApp(tester);
    }

    testWidgets('a Platform cold start opens the Platform shell on /platform and never builds the login page', (
      tester,
    ) async {
      setDesktopViewport(tester);
      TestEnv.authenticate(target: SessionTarget.platform);
      await tester.pumpWidget(App(dependencies: LocalSignInDependencies(), language: 'en'));
      final loginFrames = await pumpShellRecordingLogin(tester);

      expect(loginFrames, isEmpty, reason: 'frames that built the login page');
      expect(routerFromApp(tester).state.uri.path, ApplicationRoutesConstants.platformHome);
      expect(find.byType(PlatformShell), findsOneWidget);
      expect(find.byType(AppShell), findsNothing);
      expect(find.byType(PlatformHomePage), findsOneWidget);
    });

    testWidgets('a Platform session shows the home and the connection list inside the Platform shell', (tester) async {
      final router = await startSignedIn(tester, SessionTarget.platform);
      // The mock answers the identity after its latency.
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(find.descendant(of: find.byType(PlatformShell), matching: find.byType(PlatformHomePage)), findsOneWidget);
      expect(find.text('Example Org'), findsOneWidget);

      router.go(ApplicationRoutesConstants.platformConnections);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(
        find.descendant(of: find.byType(PlatformShell), matching: find.byType(PlatformConnectionListPage)),
        findsOneWidget,
      );
      expect(find.text('İstanbul Önbellek'), findsOneWidget);
      expect(find.byType(AppShell), findsNothing);
    });

    testWidgets('a tap on a Platform connection opens its grants inside the Platform shell', (tester) async {
      final router = await startSignedIn(tester, SessionTarget.platform);
      router.go(ApplicationRoutesConstants.platformConnections);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Legacy Billing'));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(router.state.uri.path, '/platform/connections/cm0conn0000000000000000002');
      expect(
        find.descendant(of: find.byType(PlatformShell), matching: find.byType(PlatformConnectionGrantsPage)),
        findsOneWidget,
      );
      expect(find.text('alice.reader'), findsOneWidget);
    });

    testWidgets('a Platform grants location without its connection opens the connections list', (tester) async {
      final router = await startSignedIn(tester, SessionTarget.platform);

      router.go('/platform/connections/cm0conn0000000000000000002');
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(router.state.uri.path, ApplicationRoutesConstants.platformConnections);
      expect(find.byType(PlatformConnectionGrantsPage), findsNothing);
      expect(find.byType(PlatformConnectionListPage), findsOneWidget);
    });

    testWidgets('a Studio session still lands on the Studio connection list', (tester) async {
      final router = await startSignedIn(tester, SessionTarget.studio);

      expect(router.state.uri.path, ApplicationRoutesConstants.connectionList);
      expect(find.byType(ConnectionListPage), findsOneWidget);
      expect(find.byType(PlatformShell), findsNothing);
      expect(find.byType(PlatformConnectionListPage), findsNothing);
    });

    testWidgets('a Platform session at / goes to /platform', (tester) async {
      final router = await startSignedIn(tester, SessionTarget.platform);
      router.go(ApplicationRoutesConstants.platformSettings);
      await tester.pumpAndSettle();

      router.go(ApplicationRoutesConstants.root);
      await tester.pumpAndSettle();

      expect(router.state.uri.path, ApplicationRoutesConstants.platformHome);
    });

    for (final location in ['/connections', '/browse', '/browse/seed:pg/kinds', '/sql', '/settings']) {
      testWidgets('a Platform session at $location goes to /platform', (tester) async {
        final router = await startSignedIn(tester, SessionTarget.platform);
        router.go(ApplicationRoutesConstants.platformSettings);
        await tester.pumpAndSettle();

        router.go(location);
        await tester.pumpAndSettle();

        expect(router.state.uri.toString(), ApplicationRoutesConstants.platformHome);
        expect(find.byType(AppShell), findsNothing);
      });
    }

    testWidgets('a Platform deep link at a Studio route opens /platform on a cold start', (tester) async {
      setDesktopViewport(tester);
      startOn(tester, ApplicationRoutesConstants.sql);
      TestEnv.authenticate(target: SessionTarget.platform);
      await tester.pumpWidget(App(dependencies: LocalSignInDependencies(), language: 'en'));
      await tester.pumpAndSettle();

      expect(routerFromApp(tester).state.uri.toString(), ApplicationRoutesConstants.platformHome);
      expect(find.byType(AppShell), findsNothing);
    });

    for (final location in ['/platform', '/platform/connections', '/platform/settings']) {
      testWidgets('a Studio session at $location goes to /connections', (tester) async {
        final router = await startSignedIn(tester, SessionTarget.studio);

        router.go(location);
        await tester.pumpAndSettle();

        expect(router.state.uri.toString(), ApplicationRoutesConstants.connectionList);
        expect(find.byType(PlatformShell), findsNothing);
      });
    }

    testWidgets('a Platform session on /login with a Studio returnUrl goes to /platform', (tester) async {
      final router = await startSignedIn(tester, SessionTarget.platform);

      router.go('${ApplicationRoutesConstants.login}?returnUrl=${Uri.encodeQueryComponent('/sql')}');
      await tester.pumpAndSettle();

      expect(router.state.uri.toString(), ApplicationRoutesConstants.platformHome);
    });

    testWidgets('a Platform session on /login with a Platform returnUrl goes there', (tester) async {
      final router = await startSignedIn(tester, SessionTarget.platform);

      router.go('${ApplicationRoutesConstants.login}?returnUrl=${Uri.encodeQueryComponent('/platform/settings')}');
      await tester.pumpAndSettle();

      expect(router.state.uri.toString(), ApplicationRoutesConstants.platformSettings);
      expect(find.byType(SettingsScreen), findsOneWidget);
    });

    testWidgets('a Studio session on /login with a Platform returnUrl goes to /connections', (tester) async {
      final router = await startSignedIn(tester, SessionTarget.studio);

      router.go('${ApplicationRoutesConstants.login}?returnUrl=${Uri.encodeQueryComponent('/platform/settings')}');
      await tester.pumpAndSettle();

      expect(router.state.uri.toString(), ApplicationRoutesConstants.connectionList);
    });

    testWidgets('signed out, /platform/settings goes to the login page with it as the returnUrl', (tester) async {
      setDesktopViewport(tester);
      await tester.pumpWidget(App(dependencies: LocalSignInDependencies(), language: 'en'));
      await tester.pumpAndSettle();

      routerFromApp(tester).go(ApplicationRoutesConstants.platformSettings);
      await tester.pumpAndSettle();

      expect(routerFromApp(tester).state.uri.toString(), '/login?returnUrl=%2Fplatform%2Fsettings');
    });

    testWidgets('signed out, /platform goes to the login page with no returnUrl', (tester) async {
      setDesktopViewport(tester);
      await tester.pumpWidget(App(dependencies: LocalSignInDependencies(), language: 'en'));
      await tester.pumpAndSettle();

      routerFromApp(tester).go(ApplicationRoutesConstants.platformHome);
      await tester.pumpAndSettle();

      expect(routerFromApp(tester).state.uri.toString(), ApplicationRoutesConstants.login);
    });

    testWidgets('a Platform session opens settings in the Platform shell', (tester) async {
      final router = await startSignedIn(tester, SessionTarget.platform);

      router.go(ApplicationRoutesConstants.platformSettings);
      await tester.pumpAndSettle();

      expect(find.byType(SettingsScreen), findsOneWidget);
      expect(find.byType(PlatformShell), findsOneWidget);
    });

    for (final (target, home) in [
      (SessionTarget.platform, ApplicationRoutesConstants.platformHome),
      (SessionTarget.studio, ApplicationRoutesConstants.connectionList),
    ]) {
      testWidgets('the not-found home button of a ${target.name} session goes to $home', (tester) async {
        final router = await startSignedIn(tester, target);
        router.go('/does-not-exist');
        await tester.pumpAndSettle();
        expect(find.byType(NotFoundPage), findsOneWidget);

        await tester.tap(find.widgetWithText(TextButton, 'Home'));
        await tester.pumpAndSettle();

        expect(router.state.uri.path, home);
      });
    }
  });

  // The password sign-in is gone: its pages resolve to nothing.
  group('AppRouterFactory - removed password routes', () {
    const removed = [
      '/register',
      '/forgot-password',
      '/change-password',
      '/login-otp',
      '/login-otp-verify/x@example.com',
    ];

    for (final location in removed) {
      testWidgets('signed in, $location shows the not-found page', (tester) async {
        setDesktopViewport(tester);
        TestEnv.authenticate();
        await tester.pumpWidget(App(dependencies: LocalSignInDependencies(), language: 'en'));
        await tester.pumpAndSettle();

        routerFromApp(tester).go(location);
        await tester.pumpAndSettle();

        expect(find.byType(NotFoundPage), findsOneWidget);
      });
    }

    for (final location in removed) {
      testWidgets('signed out, $location is not public and leads to the login page', (tester) async {
        setDesktopViewport(tester);
        await tester.pumpWidget(App(dependencies: LocalSignInDependencies(), language: 'en'));
        await tester.pumpAndSettle();

        routerFromApp(tester).go(location);
        await tester.pumpAndSettle();

        expect(find.byType(LoginScreen), findsOneWidget);
        expect(routerFromApp(tester).state.uri.path, ApplicationRoutesConstants.login);
      });
    }
  });

  // The app's own redirect paths carry the authorization code and state, which must never become a router location
  // or a returnUrl.
  group('AppRouterFactory - redirect paths of the identity provider', () {
    for (final (mode, dependencies) in [
      ('oidc', _OidcDependencies()),
      (
        'misconfigured oidc',
        const AppDependencies(
          appConfig: AppConfig.test(),
          authMode: OidcMisconfiguredAuthMode('OIDC_ISSUER is required'),
        ),
      ),
    ]) {
      // A pushed or crafted link may carry a trailing slash.
      for (final path in ['/oauth2redirect', '/oauth2redirect/']) {
        testWidgets('in $mode mode, signed out, $path lands on /login with no returnUrl', (tester) async {
          setDesktopViewport(tester);
          await tester.pumpWidget(App(language: 'en', dependencies: dependencies));
          await tester.pumpAndSettle();

          routerFromApp(tester).go('$path?code=SECRETCODE&state=SECRETSTATE');
          await tester.pumpAndSettle();

          expect(find.byType(LoginScreen), findsOneWidget);
          expect(routerFromApp(tester).state.uri.toString(), ApplicationRoutesConstants.login);
        });
      }

      testWidgets('in $mode mode, a cold start on /oauth2redirect lands on /login with no returnUrl', (tester) async {
        setDesktopViewport(tester);
        startOn(tester, '/oauth2redirect?code=SECRETCODE&state=SECRETSTATE');
        await tester.pumpWidget(App(language: 'en', dependencies: dependencies));
        await tester.pumpAndSettle();

        expect(find.byType(LoginScreen), findsOneWidget);
        expect(routerFromApp(tester).state.uri.toString(), ApplicationRoutesConstants.login);
      });

      testWidgets('in $mode mode, a cold start on /oauth2redirect/ lands on /login with no returnUrl', (tester) async {
        setDesktopViewport(tester);
        startOn(tester, '/oauth2redirect/?code=SECRETCODE&state=SECRETSTATE');
        await tester.pumpWidget(App(language: 'en', dependencies: dependencies));
        await tester.pumpAndSettle();

        expect(find.byType(LoginScreen), findsOneWidget);
        expect(routerFromApp(tester).state.uri.toString(), ApplicationRoutesConstants.login);
      });

      // A misconfigured build can neither sign in nor restore a stored session.
      if (dependencies.authMode is OidcAuthMode) {
        testWidgets('in $mode mode, signed in, /oauth2redirect lands on the connection list', (tester) async {
          setDesktopViewport(tester);
          TestEnv.authenticate();
          await tester.pumpWidget(App(language: 'en', dependencies: dependencies));
          await tester.pumpAndSettle();
          routerFromApp(tester).go(ApplicationRoutesConstants.settings);
          await tester.pumpAndSettle();

          routerFromApp(tester).go('/oauth2redirect?code=SECRETCODE&state=SECRETSTATE');
          await tester.pumpAndSettle();

          expect(routerFromApp(tester).state.uri.toString(), ApplicationRoutesConstants.connectionList);
          expect(find.byType(ConnectionListPage), findsOneWidget);
        });
      }
    }
  });
}
