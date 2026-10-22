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
import 'package:libredb_mobile/app/di/app_scope.dart';
import 'package:libredb_mobile/app/shell/responsive_scaffold.dart';
import 'package:libredb_mobile/core/testing/app_key_constants.dart';
import 'package:libredb_mobile/features/auth/application/login_bloc.dart';
import 'package:libredb_mobile/features/auth/application/sign_out_bloc.dart';
import 'package:libredb_mobile/features/auth/presentation/pages/login_page.dart';
import 'package:libredb_mobile/features/auth/domain/services/sso_auto_redirect_gate.dart';
import 'package:libredb_mobile/infrastructure/auth/oidc/oidc_client.dart';
import 'package:libredb_mobile/infrastructure/cache/shared_prefs_cache_storage.dart';
import 'package:libredb_mobile/infrastructure/config/auth_config.dart';
import 'package:libredb_mobile/infrastructure/config/environment.dart';
import 'package:libredb_mobile/infrastructure/http/token_rotation.dart';
import 'package:libredb_mobile/infrastructure/storage/local_storage.dart';
import 'package:libredb_mobile/infrastructure/storage/secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

import '../../support/test_env.dart';
import '../../support/user_menu.dart';

/// The app on the mock-backed development config, with the idle timeout turned on as production has it.
const _app = App(
  language: 'en',
  dependencies: AppDependencies(
    appConfig: AppConfig(
      environment: Environment.dev,
      apiBaseUrl: null,
      certificatePins: <String>[],
      idleTimeout: Duration(minutes: 5),
    ),
  ),
);

/// Stores the language, theme and brightness a user chose on this device earlier, and a device preference of an earlier
/// app version.
Future<void> _choosePreferences() async {
  await AppLocalStorage().save(StorageKeys.language.key, 'tr');
  await AppLocalStorage().save(StorageKeys.theme.key, 'nature');
  await AppLocalStorage().save(StorageKeys.brightness.key, 'dark');
  await AppLocalStorage().save(StorageKeys.sidebarCollapsed.key, 'true');
}

/// Signs out as the user does: Logout in the user menu, then Yes in the confirmation dialog, in whichever language the
/// app shows.
Future<void> _logOut(WidgetTester tester) async {
  await selectFromUserMenu(tester, Icons.logout);
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

/// Signs in through the login form. The mock API accepts any username and password.
Future<void> _signIn(WidgetTester tester, String username) async {
  await tester.enterText(find.byKey(loginTextFieldUsernameKey), username);
  await tester.enterText(find.byKey(loginTextFieldPasswordKey), 'password');
  await tester.tap(find.byKey(loginButtonSubmitKey));
  await tester.pumpAndSettle();
}

void main() {
  group('AppSessionListeners', () {
    testWidgets('an idle timeout clears the stored session, so a relaunch opens the login screen', (tester) async {
      TestEnv.authenticate();
      await FlutterSecureStorageAdapter().write(SecureStorageKeys.refreshToken.key, 'MOCK_REFRESH_TOKEN');
      await AppLocalStorage().save(StorageKeys.roles.key, <String>['ROLE_ADMIN']);
      await tester.pumpWidget(_app);
      await tester.pumpAndSettle();
      expect(find.byType(ResponsiveScaffold), findsOneWidget);

      await tester.pump(const Duration(minutes: 5));
      await tester.pumpAndSettle();
      expect(find.byKey(loginButtonSubmitKey), findsOneWidget);

      // A relaunch mounts a new App, which restores the session from storage.
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(_app);
      await tester.pumpAndSettle();
      expect(find.byKey(loginButtonSubmitKey), findsOneWidget);
      expect(find.byType(ResponsiveScaffold), findsNothing);
      expect(await FlutterSecureStorageAdapter().read(SecureStorageKeys.refreshToken.key), isNull);
      expect(await AppLocalStorage().read(StorageKeys.roles.key), isNull);
    });

    testWidgets('an idle timeout tells the user on the login screen why they were signed out', (tester) async {
      TestEnv.authenticate();
      await tester.pumpWidget(_app);
      await tester.pumpAndSettle();
      expect(find.byType(ResponsiveScaffold), findsOneWidget);

      await tester.pump(const Duration(minutes: 5));
      await tester.pumpAndSettle();

      expect(find.byKey(loginButtonSubmitKey), findsOneWidget);
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
        expect(find.byKey(loginButtonSubmitKey), findsNothing);

        await tester.pump(const Duration(minutes: 1));
        await tester.pumpAndSettle();
        expect(find.byKey(loginButtonSubmitKey), findsOneWidget);
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

      expect(find.byKey(loginButtonSubmitKey), findsOneWidget);
    });

    testWidgets('an idle timeout keeps the preferences and removes the cached responses', (tester) async {
      TestEnv.authenticate();
      await _choosePreferences();
      await tester.pumpWidget(_app);
      await tester.pumpAndSettle();
      expect(await SharedPrefsCacheStorage().count(), isPositive, reason: 'the dashboard caches its account request');

      await tester.pump(const Duration(minutes: 5));
      await tester.pumpAndSettle();
      expect(find.byKey(loginButtonSubmitKey), findsOneWidget);

      expect(await AppLocalStorage().read(StorageKeys.language.key), 'tr');
      expect(await AppLocalStorage().read(StorageKeys.theme.key), 'nature');
      expect(await AppLocalStorage().read(StorageKeys.brightness.key), 'dark');
      expect(await AppLocalStorage().read(StorageKeys.sidebarCollapsed.key), 'true');
      expect(await SharedPrefsCacheStorage().count(), 0);
    });

    testWidgets('a logout keeps the preferences and removes the cached responses', (tester) async {
      TestEnv.authenticate();
      await _choosePreferences();
      await tester.pumpWidget(_app);
      await tester.pumpAndSettle();
      expect(await SharedPrefsCacheStorage().count(), isPositive, reason: 'the dashboard caches its account request');

      await _logOut(tester);
      expect(find.byKey(loginButtonSubmitKey), findsOneWidget);

      expect(await AppLocalStorage().read(StorageKeys.language.key), 'tr');
      expect(await AppLocalStorage().read(StorageKeys.theme.key), 'nature');
      expect(await AppLocalStorage().read(StorageKeys.brightness.key), 'dark');
      expect(await AppLocalStorage().read(StorageKeys.sidebarCollapsed.key), 'true');
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
      expect(await SharedPrefsCacheStorage().count(), isPositive, reason: 'the dashboard caches its account request');

      await _logOut(tester);

      expect(find.byKey(loginButtonSubmitKey), findsOneWidget);
      expect(
        find.text('You were signed out, but some stored data could not be removed from this device.').hitTestable(),
        findsOneWidget,
      );
      expect(await FlutterSecureStorageAdapter().read(SecureStorageKeys.jwtToken.key), isNull);
    });

    group('in an oidc build', () {
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
        app.read<LoginBloc>().add(const SsoSignInRequested());
        await tester.pumpAndSettle();

        expect(app.read<LoginBloc>().state, isA<LoginLoadedState>());
        expect(app.read<SsoAutoRedirectGate>().isOpen, isFalse);
      });

      // A sign-in closes the gate as well, so this logout comes from a run that was never signed in.
      testWidgets('a logout closes the automatic redirect gate', (tester) async {
        await tester.pumpWidget(App(language: 'en', dependencies: _OidcDependencies(_FakeOidcClient())));
        await tester.pumpAndSettle();
        final app = tester.element(find.byType(MaterialApp));
        expect(app.read<SsoAutoRedirectGate>().isOpen, isTrue);

        app.read<SignOutBloc>().add(const SignOutRequested());
        await tester.pumpAndSettle();

        expect(app.read<SignOutBloc>().state, isA<SignOutDone>());
        expect(app.read<SsoAutoRedirectGate>().isOpen, isFalse);
      });
    });

    // A jwt build provides no gate, so reading it would throw ProviderNotFoundException. A misconfigured oidc build
    // never restores a session an earlier build left, see app_session_listeners_sso_test.dart.
    for (final (build, authMode) in <(String, AuthMode)>[('a jwt build', const JwtAuthMode())]) {
      testWidgets('in $build, a session left by an earlier build and a logout read no gate', (tester) async {
        TestEnv.authenticate();
        await tester.pumpWidget(
          App(
            language: 'en',
            dependencies: AppDependencies(appConfig: _app.dependencies.appConfig, authMode: authMode),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(ResponsiveScaffold), findsOneWidget);
        expect(
          () => tester.element(find.byType(MaterialApp)).read<SsoAutoRedirectGate>(),
          throwsA(isA<ProviderNotFoundException>()),
        );

        await _logOut(tester);

        expect(find.byKey(loginButtonSubmitKey), authMode is JwtAuthMode ? findsOneWidget : findsNothing);
        expect(find.byType(LoginScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    for (final MapEntry(key: ending, value: endSession) in _sessionEndings.entries) {
      testWidgets('after $ending, the next user types their password hidden', (tester) async {
        await tester.pumpWidget(_app);
        await tester.pumpAndSettle();
        // The first user shows the password while typing it.
        await tester.tap(find.byKey(loginButtonPasswordVisibilityKey));
        await tester.pump();
        await _signIn(tester, 'admin');

        await endSession(tester);

        final password = find.descendant(of: find.byKey(loginTextFieldPasswordKey), matching: find.byType(TextField));
        expect(tester.widget<TextField>(password).obscureText, isTrue);
      });
    }
  });
}

/// The identity provider of an oidc build: a sign-in succeeds as a user, and a provider
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

/// The dependencies of [_app] in an oidc build over [client].
class _OidcDependencies extends AppDependencies {
  _OidcDependencies(this.client)
    : super(
        appConfig: _app.dependencies.appConfig,
        authMode: OidcAuthMode(
          OidcSettings(issuer: Uri.parse('https://id.example.com/realms/demo'), clientId: 'app', roleClaim: 'roles'),
        ),
      );

  final IOidcClient client;

  @override
  IOidcClient createOidcClient(OidcSettings settings) => client;
}

/// A SharedPreferences platform store that keeps the cached responses when asked to remove them, as a full or
/// read-only disk does.
class _CacheKeepingStore extends InMemorySharedPreferencesStore {
  _CacheKeepingStore() : super.empty();

  @override
  Future<bool> remove(String key) async => key.startsWith('flutter._cache_') ? false : super.remove(key);
}
