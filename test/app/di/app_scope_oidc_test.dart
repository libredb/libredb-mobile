import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:libredb_mobile/app/di/app_dependencies.dart';
import 'package:libredb_mobile/app/di/app_scope.dart';
import 'package:libredb_mobile/app/localization/locale_cubit.dart';
import 'package:libredb_mobile/app/session/session_cubit.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/features/auth/domain/services/sso_auto_redirect_gate.dart';
import 'package:libredb_mobile/infrastructure/auth/oidc/oidc_client.dart';
import 'package:libredb_mobile/infrastructure/config/auth_config.dart';
import 'package:libredb_mobile/infrastructure/config/environment.dart';
import 'package:libredb_mobile/infrastructure/http/api_client.dart';
import 'package:libredb_mobile/infrastructure/http/interceptors/account_refusal_interceptor.dart';
import 'package:libredb_mobile/infrastructure/http/interceptors/auth_interceptor.dart';
import 'package:libredb_mobile/infrastructure/http/interceptors/token_refresh_interceptor.dart';
import 'package:libredb_mobile/infrastructure/http/token_rotation.dart';
import 'package:libredb_mobile/infrastructure/platform/platform_api_client.dart';
import 'package:libredb_mobile/infrastructure/storage/secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

final _oidcSettings = OidcSettings(issuer: Uri.parse('https://id.example.com/realms/demo'), clientId: 'app');

/// An identity provider these tests never sign in, refresh or log out with.
class _IdleOidcClient implements IOidcClient {
  @override
  Future<OidcSignInOutcome> signIn() => throw UnimplementedError('these tests never tap the sign-in button');

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

/// The test config over [client], recording the rotation its ApiClient is given.
class _OidcDependencies extends AppDependencies {
  _OidcDependencies(this.client) : super(appConfig: const AppConfig.test(), authMode: OidcAuthMode(_oidcSettings));

  final IOidcClient client;
  final apiClientRotations = <TokenRotation>[];
  final platformApiClientRotations = <TokenRotation>[];

  /// The language source the scope gave the provider client, read whenever a test wants to know what the next
  /// sign-in would ask the provider's page for.
  List<String> Function()? uiLocales;

  @override
  PlatformApiClient createPlatformApiClient(
    ISecureStorage secureStorage, {
    required OnSessionExpired onSessionExpired,
    OnSessionRefused? onSessionRefused,
    OnAccountRefused? onAccountRefused,
    OnTokenMissing? onTokenMissing,
    required TokenRotation tokenRotation,
  }) {
    platformApiClientRotations.add(tokenRotation);
    return super.createPlatformApiClient(
      secureStorage,
      onSessionExpired: onSessionExpired,
      onSessionRefused: onSessionRefused,
      onAccountRefused: onAccountRefused,
      onTokenMissing: onTokenMissing,
      tokenRotation: tokenRotation,
    );
  }

  @override
  IOidcClient createOidcClient(OidcSettings settings, {List<String> Function()? uiLocales}) {
    this.uiLocales = uiLocales;
    return client;
  }

  @override
  ApiClient createApiClient(
    ISecureStorage secureStorage, {
    required OnSessionExpired onSessionExpired,
    OnSessionRefused? onSessionRefused,
    OnAccountRefused? onAccountRefused,
    OnTokenMissing? onTokenMissing,
    required TokenRotation tokenRotation,
  }) {
    apiClientRotations.add(tokenRotation);
    return super.createApiClient(
      secureStorage,
      onSessionExpired: onSessionExpired,
      onSessionRefused: onSessionRefused,
      onAccountRefused: onAccountRefused,
      onTokenMissing: onTokenMissing,
      tokenRotation: tokenRotation,
    );
  }
}

/// The test config in a misconfigured build, recording the rotation its ApiClient is given.
class _MisconfiguredDependencies extends AppDependencies {
  _MisconfiguredDependencies()
    : super(
        appConfig: const AppConfig.test(),
        authMode: const OidcMisconfiguredAuthMode('OIDC_SCOPE must hold openid'),
      );

  final apiClientRotations = <TokenRotation>[];
  final platformApiClientRotations = <TokenRotation>[];

  @override
  PlatformApiClient createPlatformApiClient(
    ISecureStorage secureStorage, {
    required OnSessionExpired onSessionExpired,
    OnSessionRefused? onSessionRefused,
    OnAccountRefused? onAccountRefused,
    OnTokenMissing? onTokenMissing,
    required TokenRotation tokenRotation,
  }) {
    platformApiClientRotations.add(tokenRotation);
    return super.createPlatformApiClient(
      secureStorage,
      onSessionExpired: onSessionExpired,
      onSessionRefused: onSessionRefused,
      onAccountRefused: onAccountRefused,
      onTokenMissing: onTokenMissing,
      tokenRotation: tokenRotation,
    );
  }

  @override
  ApiClient createApiClient(
    ISecureStorage secureStorage, {
    required OnSessionExpired onSessionExpired,
    OnSessionRefused? onSessionRefused,
    OnAccountRefused? onAccountRefused,
    OnTokenMissing? onTokenMissing,
    required TokenRotation tokenRotation,
  }) {
    apiClientRotations.add(tokenRotation);
    return super.createApiClient(
      secureStorage,
      onSessionExpired: onSessionExpired,
      onSessionRefused: onSessionRefused,
      onAccountRefused: onAccountRefused,
      onTokenMissing: onTokenMissing,
      tokenRotation: tokenRotation,
    );
  }
}

/// Pumps [AppScope] over [dependencies] and returns a context below it.
Future<BuildContext> _pumpScope(WidgetTester tester, AppDependencies dependencies) async {
  late BuildContext scope;
  await tester.pumpWidget(
    AppScope(
      dependencies: dependencies,
      defaultLocale: const Locale('en'),
      child: Builder(
        builder: (context) {
          scope = context;
          return const SizedBox();
        },
      ),
    ),
  );
  return scope;
}

/// Reads [SessionCubit], which starts its restore, and waits for the first state the restore settles.
Future<SessionState> _restoredSession(WidgetTester tester, BuildContext scope) async {
  final session = scope.read<SessionCubit>();
  if (session.state is! SessionUnknown) return session.state;
  final settled = await tester.runAsync(() => session.stream.firstWhere((state) => state is! SessionUnknown));
  expect(settled, isNotNull, reason: 'the restore never settled the session');
  return settled!;
}

void main() {
  group('AppScope startup', () {
    testWidgets('refreshes an expired stored session through the provider before the router starts', (tester) async {
      for (final (key, value) in [
        (SecureStorageKeys.jwtToken, 'expired-access-token'),
        (SecureStorageKeys.refreshToken, 'stored-refresh-token'),
        (SecureStorageKeys.oidcIdToken, 'stored-id-token'),
        (SecureStorageKeys.accessTokenExpiresAt, encodeAccessTokenExpiry(DateTime.utc(2000))),
      ]) {
        await FlutterSecureStorageAdapter().write(key.key, value);
      }
      final scope = await _pumpScope(tester, _OidcDependencies(_RefreshingClient(DateTime.utc(2100))));

      await _restoredSession(tester, scope);

      expect(await FlutterSecureStorageAdapter().read(SecureStorageKeys.jwtToken.key), 'refreshed-access-token');
    });

    testWidgets('the ApiClient refreshes through the one TokenRotation the scope provides', (tester) async {
      final dependencies = _OidcDependencies(_IdleOidcClient());
      final scope = await _pumpScope(tester, dependencies);

      scope.read<ApiClient>();

      expect(dependencies.apiClientRotations, hasLength(1));
      expect(dependencies.apiClientRotations.single, same(scope.read<TokenRotation>()));
    });

    testWidgets('the provider client asks the provider page for the language the app shows', (tester) async {
      final dependencies = _OidcDependencies(_IdleOidcClient());
      final scope = await _pumpScope(tester, dependencies);

      scope.read<IOidcClient>();

      final uiLocales = dependencies.uiLocales;
      expect(uiLocales, isNotNull, reason: 'the scope gave the provider client no language to ask the page for');
      expect(uiLocales!(), ['en'], reason: 'the app starts in the scope\'s default language');

      await scope.read<LocaleCubit>().changeLocale(const Locale('tr'));
      await tester.pump();

      expect(uiLocales(), [
        'tr',
      ], reason: 'the language the user picked in Settings is what the provider page must open in');
    });

    testWidgets('the Platform client refreshes through the same TokenRotation as the Studio client', (tester) async {
      final dependencies = _OidcDependencies(_IdleOidcClient());
      final scope = await _pumpScope(tester, dependencies);

      scope.read<PlatformApiClient>();

      expect(dependencies.platformApiClientRotations, hasLength(1));
      expect(dependencies.platformApiClientRotations.single, same(scope.read<TokenRotation>()));
    });
  });

  // A session that an earlier, correctly configured build stored holds the provider's tokens.
  group('AppScope in a misconfigured build, with a session an earlier build stored', () {
    setUp(() async {
      final storage = FlutterSecureStorageAdapter();
      await storage.write(SecureStorageKeys.jwtToken.key, 'provider-access-token');
      await storage.write(SecureStorageKeys.refreshToken.key, 'provider-refresh-token');
      await storage.write(SecureStorageKeys.oidcIdToken.key, 'provider-id-token');
    });

    testWidgets('restores signed out with the configuration error, and leaves the stored session alone', (
      tester,
    ) async {
      final scope = await _pumpScope(tester, _MisconfiguredDependencies());

      expect(
        await _restoredSession(tester, scope),
        const SessionUnauthenticated(
          reason: SessionExpiredReason.signInFailed,
          signInError: AppErrorCode.authOidcConfig,
        ),
      );
      expect(await FlutterSecureStorageAdapter().read(SecureStorageKeys.refreshToken.key), 'provider-refresh-token');
    });

    // A misconfigured build cannot reach the identity provider, so it never refreshes the stored session.
    testWidgets('the ApiClient refreshes through a rotation that refuses every refresh', (tester) async {
      final dependencies = _MisconfiguredDependencies();
      final scope = await _pumpScope(tester, dependencies);

      scope.read<ApiClient>();

      expect(dependencies.apiClientRotations, hasLength(1));
      final rotation = dependencies.apiClientRotations.single;
      expect(await rotation.rotate('provider-refresh-token'), isA<RotationRefused>());
    });

    testWidgets('the Platform client refreshes through a rotation that refuses every refresh', (tester) async {
      final dependencies = _MisconfiguredDependencies();
      final scope = await _pumpScope(tester, dependencies);

      scope.read<PlatformApiClient>();

      expect(dependencies.platformApiClientRotations, hasLength(1));
      expect(dependencies.platformApiClientRotations.single, isA<RefusingTokenRotation>());
    });
  });

  testWidgets('a misconfigured build provides no automatic redirect gate', (tester) async {
    final scope = await _pumpScope(tester, _MisconfiguredDependencies());

    expect(() => scope.read<SsoAutoRedirectGate>(), throwsA(isA<ProviderNotFoundException>()));
  });
}

/// Refreshes the stored session at the provider, rotating every token, with a new access token that expires at
/// [expiresAt].
class _RefreshingClient extends _IdleOidcClient {
  _RefreshingClient(this.expiresAt);

  final DateTime expiresAt;

  @override
  Future<TokenRotationResult> refresh({
    required String refreshToken,
    required String idToken,
    required String accessToken,
    required DateTime accessTokenExpiresAt,
  }) async => TokensRotated(
    accessToken: 'refreshed-access-token',
    refreshToken: 'refreshed-refresh-token',
    oidcIdToken: 'refreshed-id-token',
    accessTokenExpiresAt: expiresAt,
  );
}
