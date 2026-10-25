@Tags(['widget'])
library;

import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:libredb_mobile/app/app.dart';
import 'package:libredb_mobile/app/bootstrap/app_session_listeners.dart';
import 'package:libredb_mobile/app/di/app_dependencies.dart';
import 'package:libredb_mobile/app/di/mock_sign_in_dependencies.dart';
import 'package:libredb_mobile/app/di/app_scope.dart';
import 'package:libredb_mobile/app/session/session_cubit.dart';
import 'package:libredb_mobile/app/session/platform_account_refusal_cubit.dart';
import 'package:libredb_mobile/app/session/studio_account_refusal_cubit.dart';
import 'package:libredb_mobile/app/shell/app_shell.dart';
import 'package:libredb_mobile/app/shell/platform_shell.dart';
import 'package:libredb_mobile/app/shell/responsive_scaffold.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/core/testing/app_key_constants.dart';
import 'package:libredb_mobile/features/auth/data/repositories/sso_sign_out_auth_repository.dart';
import 'package:libredb_mobile/features/auth/application/login_bloc.dart';
import 'package:libredb_mobile/features/auth/application/platform_identity_cubit.dart';
import 'package:libredb_mobile/features/auth/application/session_target_switch_bloc.dart';
import 'package:libredb_mobile/features/auth/application/studio_identity_cubit.dart';
import 'package:libredb_mobile/features/auth/application/usecases/switch_session_target_usecase.dart';
import 'package:libredb_mobile/features/auth/domain/entities/session_target_switch_result.dart';
import 'package:libredb_mobile/features/auth/domain/repositories/auth_session_repository.dart';
import 'package:libredb_mobile/features/auth/domain/repositories/platform_identity_repository.dart';
import 'package:libredb_mobile/features/auth/domain/repositories/studio_identity_repository.dart';
import 'package:libredb_mobile/features/app_lock/application/app_lock_bloc.dart';
import 'package:libredb_mobile/features/connections/application/connection_policy_cubit.dart';
import 'package:libredb_mobile/shared/active_connection/active_connection_cubit.dart';
import 'package:libredb_mobile/features/auth/application/sign_out_bloc.dart';
import 'package:libredb_mobile/features/auth/presentation/pages/login_page.dart';
import 'package:libredb_mobile/features/connections/application/favorite_connections_bloc.dart';
import 'package:libredb_mobile/features/connections/domain/entities/connection_favorites.dart';
import 'package:libredb_mobile/features/object_browser/data/repositories/cached_object_browser_repository.dart';
import 'package:libredb_mobile/features/auth/domain/services/sso_auto_redirect_gate.dart';
import 'package:libredb_mobile/infrastructure/auth/oidc/oidc_client.dart';
import 'package:libredb_mobile/infrastructure/cache/shared_prefs_cache_storage.dart';
import 'package:libredb_mobile/infrastructure/config/auth_config.dart';
import 'package:libredb_mobile/infrastructure/config/environment.dart';
import 'package:libredb_mobile/infrastructure/http/token_rotation.dart';
import 'package:libredb_mobile/infrastructure/storage/local_storage.dart';
import 'package:libredb_mobile/infrastructure/storage/secure_storage.dart';
import 'package:libredb_mobile/infrastructure/studio/cached_provider_meta_repository.dart';
import 'package:libredb_mobile/shared/models/platform_identity.dart';
import 'package:libredb_mobile/shared/models/session_target.dart';
import 'package:libredb_mobile/shared/models/studio_identity.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

import '../../mocks/mock_classes.dart';
import '../../support/test_env.dart';
import '../../support/user_menu.dart';

/// The app on the mock-backed development config, with the idle timeout turned on as production has it.
final _app = App(
  language: 'en',
  dependencies: MockSignInDependencies(
    appConfig: const AppConfig(
      environment: Environment.mock,
      apiBaseUrl: null,
      certificatePins: <String>[],
      idleTimeout: Duration(minutes: 5),
    ),
  ),
);

/// [_app] in a build that serves Platform mode too.
final _platformApp = App(
  language: 'en',
  dependencies: MockSignInDependencies(
    appConfig: const AppConfig(
      environment: Environment.mock,
      apiBaseUrl: null,
      certificatePins: <String>[],
      idleTimeout: Duration(minutes: 5),
      platform: PlatformConfigured(),
    ),
  ),
);

/// Stores the language, theme and brightness a user chose on this device earlier.
Future<void> _choosePreferences() async {
  await AppLocalStorage().save(StorageKeys.language.key, 'tr');
  await AppLocalStorage().save(StorageKeys.theme.key, 'nature');
  await AppLocalStorage().save(StorageKeys.brightness.key, 'dark');
}

/// Signs out as the user does: Logout in the user menu, then Yes in the confirmation dialog, in whichever language the
/// app shows.
Future<void> _logOut(WidgetTester tester) async {
  await selectFromUserMenu(tester, Icons.logout);
  await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.byType(FilledButton)));
  await tester.pumpAndSettle();
  // The app waits for Studio to record the sign-out, which the mock answers after its simulated latency.
  await tester.pump(SsoSignOutAuthRepository.defaultStudioSignOutTimeout);
  await tester.pumpAndSettle();
}

/// Signs out from the account refusal page: Logout, then Yes in the confirmation dialog.
Future<void> _logOutFromRefusalPage(WidgetTester tester) async {
  await tester.tap(find.byKey(accountRefusalSignOutKey));
  await tester.pumpAndSettle();
  await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.byType(FilledButton)));
  await tester.pumpAndSettle();
}

/// Leaves the app alone until the idle timeout signs the user out, and until its notice has gone.
Future<void> _idle(WidgetTester tester) async {
  await tester.pump(const Duration(minutes: 5));
  await tester.pumpAndSettle();
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpAndSettle();
}

/// The ways a session ends while the app keeps running for the next user of the device.
const _sessionEndings = <String, Future<void> Function(WidgetTester)>{'a logout': _logOut, 'an idle timeout': _idle};

/// Scrolls the page with a mouse wheel, which moves no pointer.
Future<void> _scrollWithWheel(WidgetTester tester) async {
  final mouse = TestPointer(1, PointerDeviceKind.mouse);
  await tester.sendEventToBinding(mouse.hover(tester.getCenter(find.byType(ResponsiveScaffold))));
  await tester.sendEventToBinding(mouse.scroll(const Offset(0, 100)));
}

/// Scrolls the page with two fingers on a trackpad, which sends pan and zoom events instead of pointer moves.
Future<void> _scrollWithTrackpad(WidgetTester tester) async {
  final trackpad = TestPointer(1, PointerDeviceKind.trackpad);
  final center = tester.getCenter(find.byType(ResponsiveScaffold));
  await tester.sendEventToBinding(trackpad.panZoomStart(center));
  await tester.sendEventToBinding(trackpad.panZoomUpdate(center, pan: const Offset(0, -100)));
  await tester.sendEventToBinding(trackpad.panZoomEnd());
}

/// Presses and releases a key, as typing in a form or moving the focus with the keyboard does.
Future<void> _pressKey(WidgetTester tester) async {
  await tester.sendKeyEvent(LogicalKeyboardKey.shiftLeft);
}

/// Input on desktop and web that touches no pointer down or move.
const _inputsWithoutPointerMoves = <String, Future<void> Function(WidgetTester)>{
  'mouse wheel scrolling': _scrollWithWheel,
  'trackpad scrolling': _scrollWithTrackpad,
  'typing': _pressKey,
};

/// Signs in with the single sign-on button, through the local sign-in of the mock-backed app.
Future<void> _signIn(WidgetTester tester) async {
  await tester.tap(find.byKey(loginButtonSsoKey));
  await tester.pumpAndSettle();
}

void main() {
  group('AppSessionListeners', () {
    testWidgets('an idle timeout clears the stored session, so a relaunch opens the login screen', (tester) async {
      TestEnv.authenticate();
      await FlutterSecureStorageAdapter().write(SecureStorageKeys.refreshToken.key, 'MOCK_REFRESH_TOKEN');
      await tester.pumpWidget(_app);
      await tester.pumpAndSettle();
      expect(find.byType(ResponsiveScaffold), findsOneWidget);

      await tester.pump(const Duration(minutes: 5));
      await tester.pumpAndSettle();
      expect(find.byKey(loginButtonSsoKey), findsOneWidget);

      // A relaunch mounts a new App, which restores the session from storage.
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(_app);
      await tester.pumpAndSettle();
      expect(find.byKey(loginButtonSsoKey), findsOneWidget);
      expect(find.byType(ResponsiveScaffold), findsNothing);
      expect(await FlutterSecureStorageAdapter().read(SecureStorageKeys.refreshToken.key), isNull);
    });

    testWidgets('an idle timeout tells the user on the login screen why they were signed out', (tester) async {
      TestEnv.authenticate();
      await tester.pumpWidget(_app);
      await tester.pumpAndSettle();
      expect(find.byType(ResponsiveScaffold), findsOneWidget);

      await tester.pump(const Duration(minutes: 5));
      await tester.pumpAndSettle();

      expect(find.byKey(loginButtonSsoKey), findsOneWidget);
      expect(find.text('You were signed out due to inactivity.').hitTestable(), findsOneWidget);
    });

    testWidgets('raises an error instead of dropping the idle timeout notice when no ScaffoldMessenger is mounted', (
      tester,
    ) async {
      TestEnv.authenticate();
      // The notice is shown from a stream listener, so its error is uncaught in the zone that built the listener.
      final errors = <Object>[];
      await runZonedGuarded(
        () => tester.pumpWidget(
          AppScope(
            dependencies: _app.dependencies,
            defaultLocale: const Locale('en'),
            child: AppSessionListeners(
              scaffoldMessengerKey: GlobalKey<ScaffoldMessengerState>(),
              child: const SizedBox(),
            ),
          ),
        ),
        (error, _) => errors.add(error),
      );
      await tester.pumpAndSettle();

      await tester.pump(const Duration(minutes: 5));
      await tester.pumpAndSettle();

      expect(errors, [isA<StateError>()]);
    });

    for (final MapEntry(key: ending, value: end) in _sessionEndings.entries) {
      testWidgets('$ending drops the object browser and provider-meta answers kept in memory', (tester) async {
        TestEnv.authenticate();
        await tester.pumpWidget(_app);
        await tester.pumpAndSettle();
        final scope = tester.element(find.byType(ResponsiveScaffold));
        final browser = scope.read<CachedObjectBrowserRepository>();
        final providerMeta = scope.read<CachedProviderMetaRepository>();
        final answers = await tester.runAsync(
          () => Future.wait([browser.containers('seed:sales-db'), providerMeta.providerMeta('seed:sales-db')]),
        );
        expect(answers, everyElement(isA<Success<Object>>()));
        expect((browser.entryCount, providerMeta.entryCount), (1, 1));

        await end(tester);

        expect(find.byKey(loginButtonSsoKey), findsOneWidget);
        expect((browser.entryCount, providerMeta.entryCount), (0, 0));
      });
    }

    for (final MapEntry(key: ending, value: end) in _sessionEndings.entries) {
      testWidgets('the favorites follow the subject Studio names, and $ending drops them from the screen', (
        tester,
      ) async {
        await AppLocalStorage().save(
          StorageKeys.connectionFavorites.key,
          '{"6f1c9a52-0d7e-4b8e-9f43-2b0c4b1f7a10": {"starred": ["seed:sales-db"], "recent": []}}',
        );
        await tester.pumpWidget(_app);
        await tester.pumpAndSettle();
        final favorites = tester.element(find.byType(MaterialApp)).read<FavoriteConnectionsBloc>();
        expect(favorites.state, const FavoriteConnectionsNone());

        await _signIn(tester);

        expect(
          favorites.state,
          const FavoriteConnectionsReady(ConnectionFavorites(starred: {'seed:sales-db'}, recent: [])),
        );

        await end(tester);

        expect(favorites.state, const FavoriteConnectionsNone());
        // The stars stay on the device for the next sign-in of the same account.
        expect(await AppLocalStorage().read(StorageKeys.connectionFavorites.key), contains('seed:sales-db'));
      });
    }

    for (final MapEntry(key: input, value: use) in _inputsWithoutPointerMoves.entries) {
      testWidgets('$input counts as activity, so the idle timeout waits for the full threshold after it', (
        tester,
      ) async {
        TestEnv.authenticate();
        await tester.pumpWidget(_app);
        await tester.pumpAndSettle();
        await tester.pump(const Duration(minutes: 4));

        await use(tester);
        await tester.pump(const Duration(minutes: 4));
        await tester.pumpAndSettle();
        expect(find.byType(ResponsiveScaffold), findsOneWidget);
        expect(find.byKey(loginButtonSsoKey), findsNothing);

        await tester.pump(const Duration(minutes: 1));
        await tester.pumpAndSettle();
        expect(find.byKey(loginButtonSsoKey), findsOneWidget);
      });
    }

    // Flutter synthesizes key events to match the keyboard state it finds, for example a key held down when the window
    // gained focus, so they do not show the user at work.
    testWidgets('a key event Flutter synthesized does not count as activity', (tester) async {
      TestEnv.authenticate();
      await tester.pumpWidget(_app);
      await tester.pumpAndSettle();
      await tester.pump(const Duration(minutes: 4));

      const physical = PhysicalKeyboardKey.shiftLeft;
      const logical = LogicalKeyboardKey.shiftLeft;
      HardwareKeyboard.instance.handleKeyEvent(
        const KeyDownEvent(physicalKey: physical, logicalKey: logical, timeStamp: Duration.zero, synthesized: true),
      );
      HardwareKeyboard.instance.handleKeyEvent(
        const KeyUpEvent(physicalKey: physical, logicalKey: logical, timeStamp: Duration.zero, synthesized: true),
      );
      await tester.pump(const Duration(minutes: 1));
      await tester.pumpAndSettle();

      expect(find.byKey(loginButtonSsoKey), findsOneWidget);
    });

    testWidgets('an idle timeout keeps the preferences and removes the cached responses', (tester) async {
      TestEnv.authenticate();
      await _choosePreferences();
      await tester.pumpWidget(_app);
      await tester.pumpAndSettle();
      await _cacheResponse();
      expect(await SharedPrefsCacheStorage().count(), isPositive);

      await tester.pump(const Duration(minutes: 5));
      await tester.pumpAndSettle();
      expect(find.byKey(loginButtonSsoKey), findsOneWidget);

      expect(await AppLocalStorage().read(StorageKeys.language.key), 'tr');
      expect(await AppLocalStorage().read(StorageKeys.theme.key), 'nature');
      expect(await AppLocalStorage().read(StorageKeys.brightness.key), 'dark');
      expect(await SharedPrefsCacheStorage().count(), 0);
    });

    testWidgets('a logout keeps the preferences and removes the cached responses', (tester) async {
      TestEnv.authenticate();
      await _choosePreferences();
      await tester.pumpWidget(_app);
      await tester.pumpAndSettle();
      await _cacheResponse();
      expect(await SharedPrefsCacheStorage().count(), isPositive);

      await _logOut(tester);
      expect(find.byKey(loginButtonSsoKey), findsOneWidget);

      expect(await AppLocalStorage().read(StorageKeys.language.key), 'tr');
      expect(await AppLocalStorage().read(StorageKeys.theme.key), 'nature');
      expect(await AppLocalStorage().read(StorageKeys.brightness.key), 'dark');
      expect(await SharedPrefsCacheStorage().count(), 0);

      // A relaunch mounts a new App, which loads the theme from storage.
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(_app);
      await tester.pumpAndSettle();
      expect(tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode, ThemeMode.dark);
    });

    testWidgets('a logout that cannot remove all stored data still signs out and tells the user', (tester) async {
      SharedPreferencesStorePlatform.instance = _CacheKeepingStore();
      TestEnv.authenticate();
      await tester.pumpWidget(_app);
      await tester.pumpAndSettle();
      await _cacheResponse();
      expect(await SharedPrefsCacheStorage().count(), isPositive);

      await _logOut(tester);

      expect(find.byKey(loginButtonSsoKey), findsOneWidget);
      expect(
        find.text('You were signed out, but some stored data could not be removed from this device.').hitTestable(),
        findsOneWidget,
      );
      expect(await FlutterSecureStorageAdapter().read(SecureStorageKeys.jwtToken.key), isNull);
    });

    group('with the identity provider', () {
      testWidgets('a logout whose provider logout fails signs out and says the provider session may be active', (
        tester,
      ) async {
        final client = _FakeOidcClient()..logoutOutcome = const ProviderLogoutFailed();
        TestEnv.authenticate();
        await tester.pumpWidget(App(language: 'en', dependencies: _OidcDependencies(client)));
        await tester.pumpAndSettle();
        expect(find.byType(ResponsiveScaffold), findsOneWidget);

        await _logOut(tester);

        expect(find.byKey(loginButtonSsoKey), findsOneWidget);
        expect(
          find
              .text('You are signed out of this app, but your session at the identity provider may still be active.')
              .hitTestable(),
          findsOneWidget,
        );
        expect(client.logouts, 1);
        expect(await FlutterSecureStorageAdapter().read(SecureStorageKeys.jwtToken.key), isNull);
      });

      testWidgets('a logout whose provider session ended shows no notice', (tester) async {
        final client = _FakeOidcClient();
        TestEnv.authenticate();
        await tester.pumpWidget(App(language: 'en', dependencies: _OidcDependencies(client)));
        await tester.pumpAndSettle();

        await _logOut(tester);

        expect(find.byKey(loginButtonSsoKey), findsOneWidget);
        expect(client.logouts, 1);
        expect(find.byType(SnackBar), findsNothing);
      });

      testWidgets('a session restored at startup closes the automatic redirect gate', (tester) async {
        TestEnv.authenticate();
        await tester.pumpWidget(App(language: 'en', dependencies: _OidcDependencies(_FakeOidcClient())));
        await tester.pumpAndSettle();
        expect(find.byType(ResponsiveScaffold), findsOneWidget);

        expect(tester.element(find.byType(MaterialApp)).read<SsoAutoRedirectGate>().isOpen, isFalse);
      });

      testWidgets('a sign-in closes the automatic redirect gate', (tester) async {
        await tester.pumpWidget(App(language: 'en', dependencies: _OidcDependencies(_FakeOidcClient())));
        await tester.pumpAndSettle();
        final app = tester.element(find.byType(MaterialApp));
        expect(app.read<SsoAutoRedirectGate>().isOpen, isTrue);

        // As the single sign-on button does.
        app.read<LoginBloc>().add(const SsoSignInRequested(target: SessionTarget.studio));
        await tester.pumpAndSettle();

        expect(app.read<LoginBloc>().state, isA<LoginLoadedState>());
        expect(app.read<SsoAutoRedirectGate>().isOpen, isFalse);
      });

      testWidgets('a sign-in marks the session authenticated for Studio and stores that target', (tester) async {
        await tester.pumpWidget(App(language: 'en', dependencies: _OidcDependencies(_FakeOidcClient())));
        await tester.pumpAndSettle();
        final app = tester.element(find.byType(MaterialApp));

        app.read<LoginBloc>().add(const SsoSignInRequested(target: SessionTarget.studio));
        await tester.pumpAndSettle();

        expect(app.read<LoginBloc>().state, const LoginLoadedState(target: SessionTarget.studio));
        expect(app.read<SessionCubit>().state, const SessionAuthenticated(target: SessionTarget.studio));
        expect(await FlutterSecureStorageAdapter().read(SecureStorageKeys.sessionTarget.key), 'studio');
      });

      testWidgets('a Platform sign-in marks the session authenticated for Platform and stores that target', (
        tester,
      ) async {
        await tester.pumpWidget(
          App(
            language: 'en',
            dependencies: _OidcDependencies(_FakeOidcClient(), appConfig: _platformApp.dependencies.appConfig),
          ),
        );
        await tester.pumpAndSettle();
        final app = tester.element(find.byType(MaterialApp));

        // As the Platform button does.
        app.read<LoginBloc>().add(const SsoSignInRequested(target: SessionTarget.platform));
        await tester.pumpAndSettle();

        expect(app.read<LoginBloc>().state, const LoginLoadedState(target: SessionTarget.platform));
        expect(app.read<SessionCubit>().state, const SessionAuthenticated(target: SessionTarget.platform));
        expect(await FlutterSecureStorageAdapter().read(SecureStorageKeys.sessionTarget.key), 'platform');
      });

      // A sign-in closes the gate as well, so this logout comes from a run that was never signed in.
      testWidgets('a logout closes the automatic redirect gate', (tester) async {
        await tester.pumpWidget(App(language: 'en', dependencies: _OidcDependencies(_FakeOidcClient())));
        await tester.pumpAndSettle();
        final app = tester.element(find.byType(MaterialApp));
        expect(app.read<SsoAutoRedirectGate>().isOpen, isTrue);

        app.read<SignOutBloc>().add(const SignOutRequested());
        await tester.pumpAndSettle();
        await tester.pump(SsoSignOutAuthRepository.defaultStudioSignOutTimeout);
        await tester.pumpAndSettle();

        expect(app.read<SignOutBloc>().state, isA<SignOutDone>());
        expect(app.read<SsoAutoRedirectGate>().isOpen, isFalse);
      });
    });

    for (final MapEntry(key: ending, value: endSession) in _sessionEndings.entries) {
      testWidgets('after $ending, the next user finds a blank login page', (tester) async {
        await tester.pumpWidget(_app);
        await tester.pumpAndSettle();
        await _signIn(tester);
        expect(find.byType(ResponsiveScaffold), findsOneWidget);

        await endSession(tester);

        expect(find.byType(LoginScreen), findsOneWidget);
        expect(tester.element(find.byType(MaterialApp)).read<LoginBloc>().state, const LoginInitialState());
      });
    }

    // The idle timeout looks at no session target.
    testWidgets('an idle timeout ends a Platform session and tells the user on the login screen', (tester) async {
      TestEnv.authenticate(target: SessionTarget.platform);
      await tester.pumpWidget(_platformApp);
      await tester.pumpAndSettle();
      expect(find.byType(PlatformShell), findsOneWidget);

      await tester.pump(const Duration(minutes: 5));
      await tester.pumpAndSettle();

      expect(find.byKey(loginButtonSsoKey), findsOneWidget);
      expect(find.text('You were signed out due to inactivity.').hitTestable(), findsOneWidget);
      expect(await FlutterSecureStorageAdapter().read(SecureStorageKeys.jwtToken.key), isNull);
    });

    // The Platform refusal page covers the profile sheet, so its own Logout is the logout here.
    for (final (ending, endSession) in <(String, Future<void> Function(WidgetTester))>[
      ('a logout from the refusal page', _logOutFromRefusalPage),
      ('an idle timeout', _idle),
    ]) {
      testWidgets('after $ending of a Platform session, its identity and refusal are forgotten', (tester) async {
        TestEnv.authenticate(target: SessionTarget.platform);
        await tester.pumpWidget(_platformApp);
        await tester.pumpAndSettle();
        // The mock answers the identity after its latency.
        await tester.pump(const Duration(seconds: 1));
        await tester.pumpAndSettle();
        final app = tester.element(find.byType(MaterialApp));
        final identity = app.read<PlatformIdentityCubit>();
        final refusal = app.read<PlatformAccountRefusalCubit>();
        expect(identity.state, isA<PlatformIdentityLoaded>());
        refusal.refuse(AppErrorCode.platformLicenseAdminSeats);
        await tester.pumpAndSettle();

        await endSession(tester);

        expect(find.byType(LoginScreen), findsOneWidget);
        expect(identity.state, const PlatformIdentityInitial());
        expect(refusal.state, const PlatformAccountAccepted());
      });
    }

    // A mode switch is no sign-out: it clears only the in-memory state of the mode it leaves, fills the identity of the
    // mode it opens from the gate's answer, and opens that mode's home.
    group('a mode switch', () {
      late _RecordingObserver observer;

      setUp(() {
        final previous = Bloc.observer;
        observer = _RecordingObserver();
        Bloc.observer = observer;
        addTearDown(() => Bloc.observer = previous);
      });

      /// Waits for the mock's latency of the gate, then for what the switch opens.
      Future<void> settle(WidgetTester tester) async {
        await tester.pump(const Duration(seconds: 1));
        await tester.pumpAndSettle();
        await tester.pump(const Duration(seconds: 1));
        await tester.pumpAndSettle();
      }

      testWidgets('from Studio clears the Studio state, fills the Platform identity and opens the Platform home', (
        tester,
      ) async {
        await AppLocalStorage().save(
          StorageKeys.connectionFavorites.key,
          '{"6f1c9a52-0d7e-4b8e-9f43-2b0c4b1f7a10": {"starred": ["seed:sales-db"], "recent": []}}',
        );
        TestEnv.authenticate();
        await tester.pumpWidget(_platformApp);
        await settle(tester);
        expect(find.byType(AppShell), findsOneWidget);
        final app = tester.element(find.byType(MaterialApp));
        expect(app.read<StudioIdentityCubit>().state, isA<StudioIdentityLoaded>());
        final refusal = app.read<StudioAccountRefusalCubit>()..refuse(AppErrorCode.studioAccountHasNoRole);
        final browser = app.read<CachedObjectBrowserRepository>();
        await tester.runAsync(() => browser.containers('seed:sales-db'));
        expect(browser.entryCount, 1);
        observer.events.clear();

        app.read<SessionTargetSwitchBloc>().add(const SessionTargetSwitchRequested(SessionTarget.platform));
        await settle(tester);

        expect(app.read<SessionCubit>().state, const SessionAuthenticated(target: SessionTarget.platform));
        expect(find.byType(PlatformShell), findsOneWidget);
        expect(app.read<PlatformIdentityCubit>().state, isA<PlatformIdentityLoaded>());
        expect(app.read<StudioIdentityCubit>().state, const StudioIdentityInitial());
        expect(app.read<ConnectionPolicyCubit>().state, const ConnectionPolicyInitial());
        expect(refusal.state, const StudioAccountAccepted());
        expect(app.read<ActiveConnectionCubit>().state.connection, isNull);
        expect(browser.entryCount, 0);
        expect(app.read<FavoriteConnectionsBloc>().state, const FavoriteConnectionsNone());
        // Only the target changed in storage, and what the account stored on the device stays.
        expect(await FlutterSecureStorageAdapter().read(SecureStorageKeys.sessionTarget.key), 'platform');
        expect(await FlutterSecureStorageAdapter().read(SecureStorageKeys.jwtToken.key), 'MOCK_TOKEN');
        expect(await AppLocalStorage().read(StorageKeys.connectionFavorites.key), contains('seed:sales-db'));
        expect(observer.events.whereType<AppLockEvent>(), isEmpty, reason: 'no app lock event');
        expect(observer.events.whereType<LoginReset>(), isEmpty, reason: 'the sign-in form is left alone');
        expect(observer.events.whereType<SignOutRequested>(), isEmpty, reason: 'no sign-out');
      });

      testWidgets('from Platform clears the Platform state, fills the Studio identity and opens the Studio home', (
        tester,
      ) async {
        TestEnv.authenticate(target: SessionTarget.platform);
        await tester.pumpWidget(_platformApp);
        await settle(tester);
        expect(find.byType(PlatformShell), findsOneWidget);
        final app = tester.element(find.byType(MaterialApp));
        expect(app.read<PlatformIdentityCubit>().state, isA<PlatformIdentityLoaded>());
        final refusal = app.read<PlatformAccountRefusalCubit>();
        observer.events.clear();

        app.read<SessionTargetSwitchBloc>().add(const SessionTargetSwitchRequested(SessionTarget.studio));
        await settle(tester);

        expect(app.read<SessionCubit>().state, const SessionAuthenticated(target: SessionTarget.studio));
        expect(find.byType(AppShell), findsOneWidget);
        expect(
          app.read<StudioIdentityCubit>().state,
          isA<StudioIdentityLoaded>().having((s) => s.identity.username, 'username', 'admin@example.com'),
        );
        expect(app.read<PlatformIdentityCubit>().state, const PlatformIdentityInitial());
        expect(refusal.state, const PlatformAccountAccepted());
        expect(await FlutterSecureStorageAdapter().read(SecureStorageKeys.sessionTarget.key), 'studio');
        expect(observer.events.whereType<AppLockEvent>(), isEmpty, reason: 'no app lock event');
      });

      testWidgets('keeps the idle timeout running', (tester) async {
        TestEnv.authenticate();
        await tester.pumpWidget(_platformApp);
        await settle(tester);
        final app = tester.element(find.byType(MaterialApp));

        app.read<SessionTargetSwitchBloc>().add(const SessionTargetSwitchRequested(SessionTarget.platform));
        await settle(tester);
        expect(find.byType(PlatformShell), findsOneWidget);

        await tester.pump(const Duration(minutes: 5));
        await tester.pumpAndSettle();

        expect(find.byKey(loginButtonSsoKey), findsOneWidget);
        expect(find.text('You were signed out due to inactivity.').hitTestable(), findsOneWidget);
      });

      testWidgets('does nothing when the session ends while the gate is asked, and leaves no target stored', (
        tester,
      ) async {
        TestEnv.authenticate();
        await tester.pumpWidget(_platformApp);
        await settle(tester);
        final app = tester.element(find.byType(MaterialApp));

        app.read<SessionTargetSwitchBloc>().add(const SessionTargetSwitchRequested(SessionTarget.platform));
        await tester.pump();
        await app.read<SessionCubit>().endSession(reason: SessionExpiredReason.idleTimeout);
        await settle(tester);

        expect(app.read<SessionCubit>().state, isA<SessionUnauthenticated>());
        expect(find.byKey(loginButtonSsoKey), findsOneWidget);
        expect(app.read<PlatformIdentityCubit>().state, const PlatformIdentityInitial());
        expect(await FlutterSecureStorageAdapter().read(SecureStorageKeys.sessionTarget.key), isNull);
        expect(await FlutterSecureStorageAdapter().read(SecureStorageKeys.jwtToken.key), isNull);
      });

      // The switch answers only after the session ended, as when a 401 ends it while the gate is asked; the stored
      // target guard cannot stop that answer here, because the use case is a double that answers success anyway.
      for (final (from, to, result) in <(SessionTarget, SessionTarget, SessionTargetSwitchResult)>[
        (SessionTarget.studio, SessionTarget.platform, const SwitchedToPlatform(_platformAdmin)),
        (SessionTarget.platform, SessionTarget.studio, const SwitchedToStudio(_studioAdmin)),
      ]) {
        testWidgets('to ${to.name} that succeeds after the session ended opens nothing and fills no identity', (
          tester,
        ) async {
          final answer = Completer<SessionTargetSwitchResult>();
          final switchTarget = MockSwitchSessionTargetUseCase();
          when(() => switchTarget(to)).thenAnswer((_) => answer.future);
          TestEnv.authenticate(target: from);
          await tester.pumpWidget(_appWithSwitch(switchTarget));
          await settle(tester);
          final app = tester.element(find.byType(MaterialApp));

          app.read<SessionTargetSwitchBloc>().add(SessionTargetSwitchRequested(to));
          await tester.pump();
          await app.read<SessionCubit>().endSession(reason: SessionExpiredReason.expired);
          await settle(tester);
          expect(find.byKey(loginButtonSsoKey), findsOneWidget);
          observer.states.clear();
          answer.complete(result);
          await settle(tester);

          expect(app.read<SessionTargetSwitchBloc>().state, SessionTargetSwitchSucceeded(result));
          // Not even for a moment: a session marked authenticated again would send requests the next 401 ends.
          expect(observer.states.whereType<SessionAuthenticated>(), isEmpty, reason: 'no markAuthenticated');
          expect(observer.states.whereType<PlatformIdentityLoaded>(), isEmpty);
          expect(observer.states.whereType<StudioIdentityLoaded>(), isEmpty);
          expect(app.read<SessionCubit>().state, isA<SessionUnauthenticated>());
          expect(find.byKey(loginButtonSsoKey), findsOneWidget);
          expect(app.read<PlatformIdentityCubit>().state, const PlatformIdentityInitial());
          expect(app.read<StudioIdentityCubit>().state, const StudioIdentityInitial());
        });
      }

      testWidgets('that is refused after the session ended shows no notice on the login page', (tester) async {
        final answer = Completer<SessionTargetSwitchResult>();
        final switchTarget = MockSwitchSessionTargetUseCase();
        when(() => switchTarget(SessionTarget.platform)).thenAnswer((_) => answer.future);
        TestEnv.authenticate();
        await tester.pumpWidget(_appWithSwitch(switchTarget));
        await settle(tester);
        final app = tester.element(find.byType(MaterialApp));

        app.read<SessionTargetSwitchBloc>().add(const SessionTargetSwitchRequested(SessionTarget.platform));
        await tester.pump();
        await app.read<SessionCubit>().endSession(reason: SessionExpiredReason.expired);
        await settle(tester);
        expect(find.byKey(loginButtonSsoKey), findsOneWidget);
        answer.complete(const SessionTargetSwitchRefused(AppErrorCode.platformAdminRoleRequired));
        await settle(tester);

        expect(
          app.read<SessionTargetSwitchBloc>().state,
          const SessionTargetSwitchRefusedState(AppErrorCode.platformAdminRoleRequired),
        );
        expect(find.byKey(loginButtonSsoKey), findsOneWidget);
        expect(find.byType(SnackBar), findsNothing);
      });

      testWidgets('that is refused while signed in says why in the mode the user stayed in', (tester) async {
        final switchTarget = MockSwitchSessionTargetUseCase();
        when(() => switchTarget(SessionTarget.platform))
            .thenAnswer((_) async => const SessionTargetSwitchRefused(AppErrorCode.platformAdminRoleRequired));
        TestEnv.authenticate();
        await tester.pumpWidget(_appWithSwitch(switchTarget));
        await settle(tester);
        final app = tester.element(find.byType(MaterialApp));

        app.read<SessionTargetSwitchBloc>().add(const SessionTargetSwitchRequested(SessionTarget.platform));
        await tester.pumpAndSettle();

        expect(app.read<SessionCubit>().state, const SessionAuthenticated(target: SessionTarget.studio));
        expect(find.byType(AppShell), findsOneWidget);
        expect(find.text('This account is not a Platform admin, so it stays in Studio.'), findsOneWidget);
      });

      testWidgets('a cold restart after a switch restores the new target', (tester) async {
        TestEnv.authenticate();
        await tester.pumpWidget(_platformApp);
        await settle(tester);
        tester
            .element(find.byType(MaterialApp))
            .read<SessionTargetSwitchBloc>()
            .add(const SessionTargetSwitchRequested(SessionTarget.platform));
        await settle(tester);

        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(_platformApp);
        await settle(tester);

        expect(find.byType(PlatformShell), findsOneWidget);
      });
    });

    // The logout from the refusal page is tested with the page, in studio_account_refusal_shell_test.dart.
    testWidgets('after an idle timeout, the refusal of the signed-out account is forgotten', (tester) async {
      await tester.pumpWidget(_app);
      await tester.pumpAndSettle();
      await _signIn(tester);
      final refusal = tester.element(find.byType(MaterialApp)).read<StudioAccountRefusalCubit>();
      refusal.refuse(AppErrorCode.studioAccountHasNoRole);

      await _idle(tester);

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(refusal.state, const StudioAccountAccepted());
    });
  });
}

/// The identity provider: a sign-in succeeds as a user, and a provider
/// logout ends with [logoutOutcome], counted in [logouts].
class _FakeOidcClient implements IOidcClient {
  OidcLogoutOutcome logoutOutcome = const ProviderSessionEnded();
  var logouts = 0;

  @override
  Future<OidcSignInOutcome> signIn() async => OidcSignedIn(
    tokens: OidcTokens(
      accessToken: 'sso-access-token',
      idToken: 'sso-id-token',
      refreshToken: 'sso-refresh-token',
      accessTokenExpiresAt: DateTime.utc(2100),
    ),
    claims: const {
      'iss': 'https://id.example.com/realms/demo',
      'sub': 'subject-1',
      'roles': ['admin'],
    },
  );

  @override
  Future<TokenRotationResult> refresh({
    required String refreshToken,
    required String idToken,
    required String accessToken,
    required DateTime accessTokenExpiresAt,
  }) => throw UnimplementedError('these tests store no expired session');

  @override
  Future<OidcLogoutOutcome> endProviderSession({String? idTokenHint}) async {
    logouts++;
    return logoutOutcome;
  }
}

/// The dependencies of [_app] over [client].
class _OidcDependencies extends AppDependencies {
  _OidcDependencies(this.client, {AppConfig? appConfig})
    : super(
        appConfig: appConfig ?? _app.dependencies.appConfig,
        authMode: OidcAuthMode(OidcSettings(issuer: Uri.parse('https://id.example.com/realms/demo'), clientId: 'app')),
      );

  final IOidcClient client;

  @override
  IOidcClient createOidcClient(OidcSettings settings) => client;
}

/// Leaves a cached response as a GET outside Studio's live endpoints does. Since the app config check is gone, the app
/// caches nothing on its way to the connection list, whose requests are all live.
Future<void> _cacheResponse() =>
    SharedPrefsCacheStorage().write('GET_https://api.example.test/storage/config', '{"storageProvider":"local"}');

/// A SharedPreferences platform store that keeps the cached responses when asked to remove them, as a full or
/// read-only disk does.
class _CacheKeepingStore extends InMemorySharedPreferencesStore {
  _CacheKeepingStore() : super.empty();

  @override
  Future<bool> remove(String key) async => key.startsWith('flutter._cache_') ? false : super.remove(key);
}

/// Records every event a BLoC is sent.
/// [_platformApp] with [switchTarget] in place of the use case that asks the gate of the target switched to.
App _appWithSwitch(SwitchSessionTargetUseCase switchTarget) => App(
  language: 'en',
  dependencies: _SwitchDependencies(
    switchTarget,
    appConfig: const AppConfig(
      environment: Environment.mock,
      apiBaseUrl: null,
      certificatePins: <String>[],
      idleTimeout: Duration(minutes: 5),
      platform: PlatformConfigured(),
    ),
  ),
);

class _SwitchDependencies extends MockSignInDependencies {
  _SwitchDependencies(this._switchTarget, {super.appConfig});

  final SwitchSessionTargetUseCase _switchTarget;

  @override
  SwitchSessionTargetUseCase createSwitchSessionTargetUseCase(
    IStudioIdentityRepository studioIdentity,
    IPlatformIdentityRepository? platformIdentity,
    IAuthSessionRepository sessionRepository,
  ) => _switchTarget;
}

const _platformAdmin = PlatformIdentity(
  id: 'u1',
  email: 'admin@example.com',
  roles: ['admin'],
  permissions: [],
  tenant: PlatformTenant(id: 't1', name: 'Example Org', slug: 'example-org'),
);

const _studioAdmin = StudioIdentity(username: 'admin@example.com', role: StudioAdminRole());

class _RecordingObserver extends BlocObserver {
  final events = <Object?>[];

  /// The states every bloc and cubit moved to, in order.
  final states = <Object?>[];

  @override
  void onEvent(Bloc<dynamic, dynamic> bloc, Object? event) {
    super.onEvent(bloc, event);
    events.add(event);
  }

  @override
  void onChange(BlocBase<dynamic> bloc, Change<dynamic> change) {
    super.onChange(bloc, change);
    states.add(change.nextState);
  }
}
