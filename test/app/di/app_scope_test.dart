@Tags(['widget'])
library;

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:libredb_mobile/app/di/app_dependencies.dart';
import 'package:libredb_mobile/app/di/app_scope.dart';
import 'package:libredb_mobile/app/di/local_sign_in_dependencies.dart';
import 'package:libredb_mobile/infrastructure/auth/oidc/local_oidc_client.dart';
import 'package:libredb_mobile/app/session/session_cubit.dart';
import 'package:libredb_mobile/app/session/studio_account_refusal_cubit.dart';
import 'package:libredb_mobile/core/errors/app_api_exception.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/auth/application/login_bloc.dart';
import 'package:libredb_mobile/features/auth/application/sign_out_bloc.dart';
import 'package:libredb_mobile/features/auth/application/studio_identity_cubit.dart';
import 'package:libredb_mobile/features/auth/domain/entities/auth_session.dart';
import 'package:libredb_mobile/features/auth/domain/repositories/auth_repository.dart';
import 'package:libredb_mobile/features/auth/domain/repositories/auth_session_repository.dart';
import 'package:libredb_mobile/features/auth/domain/repositories/studio_identity_repository.dart';
import 'package:libredb_mobile/features/lifecycle/data/repositories/lifecycle_repository.dart';
import 'package:libredb_mobile/features/object_browser/data/repositories/cached_object_browser_repository.dart';
import 'package:libredb_mobile/features/object_browser/domain/repositories/object_browser_repository.dart';
import 'package:libredb_mobile/features/lifecycle/domain/entities/app_config_entity.dart';
import 'package:libredb_mobile/infrastructure/auth/oidc/oidc_client.dart';
import 'package:libredb_mobile/infrastructure/auth/oidc/oidc_token_rotation.dart';
import 'package:libredb_mobile/infrastructure/config/auth_config.dart';
import 'package:libredb_mobile/infrastructure/config/environment.dart';
import 'package:libredb_mobile/infrastructure/http/api_client.dart';
import 'package:libredb_mobile/infrastructure/http/interceptors/account_refusal_interceptor.dart';
import 'package:libredb_mobile/infrastructure/http/interceptors/token_refresh_interceptor.dart';
import 'package:libredb_mobile/infrastructure/http/token_rotation.dart';
import 'package:libredb_mobile/infrastructure/storage/secure_storage.dart';
import 'package:libredb_mobile/infrastructure/studio/cached_provider_meta_repository.dart';
import 'package:libredb_mobile/shared/models/provider_meta_repository.dart';
import 'package:libredb_mobile/shared/models/studio_identity.dart';
import 'package:libredb_mobile/shared/utils/schema_change_notifier.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_env.dart';

/// Production behavior (no mock interceptor, token expiry enforced) with a valid base URL, which [AppConfig.prod] has
/// only when the build gives `PROD_API_URL`.
const _prodConfig = AppConfig(
  environment: Environment.prod,
  apiBaseUrl: 'https://api.example.test',
  certificatePins: <String>[],
  idleTimeout: null,
);

/// A JWT whose `exp` lies far in the future, so a production [SessionCubit] restores it as authenticated.
String _unexpiredJwt() => _jwt(exp: 4102444800);

/// A JWT whose `exp` has passed, so a production [SessionCubit] restores it as signed out but leaves it stored.
String _expiredJwt() => _jwt(exp: 946684800);

String _jwt({required int exp, String sub = 'admin'}) {
  String part(Map<String, Object> json) => base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');
  return '${part({'alg': 'HS256', 'typ': 'JWT'})}.${part({'sub': sub, 'exp': exp})}.signature';
}

/// Answers every request with 401, like a server that rejects the stored token.
class _UnauthorizedAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString('{}', 401);

  @override
  void close({bool force = false}) {}
}

/// Answers each request from [_routes] by method and path, and records it with its Authorization header. Like a
/// Spring Security resource server, it answers 401 to a request that carries an expired token before it looks at the
/// endpoint, public ones included.
class _ServerAdapter implements HttpClientAdapter {
  _ServerAdapter(this._routes);

  final Map<String, (int, Object)> _routes;
  final requests = <String>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final route = '${options.method} ${options.path}';
    final authorization = options.headers['Authorization'] as String?;
    requests.add('$route $authorization');
    if (authorization == 'Bearer ${_expiredJwt()}') return ResponseBody.fromString('invalid_token', 401);
    final (statusCode, body) = _routes[route] ?? (throw StateError('No route for $route'));
    return ResponseBody.fromString(
      jsonEncode(body),
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// Counts the clears that reach it.
class _CountingSessionRepository implements IAuthSessionRepository {
  int clears = 0;

  @override
  Future<Result<void>> persist(AuthSession session) async => const Success(null);

  @override
  Future<Result<void>> clear() async {
    clears++;
    return const Success(null);
  }
}

/// The test config with [sessionRepository] in place of the one AppDependencies creates.
class _SessionRepositoryDependencies extends LocalSignInDependencies {
  _SessionRepositoryDependencies(this.sessionRepository) : super(appConfig: const AppConfig.test());

  final IAuthSessionRepository sessionRepository;

  @override
  IAuthSessionRepository createAuthSessionRepository(ISecureStorage secureStorage) => sessionRepository;
}

/// A token refresh at the identity provider that answers [result], a refusal by default, counted in [rotations].
class _FakeRotation implements TokenRotation {
  _FakeRotation([this.result = const RotationRefused()]);

  final TokenRotationResult result;
  int rotations = 0;

  @override
  Future<TokenRotationResult> rotate(String refreshToken) async {
    rotations++;
    return result;
  }
}

/// The production dependencies with [rotation] as the token refresh and [client] as the identity provider, counting
/// how often the client reports a 401 that a token refresh could not fix.
class _CountingDependencies extends AppDependencies {
  _CountingDependencies({TokenRotation? rotation, IOidcClient? client})
    : rotation = rotation ?? _FakeRotation(),
      client = client ?? _FakeOidcClient(const OidcSignInCancelled()),
      super(appConfig: _prodConfig, authMode: OidcAuthMode(_oidcSettings));

  final TokenRotation rotation;
  final IOidcClient client;
  int sessionExpiredCalls = 0;

  @override
  IOidcClient createOidcClient(OidcSettings settings) => client;

  @override
  TokenRotation createOidcTokenRotation(IOidcClient client, ISecureStorage secureStorage) => rotation;

  @override
  ApiClient createApiClient(
    ISecureStorage secureStorage, {
    required OnSessionExpired onSessionExpired,
    OnAccountRefused? onAccountRefused,
    required TokenRotation tokenRotation,
  }) => super.createApiClient(
    secureStorage,
    onSessionExpired: () {
      sessionExpiredCalls++;
      onSessionExpired();
    },
    onAccountRefused: onAccountRefused,
    tokenRotation: tokenRotation,
  );
}

/// Answers like the server while a token refresh races the end of the session: a request with [staleJwt] gets 401,
/// and a request with [freshJwt] gets an answer. Records each request with its Authorization header.
class _RefreshRaceServer implements HttpClientAdapter {
  _RefreshRaceServer({required this.staleJwt, required this.freshJwt});

  final String staleJwt;
  final String freshJwt;
  final requests = <String>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final route = '${options.method} ${options.path}';
    final authorization = switch (options.headers['Authorization']) {
      final String header when header == 'Bearer $staleJwt' => 'Bearer stale',
      final String header when header == 'Bearer $freshJwt' => 'Bearer fresh',
      final other => '$other',
    };
    requests.add('$route $authorization');
    final ok = authorization == 'Bearer fresh' || route == 'POST /auth/logout';
    return ResponseBody.fromString(
      jsonEncode(ok ? {'connections': <Object>[], 'success': true} : {'code': 'AUTH_REQUIRED'}),
      ok ? 200 : 401,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// The identity provider's token refresh while it races the end of the session: it waits for [releaseRefresh] and then
/// rotates the tokens to [freshJwt].
class _GatedRotation implements TokenRotation {
  _GatedRotation(this.freshJwt);

  final String freshJwt;
  final refreshReceived = Completer<void>();
  final releaseRefresh = Completer<void>();

  @override
  Future<TokenRotationResult> rotate(String refreshToken) async {
    refreshReceived.complete();
    await releaseRefresh.future;
    return TokensRotated(accessToken: freshJwt, refreshToken: 'rotated-refresh-token');
  }
}

/// Answers like the server while a request of one user is on its way and that user signs out and another signs in:
/// the statement sent with [signedOutJwt] waits for [releaseSave] and is then rejected with 401, and every request with
/// [signedInJwt] succeeds. Records each request with its Authorization header.
class _SignInRaceServer implements HttpClientAdapter {
  _SignInRaceServer({required this.signedOutJwt, required this.signedInJwt});

  final String signedOutJwt;
  final String signedInJwt;
  final requests = <String>[];
  final saveReceived = Completer<void>();
  final releaseSave = Completer<void>();

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final route = '${options.method} ${options.path}';
    final authorization = switch (options.headers['Authorization']) {
      final String header when header == 'Bearer $signedOutJwt' => 'Bearer signed-out-user',
      final String header when header == 'Bearer $signedInJwt' => 'Bearer signed-in-user',
      final other => '$other',
    };
    requests.add('$route $authorization');
    ResponseBody json(int statusCode, Object body) => ResponseBody.fromString(
      jsonEncode(body),
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
    switch ((route, authorization)) {
      case ('POST /auth/logout', 'Bearer signed-out-user'):
        return json(200, {'success': true});
      case ('POST /db/query', 'Bearer signed-out-user'):
        saveReceived.complete();
        await releaseSave.future;
        return json(401, {'code': 'AUTH_REQUIRED'});
      case ('GET /auth/me', 'Bearer signed-in-user'):
        return json(200, _studioIdentity);
      case (_, 'Bearer signed-in-user'):
        return json(200, {'ok': true});
    }
    return json(401, {'code': 'AUTH_REQUIRED'});
  }

  @override
  void close({bool force = false}) {}
}

/// Studio's `GET /api/auth/me` answer for a signed-in user.
const _studioIdentity = {
  'authenticated': true,
  'user': {'role': 'user', 'username': 'user@example.com', 'channel': 'bearer'},
};

/// Pumps until [done] holds, so a test can run a request, a token refresh and the end of the session in a fixed order.
Future<void> _pumpUntil(WidgetTester tester, bool Function() done) async {
  for (var i = 0; i < 50 && !done(); i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(done(), isTrue);
}

final _oidcSettings = OidcSettings(issuer: Uri.parse('https://id.example.com/realms/demo'), clientId: 'app');

/// Signs in with [outcome], as a provider would after the user signed in on its page.
class _FakeOidcClient implements IOidcClient {
  _FakeOidcClient(this.outcome, {this.logout});

  final OidcSignInOutcome outcome;

  /// How a provider logout ends, or null for a test that never logs out.
  final OidcLogoutOutcome? logout;

  @override
  Future<OidcSignInOutcome> signIn() async => outcome;

  @override
  Future<TokenRotationResult> refresh({
    required String refreshToken,
    required String idToken,
    required String accessToken,
    required DateTime accessTokenExpiresAt,
  }) => throw UnimplementedError('these tests never refresh');

  @override
  Future<OidcLogoutOutcome> endProviderSession({String? idTokenHint}) async =>
      logout ?? (throw UnimplementedError('this test never logs out'));
}

/// The test config in [authMode], counting the OIDC clients it creates; each one is [client].
class _OidcClientDependencies extends AppDependencies {
  _OidcClientDependencies({required super.authMode, required this.client}) : super(appConfig: const AppConfig.test());

  final IOidcClient client;
  int oidcClientsCreated = 0;

  @override
  IOidcClient createOidcClient(OidcSettings settings) {
    oidcClientsCreated++;
    return client;
  }
}

/// Counts the sign-outs recorded at Studio, noting each one in [events] with the bearer stored when it was sent.
class _CountingStudioIdentity implements IStudioIdentityRepository {
  _CountingStudioIdentity(this.events);

  final List<String> events;
  int signOutsRecorded = 0;

  @override
  Future<Result<void>> recordSignOut() async {
    signOutsRecorded++;
    events.add('recordSignOut ${await FlutterSecureStorageAdapter().read(SecureStorageKeys.jwtToken.key)}');
    return const Success(null);
  }

  @override
  Future<Result<StudioIdentity>> fetch() => throw UnimplementedError('these tests never read the identity');
}

/// A provider without a logout endpoint, so a logout ends no provider session.
class _NoLogoutOidcClient extends _FakeOidcClient {
  _NoLogoutOidcClient() : super(const OidcSignInCancelled());

  @override
  Future<OidcLogoutOutcome> endProviderSession({String? idTokenHint}) async => const NoProviderLogout();
}

/// Rotates every refresh token into the access token `refreshed-access-token`, noting each rotation in [events].
class _RecordingTokenRotation implements TokenRotation {
  _RecordingTokenRotation(this.events);

  final List<String> events;

  @override
  Future<TokenRotationResult> rotate(String refreshToken) async {
    events.add('rotate $refreshToken');
    return TokensRotated(accessToken: 'refreshed-access-token', accessTokenExpiresAt: DateTime.utc(2100));
  }
}

/// The test config in [authMode], whose Studio identity repository is [studioIdentity] and whose oidc token rotation
/// notes each rotation in [events].
class _StudioIdentityDependencies extends AppDependencies {
  _StudioIdentityDependencies({required super.authMode}) : super(appConfig: const AppConfig.test());

  final events = <String>[];
  late final studioIdentity = _CountingStudioIdentity(events);

  @override
  IOidcClient createOidcClient(OidcSettings settings) => _NoLogoutOidcClient();

  @override
  TokenRotation createOidcTokenRotation(IOidcClient client, ISecureStorage secureStorage) =>
      _RecordingTokenRotation(events);

  @override
  IStudioIdentityRepository createStudioIdentityRepository(ApiClient apiClient) => studioIdentity;
}

/// Pumps [AppScope] over [dependencies], restores the stored session as a launch does, and returns a context below it.
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
  // SessionCubit is created, and restores the stored session, on its first read, as App reads it on launch.
  scope.read<SessionCubit>();
  await tester.pumpAndSettle();
  return scope;
}

void main() {
  group('AppScope', () {
    testWidgets('ends the session and clears the stored session when a 401 cannot be refreshed', (tester) async {
      // A production config sends requests to the adapter instead of the mock assets. The identity provider refuses
      // the refresh, so the stored refresh token cannot renew the session.
      await FlutterSecureStorageAdapter().write(SecureStorageKeys.jwtToken.key, _unexpiredJwt());
      await FlutterSecureStorageAdapter().write(SecureStorageKeys.refreshToken.key, 'rejected-refresh-token');
      final rotation = _FakeRotation();
      final dependencies = _CountingDependencies(rotation: rotation);
      final scope = await _pumpScope(tester, dependencies);
      final session = scope.read<SessionCubit>();
      expect(session.state, isA<SessionAuthenticated>());

      final apiClient = scope.read<ApiClient>();
      apiClient.instance.httpClientAdapter = _UnauthorizedAdapter();
      // Dio runs each interceptor step on a timer, so the request, the refresh and the wipe of the stored session run
      // while fake time moves, and all of them have finished when the pump returns.
      final request = expectLater(apiClient.get('/connections/managed'), throwsA(isA<UnauthorizedException>()));
      await tester.pump(Duration.zero);
      await request;

      expect(session.state, const SessionUnauthenticated(reason: SessionExpiredReason.expired));
      expect(rotation.rotations, 1);
      // A relaunch restores the session from secure storage, as AppScope does on launch.
      final relaunched = SessionCubit(secureStorage: FlutterSecureStorageAdapter(), appConfig: _prodConfig);
      addTearDown(relaunched.close);
      await relaunched.restore();
      expect(relaunched.state, const SessionUnauthenticated(reason: SessionExpiredReason.noToken));
      expect(await FlutterSecureStorageAdapter().read(SecureStorageKeys.refreshToken.key), isNull);
    });

    testWidgets('ends the session in mock mode when a request without a token gets 401', (tester) async {
      // The mock answers a protected request without a token with 401, as the server does. That happens when the
      // stored token is gone while the session is open. No refresh token is stored, so the refresh fails.
      TestEnv.authenticate();
      final scope = await _pumpScope(tester, LocalSignInDependencies(appConfig: const AppConfig.test()));
      final session = scope.read<SessionCubit>();
      expect(session.state, isA<SessionAuthenticated>());

      await FlutterSecureStorageAdapter().delete(SecureStorageKeys.jwtToken.key);
      final apiClient = scope.read<ApiClient>();
      // Dio runs each interceptor step on a timer, so the request moves only while fake time does.
      final request = expectLater(apiClient.get('/connections/managed'), throwsA(isA<UnauthorizedException>()));
      await tester.pump(Duration.zero);
      await request;

      expect(session.state, const SessionUnauthenticated(reason: SessionExpiredReason.expired));
    });

    testWidgets('keeps the session in mock mode when a 401 can be fixed by a token refresh', (tester) async {
      // The mock answers a request whose JWT bearer has expired with 401, which starts a token refresh, as it does in
      // production. The local sign-in answers the refresh as the identity provider would, the request is sent again
      // with the new token, and the user stays signed in.
      final secure = FlutterSecureStorageAdapter();
      await secure.write(SecureStorageKeys.jwtToken.key, _expiredJwt());
      await secure.write(SecureStorageKeys.refreshToken.key, 'LOCAL_REFRESH_TOKEN');
      await secure.write(SecureStorageKeys.oidcIdToken.key, 'LOCAL_ID_TOKEN');
      await secure.write(SecureStorageKeys.accessTokenExpiresAt.key, encodeAccessTokenExpiry(DateTime.utc(2100)));
      final scope = await _pumpScope(tester, LocalSignInDependencies(appConfig: const AppConfig.test()));
      final session = scope.read<SessionCubit>();
      expect(session.state, isA<SessionAuthenticated>());

      final apiClient = scope.read<ApiClient>();
      // Dio runs each interceptor step on a timer, so the request and the refresh move only while fake time does.
      final request = apiClient.get('/connections/managed');
      await tester.pump(Duration.zero);
      final response = await request;

      expect(response.statusCode, 200);
      expect(session.state, isA<SessionAuthenticated>());
      expect(await secure.read(SecureStorageKeys.jwtToken.key), LocalOidcClient.accessToken);
    });

    testWidgets('provides the auth mode that AppDependencies carries', (tester) async {
      const authMode = OidcMisconfiguredAuthMode('OIDC_ISSUER is required');
      final scope = await _pumpScope(tester, const AppDependencies(authMode: authMode));

      expect(scope.read<AuthMode>(), same(authMode));
    });

    // The logout, the idle timeout and an unrefreshable 401 must clear the same things, so they share one repository.
    testWidgets('logs out through the session repository that AppDependencies creates', (tester) async {
      final sessionRepository = _CountingSessionRepository();
      final scope = await _pumpScope(tester, _SessionRepositoryDependencies(sessionRepository));

      // The logout records the sign-out at Studio first, under a time budget that moves only while fake time does.
      Result<void>? result;
      scope.read<IAuthRepository>().logout().then((value) => result = value);
      await _pumpUntil(tester, () => result != null);

      expect(result, isA<Success<void>>());

      expect(sessionRepository.clears, 1);
    });

    // The lifecycle checks read GET /app/config before sign-in. Were it not public, it would carry the stored token,
    // which the server may reject, and spend the stored refresh token on a refresh.
    testWidgets('reading the app config sends no stored token and refreshes none', (tester) async {
      await FlutterSecureStorageAdapter().write(SecureStorageKeys.jwtToken.key, _expiredJwt());
      await FlutterSecureStorageAdapter().write(SecureStorageKeys.refreshToken.key, 'stored-refresh-token');
      final rotation = _FakeRotation();
      final dependencies = _CountingDependencies(rotation: rotation);
      final scope = await _pumpScope(tester, dependencies);
      final server = _ServerAdapter({
        'GET /app/config': (200, {'minimumVersion': '1.0.0', 'maintenanceMode': false}),
      });
      final apiClient = scope.read<ApiClient>();
      apiClient.instance.httpClientAdapter = server;

      Result<AppConfigEntity>? result;
      LifecycleRepository(apiClient).fetchAppConfig().then((value) => result = value);
      await _pumpUntil(tester, () => result != null);

      expect(result, isA<Success<AppConfigEntity>>());
      expect(server.requests, ['GET /app/config null'], reason: 'no stored token is sent, and none is refreshed');
      expect(rotation.rotations, 0);
      expect(dependencies.sessionExpiredCalls, 0);
      expect(await FlutterSecureStorageAdapter().read(SecureStorageKeys.refreshToken.key), 'stored-refresh-token');
    });

    // Regression: a token refresh still on its way when the session ended stored the rotated tokens after the wipe.
    // The request it sent again then succeeded, so nothing ended the session a second time, and a relaunch signed the
    // user back in.
    for (final (name, endSession) in <(String, Future<void> Function(BuildContext scope))>[
      (
        'the user logs out',
        (scope) async {
          final signOut = scope.read<SignOutBloc>();
          signOut.add(const SignOutRequested());
          await signOut.stream.firstWhere((state) => state is SignOutDone);
        },
      ),
      (
        'the idle timeout fires',
        (scope) => scope.read<SessionCubit>().endSession(reason: SessionExpiredReason.idleTimeout),
      ),
    ]) {
      testWidgets('leaves no session for a relaunch to restore when $name during a token refresh', (tester) async {
        final staleJwt = _unexpiredJwt();
        final freshJwt = _jwt(exp: 4102444801);
        await FlutterSecureStorageAdapter().write(SecureStorageKeys.jwtToken.key, staleJwt);
        await FlutterSecureStorageAdapter().write(SecureStorageKeys.refreshToken.key, 'stored-refresh-token');
        final rotation = _GatedRotation(freshJwt);
        final dependencies = _CountingDependencies(
          rotation: rotation,
          client: _FakeOidcClient(const OidcSignInCancelled(), logout: const NoProviderLogout()),
        );
        final scope = await _pumpScope(tester, dependencies);
        final session = scope.read<SessionCubit>();
        expect(session.state, isA<SessionAuthenticated>());
        final server = _RefreshRaceServer(staleJwt: staleJwt, freshJwt: freshJwt);
        final apiClient = scope.read<ApiClient>();
        apiClient.instance.httpClientAdapter = server;

        // The stored token is rejected, so the request starts a refresh, and the session ends before the identity
        // provider answers the refresh.
        Object? outcome;
        apiClient
            .get('/connections/managed')
            .then<void>((response) => outcome = response, onError: (Object error) => outcome = error);
        await _pumpUntil(tester, () => rotation.refreshReceived.isCompleted);
        var ended = false;
        endSession(scope).then((_) => ended = true);
        await _pumpUntil(tester, () => ended);
        rotation.releaseRefresh.complete();
        await _pumpUntil(tester, () => outcome != null);

        expect(outcome, isA<UnauthorizedException>());
        expect(server.requests, [
          'GET /connections/managed Bearer stale',
          // A logout the user starts records the sign-out at Studio before it clears the session.
          if (name == 'the user logs out') 'POST /auth/logout Bearer stale',
        ]);
        expect(dependencies.sessionExpiredCalls, 0);
        expect(await FlutterSecureStorageAdapter().read(SecureStorageKeys.jwtToken.key), isNull);
        expect(await FlutterSecureStorageAdapter().read(SecureStorageKeys.refreshToken.key), isNull);
        // A relaunch restores the session from secure storage, as AppScope does on launch.
        final relaunched = SessionCubit(secureStorage: FlutterSecureStorageAdapter(), appConfig: _prodConfig);
        addTearDown(relaunched.close);
        await relaunched.restore();
        expect(relaunched.state, const SessionUnauthenticated(reason: SessionExpiredReason.noToken));
      });
    }

    // Regression: a request still on its way when the user signed out got its 401 after another user had signed in,
    // and it was sent again with the token of that user, so the change the first user saved was made as the second.
    testWidgets('does not send a request of the user who signed out again as the user who signed in since', (
      tester,
    ) async {
      final signedOutJwt = _jwt(exp: 4102444800, sub: 'user-one');
      final signedInJwt = _jwt(exp: 4102444800, sub: 'user-two');
      await FlutterSecureStorageAdapter().write(SecureStorageKeys.jwtToken.key, signedOutJwt);
      await FlutterSecureStorageAdapter().write(SecureStorageKeys.refreshToken.key, 'signed-out-refresh-token');
      final rotation = _FakeRotation(TokensRotated(accessToken: signedInJwt));
      final dependencies = _CountingDependencies(
        rotation: rotation,
        client: _FakeOidcClient(
          OidcSignedIn(
            tokens: OidcTokens(
              accessToken: signedInJwt,
              idToken: 'signed-in-id-token',
              refreshToken: 'signed-in-refresh-token',
              accessTokenExpiresAt: DateTime.utc(2100),
            ),
            claims: const {'iss': 'https://id.example.com/realms/demo', 'sub': 'user-two'},
          ),
          logout: const NoProviderLogout(),
        ),
      );
      final scope = await _pumpScope(tester, dependencies);
      final session = scope.read<SessionCubit>();
      expect(session.state, isA<SessionAuthenticated>());
      final server = _SignInRaceServer(signedOutJwt: signedOutJwt, signedInJwt: signedInJwt);
      final apiClient = scope.read<ApiClient>();
      apiClient.instance.httpClientAdapter = server;

      // The first user runs a statement. Before the server answers, that user signs out and another signs in.
      Object? outcome;
      apiClient
          .post('/db/query', {'connectionId': 'seed:sales-db', 'sql': 'update t set x = 1'})
          .then<void>((response) => outcome = response, onError: (Object error) => outcome = error);
      await _pumpUntil(tester, () => server.saveReceived.isCompleted);
      final signOut = scope.read<SignOutBloc>();
      signOut.add(const SignOutRequested());
      await _pumpUntil(tester, () => signOut.state is SignOutDone);
      final login = scope.read<LoginBloc>();
      login.add(const SsoSignInRequested());
      await _pumpUntil(tester, () => login.state is LoginLoadedState);
      // The token of the first user expired on the way, so the server rejects the statement.
      server.releaseSave.complete();
      await _pumpUntil(tester, () => outcome != null);

      expect(outcome, isA<UnauthorizedException>());
      expect(server.requests, [
        'POST /db/query Bearer signed-out-user',
        'POST /auth/logout Bearer signed-out-user',
        'GET /auth/me Bearer signed-in-user',
      ]);
      expect(rotation.rotations, 0, reason: 'the session the request was sent under has ended, so none is refreshed');
      expect(dependencies.sessionExpiredCalls, 0, reason: 'ending the session would sign out the user signed in now');
      expect(await FlutterSecureStorageAdapter().read(SecureStorageKeys.jwtToken.key), signedInJwt);
    });
  });

  // Signed in, the shell asks GET /api/auth/me who the user is. Its failure shows with a retry and never ends the
  // session: only the ApiClient does, for a 401 AUTH_REQUIRED that survives the token refresh.
  group('AppScope StudioIdentityCubit, signed in', () {
    for (final (shape, status, body, code, refreshes) in <(String, int, Object, AppErrorCode, int)>[
      ('a 401 without a code, twice (Studio main)', 401, {'authenticated': false}, AppErrorCode.generic, 1),
      (
        'a 503 IDENTITY_PROVIDER_UNAVAILABLE (libredb-studio#1922)',
        503,
        {'error': 'The identity provider is unavailable.', 'code': 'IDENTITY_PROVIDER_UNAVAILABLE'},
        AppErrorCode.studioIdentityProviderUnavailable,
        0,
      ),
      (
        'a 403 BEARER_NO_ROLE (libredb-studio#1922)',
        403,
        {'error': 'This account has no role in Studio.', 'code': 'BEARER_NO_ROLE'},
        AppErrorCode.studioAccountHasNoRole,
        0,
      ),
      (
        'a 403 BEARER_NO_IDENTITY (libredb-studio#1922)',
        403,
        {'error': 'This account has no identity in Studio.', 'code': 'BEARER_NO_IDENTITY'},
        AppErrorCode.studioAccountHasNoIdentity,
        0,
      ),
    ]) {
      testWidgets('keeps $shape as a failure with ${code.key} and the user signed in', (tester) async {
        await FlutterSecureStorageAdapter().write(SecureStorageKeys.jwtToken.key, _unexpiredJwt());
        await FlutterSecureStorageAdapter().write(SecureStorageKeys.refreshToken.key, 'stored-refresh-token');
        final rotation = _FakeRotation(TokensRotated(accessToken: _unexpiredJwt()));
        final dependencies = _CountingDependencies(rotation: rotation);
        final scope = await _pumpScope(tester, dependencies);
        final session = scope.read<SessionCubit>();
        expect(session.state, isA<SessionAuthenticated>());
        final server = _ServerAdapter({'GET /auth/me': (status, body)});
        scope.read<ApiClient>().instance.httpClientAdapter = server;

        final identity = scope.read<StudioIdentityCubit>();
        unawaited(identity.load());
        await _pumpUntil(tester, () => identity.state is StudioIdentityFailure);

        expect(identity.state, StudioIdentityFailure(code));
        expect(server.requests.map((request) => request.split(' ').take(2).join(' ')), [
          for (var i = 0; i <= refreshes; i++) 'GET /auth/me',
        ]);
        expect(rotation.rotations, refreshes, reason: 'only a 401 starts a refresh');
        expect(dependencies.sessionExpiredCalls, 0);
        expect(session.state, isA<SessionAuthenticated>());
        expect(await FlutterSecureStorageAdapter().read(SecureStorageKeys.jwtToken.key), isNotNull);
      });
    }
  });

  // From libredb-studio#1922 on, Studio refuses a signed-in account it no longer accepts, such as one whose role an
  // administrator removed, on every route once the access token is next refreshed. Whichever request meets the refusal
  // first tells the shell, which shows the refusal page; nothing refreshes and the session stays.
  group('AppScope account refusal, signed in', () {
    for (final (code, expected) in [
      ('BEARER_NO_ROLE', AppErrorCode.studioAccountHasNoRole),
      ('BEARER_NO_IDENTITY', AppErrorCode.studioAccountHasNoIdentity),
    ]) {
      for (final route in ['GET /auth/me', 'GET /connections/managed']) {
        testWidgets('a 403 $code on $route refuses the account and keeps the session', (tester) async {
          await FlutterSecureStorageAdapter().write(SecureStorageKeys.jwtToken.key, _unexpiredJwt());
          await FlutterSecureStorageAdapter().write(SecureStorageKeys.refreshToken.key, 'stored-refresh-token');
          final rotation = _FakeRotation(TokensRotated(accessToken: _unexpiredJwt()));
          final dependencies = _CountingDependencies(rotation: rotation);
          final scope = await _pumpScope(tester, dependencies);
          final session = scope.read<SessionCubit>();
          expect(session.state, isA<SessionAuthenticated>());
          final server = _ServerAdapter({
            route: (403, {'error': 'refused', 'code': code}),
          });
          final apiClient = scope.read<ApiClient>();
          apiClient.instance.httpClientAdapter = server;

          Object? outcome;
          apiClient
              .get(route.split(' ').last)
              .then<void>((response) => outcome = response, onError: (Object error) => outcome = error);
          await _pumpUntil(tester, () => outcome != null);

          expect(outcome, isA<AppException>());

          expect(scope.read<StudioAccountRefusalCubit>().state, StudioAccountRefused(expected));
          expect(server.requests, hasLength(1), reason: 'sent once, never again');
          expect(rotation.rotations, 0);
          expect(dependencies.sessionExpiredCalls, 0);
          expect(session.state, isA<SessionAuthenticated>());
          expect(await FlutterSecureStorageAdapter().read(SecureStorageKeys.jwtToken.key), isNotNull);
        });
      }
    }

    testWidgets('a 503 IDENTITY_PROVIDER_UNAVAILABLE refuses nothing', (tester) async {
      await FlutterSecureStorageAdapter().write(SecureStorageKeys.jwtToken.key, _unexpiredJwt());
      await FlutterSecureStorageAdapter().write(SecureStorageKeys.refreshToken.key, 'stored-refresh-token');
      final scope = await _pumpScope(tester, _CountingDependencies());
      final apiClient = scope.read<ApiClient>();
      apiClient.instance.httpClientAdapter = _ServerAdapter({
        'GET /connections/managed': (503, {'error': 'unreachable', 'code': 'IDENTITY_PROVIDER_UNAVAILABLE'}),
      });

      Object? outcome;
      apiClient
          .get('/connections/managed')
          .then<void>((response) => outcome = response, onError: (Object error) => outcome = error);
      await _pumpUntil(tester, () => outcome != null);

      expect(outcome, isA<AppException>());

      expect(scope.read<StudioAccountRefusalCubit>().state, const StudioAccountAccepted());
      expect(scope.read<SessionCubit>().state, isA<SessionAuthenticated>());
    });
  });

  // Studio decides at sign-in whether it accepts the account, through GET /api/auth/me. Studio main answers a refused
  // account with 401 and no code; libredb-studio#1922 answers 403 BEARER_NO_ROLE, and 401 AUTH_REQUIRED for a token it
  // refuses itself.
  group('AppScope sign-in that Studio refuses', () {
    final signedIn = OidcSignedIn(
      tokens: OidcTokens(
        accessToken: 'signed-in-access-token',
        idToken: 'signed-in-id-token',
        refreshToken: 'signed-in-refresh-token',
        accessTokenExpiresAt: DateTime.utc(2100),
      ),
      claims: const {'iss': 'https://id.example.com/realms/demo', 'sub': 'norole'},
    );

    for (final (shape, status, body, code, refreshes) in <(String, int, Object, AppErrorCode, int)>[
      (
        'a 401 without a code, twice (Studio main)',
        401,
        {'authenticated': false},
        AppErrorCode.studioAccountRefused,
        1,
      ),
      (
        'a 401 AUTH_REQUIRED, twice',
        401,
        {'error': 'Invalid access token', 'code': 'AUTH_REQUIRED'},
        AppErrorCode.studioAccountRefused,
        1,
      ),
      (
        'a 403 BEARER_NO_ROLE (libredb-studio#1922)',
        403,
        {'error': 'This account has no role in Studio.', 'code': 'BEARER_NO_ROLE'},
        AppErrorCode.studioAccountHasNoRole,
        0,
      ),
    ]) {
      testWidgets('rejects $shape with ${code.key}, stores nothing and ends no session', (tester) async {
        final rotation = _FakeRotation(const TokensRotated(accessToken: 'refreshed-access-token'));
        final dependencies = _CountingDependencies(rotation: rotation, client: _FakeOidcClient(signedIn));
        final scope = await _pumpScope(tester, dependencies);
        final session = scope.read<SessionCubit>();
        final sessionStates = <SessionState>[];
        final subscription = session.stream.listen(sessionStates.add);
        addTearDown(subscription.cancel);
        final server = _ServerAdapter({'GET /auth/me': (status, body)});
        scope.read<ApiClient>().instance.httpClientAdapter = server;

        final login = scope.read<LoginBloc>();
        login.add(const SsoSignInRequested());
        await _pumpUntil(tester, () => login.state is LoginErrorState);

        expect(login.state, LoginErrorState(errorCode: code));
        expect(server.requests.map((request) => request.split(' ').take(2).join(' ')), [
          for (var i = 0; i <= refreshes; i++) 'GET /auth/me',
        ]);
        expect(rotation.rotations, refreshes, reason: 'only a 401 starts a refresh');
        final secure = FlutterSecureStorageAdapter();
        for (final key in SecureStorageKeys.values) {
          expect(await secure.read(key.key), isNull, reason: '${key.name} stays stored');
        }
        expect(sessionStates, isEmpty, reason: 'a refused sign-in signs nobody in and ends no session');
        expect(session.state, isA<SessionUnauthenticated>());
        expect(
          scope.read<StudioAccountRefusalCubit>().state,
          const StudioAccountAccepted(),
          reason: 'the login page tells a refused sign-in, so no refusal waits for the next user to sign in',
        );
      });
    }
  });

  group('AppScope single sign-on', () {
    testWidgets('signs in through the OIDC client and stores the whole session', (tester) async {
      final expiresAt = DateTime.utc(2100);
      final dependencies = _OidcClientDependencies(
        authMode: OidcAuthMode(_oidcSettings),
        client: _FakeOidcClient(
          OidcSignedIn(
            tokens: OidcTokens(
              accessToken: 'sso-access-token',
              idToken: 'sso-id-token',
              refreshToken: 'sso-refresh-token',
              accessTokenExpiresAt: expiresAt,
            ),
            claims: const {
              'iss': 'https://id.example.com/realms/demo',
              'sub': 'subject-1',
              'email': 'jdoe@example.com',
            },
          ),
        ),
      );
      final scope = await _pumpScope(tester, dependencies);

      final login = scope.read<LoginBloc>();
      login.add(const SsoSignInRequested());
      await _pumpUntil(tester, () => login.state is LoginLoadedState);

      expect(login.state, const LoginLoadedState());
      expect(dependencies.oidcClientsCreated, 1);
      final secure = FlutterSecureStorageAdapter();
      expect(await secure.read(SecureStorageKeys.jwtToken.key), 'sso-access-token');
      expect(await secure.read(SecureStorageKeys.refreshToken.key), 'sso-refresh-token');
      expect(await secure.read(SecureStorageKeys.oidcIdToken.key), 'sso-id-token');
      expect(readAccessTokenExpiry(await secure.read(SecureStorageKeys.accessTokenExpiresAt.key)), expiresAt);
      expect(scope.read<TokenRotation>(), isA<OidcTokenRotation>());
    });

    testWidgets('a misconfigured build creates no OIDC client', (tester) async {
      final dependencies = _OidcClientDependencies(
        authMode: const OidcMisconfiguredAuthMode('OIDC_ISSUER is required'),
        client: _FakeOidcClient(const OidcSignInCancelled()),
      );
      final scope = await _pumpScope(tester, dependencies);

      // LoginBloc is created on first read, which is when a configured build reads the OIDC client.
      expect(scope.read<LoginBloc>().state, const LoginInitialState());

      expect(dependencies.oidcClientsCreated, 0);
      expect(() => scope.read<IOidcClient>(), throwsA(isA<ProviderNotFoundException>()));
    });

    testWidgets('provides the provider meta repository that several features read', (tester) async {
      final scope = await _pumpScope(tester, LocalSignInDependencies(appConfig: const AppConfig.test()));

      expect(scope.read<IProviderMetaRepository>(), isA<IProviderMetaRepository>());
    });

    testWidgets('features get the one cached object browser and provider-meta that the app clears', (tester) async {
      final scope = await _pumpScope(tester, LocalSignInDependencies(appConfig: const AppConfig.test()));

      expect(scope.read<IObjectBrowserRepository>(), same(scope.read<CachedObjectBrowserRepository>()));
      expect(scope.read<IProviderMetaRepository>(), same(scope.read<CachedProviderMetaRepository>()));
    });

    testWidgets('a statement that changes the schema drops the provided browser cache of its connection', (
      tester,
    ) async {
      TestEnv.authenticate();
      final scope = await _pumpScope(tester, LocalSignInDependencies(appConfig: const AppConfig.test()));
      final browser = scope.read<CachedObjectBrowserRepository>();
      await tester.runAsync(() => browser.containers('seed:sales-db'));
      expect(browser.entryCount, 1);

      final result = await tester.runAsync(
        () => scope.read<SchemaChangeNotifier>().statementSucceeded('seed:sales-db', 'drop table orders'),
      );

      expect(result, const Success(true));
      expect(browser.entryCount, 0);
    });

    testWidgets('records the sign-out at Studio', (tester) async {
      final dependencies = _StudioIdentityDependencies(authMode: OidcAuthMode(_oidcSettings));
      final scope = await _pumpScope(tester, dependencies);

      expect(await scope.read<IAuthRepository>().logout(), isA<Success<void>>());

      expect(dependencies.studioIdentity.signOutsRecorded, 1);
    });

    testWidgets('refreshes an expired access token before it records the sign-out at Studio', (tester) async {
      final dependencies = _StudioIdentityDependencies(authMode: OidcAuthMode(_oidcSettings));
      final scope = await _pumpScope(tester, dependencies);
      final session = scope.read<SessionCubit>();
      await _pumpUntil(tester, () => session.state is! SessionUnknown);
      // Stored after startup, as a token that expired while the app was open.
      final secure = FlutterSecureStorageAdapter();
      await secure.write(SecureStorageKeys.jwtToken.key, 'expired-access-token');
      await secure.write(SecureStorageKeys.refreshToken.key, 'stored-refresh-token');
      await secure.write(SecureStorageKeys.accessTokenExpiresAt.key, encodeAccessTokenExpiry(DateTime.utc(2020)));

      expect(await scope.read<IAuthRepository>().logout(), isA<Success<void>>());

      expect(dependencies.events, ['rotate stored-refresh-token', 'recordSignOut refreshed-access-token']);
      expect(await secure.read(SecureStorageKeys.jwtToken.key), isNull);
    });

    testWidgets('a misconfigured build never records the sign-out at Studio', (tester) async {
      final dependencies = _StudioIdentityDependencies(
        authMode: const OidcMisconfiguredAuthMode('OIDC_ISSUER is required'),
      );
      final scope = await _pumpScope(tester, dependencies);

      expect(await scope.read<IAuthRepository>().logout(), isA<Success<void>>());

      expect(dependencies.studioIdentity.signOutsRecorded, 0);
    });
  });
}
