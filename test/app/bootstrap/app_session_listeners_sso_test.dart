@Tags(['widget'])
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:libredb_mobile/infrastructure/cache/shared_prefs_cache_storage.dart';
import 'package:libredb_mobile/app/app.dart';
import 'package:libredb_mobile/app/di/app_dependencies.dart';
import 'package:libredb_mobile/app/session/session_cubit.dart';
import 'package:libredb_mobile/app/shell/responsive_scaffold.dart';
import 'package:libredb_mobile/core/testing/app_key_constants.dart';
import 'package:libredb_mobile/features/auth/data/repositories/sso_sign_out_auth_repository.dart';
import 'package:libredb_mobile/features/auth/domain/services/sso_auto_redirect_gate.dart';
import 'package:libredb_mobile/infrastructure/auth/oidc/oidc_client.dart';
import 'package:libredb_mobile/infrastructure/config/auth_config.dart';
import 'package:libredb_mobile/infrastructure/config/environment.dart';
import 'package:libredb_mobile/infrastructure/http/token_rotation.dart';
import 'package:libredb_mobile/infrastructure/storage/secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

import '../../support/test_env.dart';
import '../../support/user_menu.dart';

const _appConfig = AppConfig(
  environment: Environment.dev,
  apiBaseUrl: null,
  certificatePins: <String>[],
  idleTimeout: Duration(minutes: 5),
);

const _providerSessionLeft =
    'You are signed out of this app, but your session at the identity provider may still be active.';

const _storedDataLeft = 'You were signed out, but some stored data could not be removed from this device.';

/// The identity provider. A provider logout ends when the test completes [logout], so a test can
/// hold it open as the browser flow does while the user is still at the provider; [signIns] counts the sign-ins the
/// app starts.
class _FakeOidcClient implements IOidcClient {
  final logout = Completer<OidcLogoutOutcome>();
  var logouts = 0;
  var signIns = 0;

  @override
  Future<OidcSignInOutcome> signIn() async {
    signIns++;
    return const OidcSignInCancelled();
  }

  @override
  Future<TokenRotationResult> refresh({
    required String refreshToken,
    required String idToken,
    required String accessToken,
    required DateTime accessTokenExpiresAt,
  }) => throw UnimplementedError('these tests store no expired session');

  @override
  Future<OidcLogoutOutcome> endProviderSession({String? idTokenHint}) {
    logouts++;
    return logout.future;
  }
}

/// The dependencies over [client], on the mock-backed development config.
class _OidcDependencies extends AppDependencies {
  _OidcDependencies(this.client, {bool autoRedirect = false})
    : super(
        appConfig: _appConfig,
        authMode: OidcAuthMode(
          OidcSettings(
            issuer: Uri.parse('https://id.example.com/realms/demo'),
            clientId: 'app',
            autoRedirect: autoRedirect,
          ),
        ),
      );

  final IOidcClient client;

  @override
  IOidcClient createOidcClient(OidcSettings settings) => client;
}

/// The secure store of the session in memory, whose reads of the access token wait until the test completes
/// [release], as a keychain that waits for its password does.
class _SlowAccessTokenStorage implements ISecureStorage {
  final release = Completer<void>();
  final values = <String, String>{};

  @override
  Future<String?> read(String key) async {
    if (key == SecureStorageKeys.jwtToken.key) await release.future;
    return values[key];
  }

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<void> deleteAll() async => values.clear();

  @override
  Future<Set<String>> keys() => throw UnimplementedError('not used by this test');
}

/// A SharedPreferences platform store that keeps the cached responses when asked to remove them, as a full or
/// read-only disk does.
/// Leaves a cached response as a GET outside Studio's live endpoints does. Since the app config check is gone, the app
/// caches nothing on its way to the connection list, whose requests are all live.
Future<void> _cacheResponse() =>
    SharedPrefsCacheStorage().write('GET_https://api.example.test/storage/config', '{"storageProvider":"local"}');

class _CacheKeepingStore extends InMemorySharedPreferencesStore {
  _CacheKeepingStore() : super.empty();

  @override
  Future<bool> remove(String key) async => key.startsWith('flutter._cache_') ? false : super.remove(key);
}

/// Signs out as the user does: Logout in the user menu, then Yes in the confirmation dialog.
Future<void> _logOut(WidgetTester tester) async {
  await selectFromUserMenu(tester, Icons.logout);
  await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.byType(FilledButton)));
  await tester.pumpAndSettle();
  // The app waits for Studio to record the sign-out, which the mock answers after its simulated latency.
  await tester.pump(SsoSignOutAuthRepository.defaultStudioSignOutTimeout);
  await tester.pumpAndSettle();
}

/// Starts the app over [client] with the mock session stored, on the connection list.
Future<void> _startSignedIn(WidgetTester tester, _FakeOidcClient client) async {
  TestEnv.authenticate();
  await tester.pumpWidget(App(language: 'en', dependencies: _OidcDependencies(client)));
  await tester.pumpAndSettle();
  expect(find.byType(ResponsiveScaffold), findsOneWidget);
}

BuildContext _app(WidgetTester tester) => tester.element(find.byType(MaterialApp));

void main() {
  // The provider logout waits for the browser, and for as long as the discovery request hangs.
  group('a logout the user starts', () {
    testWidgets('opens the login page while the provider logout has not ended', (tester) async {
      final client = _FakeOidcClient();
      await _startSignedIn(tester, client);

      await _logOut(tester);

      expect(client.logouts, 1);
      expect(find.byKey(loginButtonSsoKey), findsOneWidget);
      expect(find.byType(ResponsiveScaffold), findsNothing);
      expect(
        _app(tester).read<SessionCubit>().state,
        const SessionUnauthenticated(reason: SessionExpiredReason.noToken),
      );
      expect(_app(tester).read<SsoAutoRedirectGate>().isOpen, isFalse);
      expect(await FlutterSecureStorageAdapter().read(SecureStorageKeys.jwtToken.key), isNull);
      expect(find.byType(SnackBar), findsNothing);

      client.logout.complete(const ProviderSessionEnded());
      await tester.pumpAndSettle();
    });

    testWidgets('says the provider session may be active when the provider logout fails later', (tester) async {
      final client = _FakeOidcClient();
      await _startSignedIn(tester, client);
      await _logOut(tester);
      expect(find.byKey(loginButtonSsoKey), findsOneWidget);
      expect(find.text(_providerSessionLeft), findsNothing);

      client.logout.complete(const ProviderLogoutFailed());
      await tester.pumpAndSettle();

      expect(find.byKey(loginButtonSsoKey), findsOneWidget);
      expect(find.text(_providerSessionLeft).hitTestable(), findsOneWidget);
    });

    testWidgets('shows no notice when the provider session ends later', (tester) async {
      final client = _FakeOidcClient();
      await _startSignedIn(tester, client);
      await _logOut(tester);

      client.logout.complete(const ProviderSessionEnded());
      await tester.pumpAndSettle();

      expect(find.byKey(loginButtonSsoKey), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
    });

    // The data left on this device is the more serious of the two, and the user is told only that.
    testWidgets('that cannot remove all stored data says only that, also when the provider logout fails later', (
      tester,
    ) async {
      SharedPreferencesStorePlatform.instance = _CacheKeepingStore();
      final client = _FakeOidcClient();
      await _startSignedIn(tester, client);
      await _cacheResponse();

      await _logOut(tester);
      expect(find.byKey(loginButtonSsoKey), findsOneWidget);
      expect(find.text(_storedDataLeft).hitTestable(), findsOneWidget);

      client.logout.complete(const ProviderLogoutFailed());
      await tester.pumpAndSettle();

      expect(find.text(_providerSessionLeft), findsNothing);
    });
  });

  // The stored session may still open the app when its read answers late, so the login page must not send the user to
  // the identity provider meanwhile.
  testWidgets('a stored session read past the restore limit closes the automatic redirect gate', (tester) async {
    final client = _FakeOidcClient();
    final storage = _SlowAccessTokenStorage();
    await tester.pumpWidget(
      App(language: 'en', dependencies: _OidcDependencies(client, autoRedirect: true), secureStorage: storage),
    );
    await tester.pump(SessionCubit.defaultRestoreTimeLimit + const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(
      _app(tester).read<SessionCubit>().state,
      isA<SessionUnauthenticated>().having((s) => s.reason, 'reason', SessionExpiredReason.storageTimeout),
    );
    expect(find.byKey(loginButtonSsoKey), findsOneWidget);
    expect(_app(tester).read<SsoAutoRedirectGate>().isOpen, isFalse);
    expect(client.signIns, 0);

    storage.release.complete();
    await tester.pumpAndSettle();
  });

  // A session that an earlier, correctly configured build stored holds the provider's tokens, and this build
  // provides no automatic redirect gate.
  testWidgets('in a misconfigured build, a session an earlier build left starts signed out with the config error', (
    tester,
  ) async {
    TestEnv.authenticate();
    await tester.pumpWidget(
      const App(
        language: 'en',
        dependencies: AppDependencies(
          appConfig: _appConfig,
          authMode: OidcMisconfiguredAuthMode('OIDC_SCOPE must hold openid'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ResponsiveScaffold), findsNothing);
    expect(
      find.text('Single sign-on is not configured correctly in this app. Contact your administrator.'),
      findsOneWidget,
    );
    expect(() => _app(tester).read<SsoAutoRedirectGate>(), throwsA(isA<ProviderNotFoundException>()));
    expect(tester.takeException(), isNull);
  });
}
