import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:libredb_mobile/app/di/app_dependencies.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/features/auth/domain/entities/auth_session.dart';
import 'package:libredb_mobile/features/auth/domain/repositories/auth_repository.dart';
import 'package:libredb_mobile/features/object_browser/data/repositories/cached_object_browser_repository.dart';
import 'package:libredb_mobile/features/lifecycle/domain/repositories/lifecycle_repository.dart';
import 'package:libredb_mobile/infrastructure/config/auth_config.dart';
import 'package:libredb_mobile/infrastructure/config/environment.dart';
import 'package:libredb_mobile/infrastructure/http/api_client.dart';
import 'package:libredb_mobile/infrastructure/http/token_rotation.dart';
import 'package:libredb_mobile/infrastructure/storage/secure_storage.dart';
import 'package:libredb_mobile/infrastructure/studio/cached_provider_meta_repository.dart';
import 'package:libredb_mobile/infrastructure/studio/studio_session_policy.dart';
import 'package:libredb_mobile/infrastructure/studio/studio_timeouts.dart';
import 'package:libredb_mobile/shared/models/provider_meta_repository.dart';
import 'package:libredb_mobile/shared/models/statement_repository.dart';
import 'package:libredb_mobile/features/sql_editor/domain/repositories/sql_editor_repository.dart';
import 'package:libredb_mobile/features/sql_editor/domain/repositories/statement_text_store.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_env.dart';

class _StubSecureStorage implements ISecureStorage {
  @override
  Future<String?> read(String key) async => null;
  @override
  Future<void> write(String key, String value) async {}
  @override
  Future<void> delete(String key) async {}
  @override
  Future<void> deleteAll() async {}

  @override
  Future<Set<String>> keys() => throw UnimplementedError('not used by this test');
}

class _MemorySecureStorage implements ISecureStorage {
  final store = <String, String>{};
  @override
  Future<String?> read(String key) async => store[key];
  @override
  Future<void> write(String key, String value) async => store[key] = value;
  @override
  Future<void> delete(String key) async => store.remove(key);
  @override
  Future<void> deleteAll() async => store.clear();

  @override
  Future<Set<String>> keys() => throw UnimplementedError('not used by this test');
}

/// Dependencies whose 401 predicate accepts no 401, as an app on a backend that narrows it does.
class _NoSessionExpiryDependencies extends AppDependencies {
  _NoSessionExpiryDependencies() : super(appConfig: _prodConfig, authMode: _oidcMode);

  @override
  SessionExpiredPredicate get sessionExpiredPredicate =>
      (_) => false;
}

final _oidcMode = OidcAuthMode(OidcSettings(issuer: Uri.parse('https://id.example.test/realms/demo'), clientId: 'app'));

/// A production config, so no MockInterceptor answers in place of the adapter the tests install.
const _prodConfig = AppConfig(
  environment: Environment.prod,
  apiBaseUrl: 'https://api.example.test',
  certificatePins: [],
  idleTimeout: null,
);

/// A TokenRotation that records each refresh token it is asked to rotate and answers [result], a refusal by default.
class _FakeRotation implements TokenRotation {
  _FakeRotation([this.result = const RotationRefused()]);

  final TokenRotationResult result;
  final sent = <String>[];

  @override
  Future<TokenRotationResult> rotate(String refreshToken) async {
    sent.add(refreshToken);
    return result;
  }
}

/// Answers every request with 401, and records each request as `METHOD path`.
class _UnauthorizedAdapter implements HttpClientAdapter {
  _UnauthorizedAdapter([this.body = '', this.statusCode = 401]);

  /// The body of every answer.
  final String body;

  /// The status of every answer, 401 unless a test asks for another refusal.
  final int statusCode;

  final requests = <String>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add('${options.method} ${options.path}');
    return ResponseBody.fromString(
      body,
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// A secure store holding a signed-in session with a refresh token.
Future<_MemorySecureStorage> _signedInStorage() async {
  final storage = _MemorySecureStorage();
  await storage.write(SecureStorageKeys.jwtToken.key, 'ACCESS');
  await storage.write(SecureStorageKeys.refreshToken.key, 'REFRESH');
  return storage;
}

/// Sends a GET of [path] through [client], whose server answers [adapter]'s 401, and waits for it to fail.
Future<void> _getUnauthorized(ApiClient client, _UnauthorizedAdapter adapter, [String path = '/api/users']) async {
  client.instance.httpClientAdapter = adapter;
  await expectLater(client.get(path).timeout(const Duration(seconds: 5)), throwsA(anything));
}

final _oidcSession = AuthSession(
  idToken: 'ACCESS',
  oidcIdToken: 'ID_TOKEN',
  accessTokenExpiresAt: DateTime.utc(2026, 10, 21, 12),
);

void main() {
  final dependencies = AppDependencies(authMode: _oidcMode);

  test('app dependencies expose auth repository contract', () {
    final sessionRepository = dependencies.createAuthSessionRepository(_StubSecureStorage());
    expect(dependencies.createAuthRepository(sessionRepository), isA<IAuthRepository>());
  });

  test('the session repository stores the OIDC ID token and the expiry', () async {
    final secureStorage = _MemorySecureStorage();

    await dependencies.createAuthSessionRepository(secureStorage).persist(_oidcSession);

    expect(secureStorage.store[SecureStorageKeys.oidcIdToken.key], 'ID_TOKEN');
    expect(secureStorage.store[SecureStorageKeys.accessTokenExpiresAt.key], isNotNull);
  });

  // LibreDB Studio also answers 401 for a wrong database password (AUTH_ERROR), which must not end the session.
  test('the 401 predicate is Studio\'s', () {
    expect(dependencies.sessionExpiredPredicate, same(isStudioSessionExpired));
  });

  test('createApiClient keeps the session on a 401 AUTH_ERROR, a refused database credential', () async {
    final adapter = _UnauthorizedAdapter('{"error":"password authentication failed","code":"AUTH_ERROR"}');
    final rotation = _FakeRotation();
    var sessionExpiredCalls = 0;
    final client = AppDependencies(
      appConfig: _prodConfig,
      authMode: _oidcMode,
    ).createApiClient(await _signedInStorage(), onSessionExpired: () => sessionExpiredCalls++, tokenRotation: rotation);

    await _getUnauthorized(client, adapter);

    expect(adapter.requests, ['GET /api/users'], reason: 'AUTH_ERROR starts no refresh');
    expect(rotation.sent, isEmpty);
    expect(sessionExpiredCalls, 0);
  });

  test('createApiClient routes a 401 to the given rotation', () async {
    final adapter = _UnauthorizedAdapter();
    final rotation = _FakeRotation();
    var sessionExpiredCalls = 0;
    final client = AppDependencies(
      appConfig: _prodConfig,
      authMode: _oidcMode,
    ).createApiClient(await _signedInStorage(), onSessionExpired: () => sessionExpiredCalls++, tokenRotation: rotation);

    await _getUnauthorized(client, adapter);

    expect(rotation.sent, ['REFRESH']);
    expect(adapter.requests, ['GET /api/users'], reason: 'the refresh goes to the identity provider, not the API');
    expect(sessionExpiredCalls, 1, reason: 'the fake rotation refuses');
  });

  // GET /api/auth/me also answers 401 without a code when Studio cannot reach Keycloak, which a new session would not fix.
  test('the predicate of a 401 after a refresh is Studio\'s', () {
    expect(dependencies.sessionRefusedPredicate, same(isStudioSessionRefused));
  });

  test('createApiClient keeps the session when /auth/me answers 401 without a code after a refresh', () async {
    final adapter = _UnauthorizedAdapter('{"authenticated":false}');
    final rotation = _FakeRotation(const TokensRotated(accessToken: 'NEW_ACCESS'));
    var sessionExpiredCalls = 0;
    final client = AppDependencies(
      appConfig: _prodConfig,
      authMode: _oidcMode,
    ).createApiClient(await _signedInStorage(), onSessionExpired: () => sessionExpiredCalls++, tokenRotation: rotation);

    await _getUnauthorized(client, adapter, '/auth/me');

    expect(rotation.sent, ['REFRESH']);
    expect(adapter.requests, ['GET /auth/me', 'GET /auth/me'], reason: 'sent again once with the new token');
    expect(sessionExpiredCalls, 0);
  });

  test('createApiClient ends the session when Studio answers 401 AUTH_REQUIRED after a refresh', () async {
    final adapter = _UnauthorizedAdapter('{"error":"Invalid access token","code":"AUTH_REQUIRED"}');
    final rotation = _FakeRotation(const TokensRotated(accessToken: 'NEW_ACCESS'));
    var sessionExpiredCalls = 0;
    final client = AppDependencies(
      appConfig: _prodConfig,
      authMode: _oidcMode,
    ).createApiClient(await _signedInStorage(), onSessionExpired: () => sessionExpiredCalls++, tokenRotation: rotation);

    await _getUnauthorized(client, adapter, '/connections/managed');

    expect(adapter.requests, ['GET /connections/managed', 'GET /connections/managed']);
    expect(sessionExpiredCalls, 1);
  });

  // From libredb-studio#1922 on, Studio refuses an account it does not accept with 403 and its own code.
  test('the account refusal is Studio\'s', () {
    expect(dependencies.accountRefusal, same(studioAccountRefusal));
  });

  test(
    'createApiClient reports a 403 BEARER_NO_ROLE to onAccountRefused, with no refresh and the session kept',
    () async {
      final adapter = _UnauthorizedAdapter(
        '{"error":"This account has no role in Studio.","code":"BEARER_NO_ROLE"}',
        403,
      );
      final rotation = _FakeRotation();
      var sessionExpiredCalls = 0;
      final refusals = <AppErrorCode>[];
      final client = AppDependencies(appConfig: _prodConfig, authMode: _oidcMode).createApiClient(
        await _signedInStorage(),
        onSessionExpired: () => sessionExpiredCalls++,
        onAccountRefused: refusals.add,
        tokenRotation: rotation,
      );

      await _getUnauthorized(client, adapter, '/connections/managed');

      expect(refusals, [AppErrorCode.studioAccountHasNoRole]);
      expect(adapter.requests, ['GET /connections/managed']);
      expect(rotation.sent, isEmpty);
      expect(sessionExpiredCalls, 0);
    },
  );

  test('createApiClient uses sessionExpiredPredicate', () async {
    final adapter = _UnauthorizedAdapter();
    final rotation = _FakeRotation();
    var sessionExpiredCalls = 0;
    final client = _NoSessionExpiryDependencies().createApiClient(
      await _signedInStorage(),
      onSessionExpired: () => sessionExpiredCalls++,
      tokenRotation: rotation,
    );

    await _getUnauthorized(client, adapter);

    expect(rotation.sent, isEmpty);
    expect(sessionExpiredCalls, 0);
  });

  test('app dependencies expose lifecycle repository contract', () {
    expect(dependencies.createLifecycleRepository(TestEnv.apiClient()), isA<ILifecycleRepository>());
  });

  test('app dependencies expose provider meta repository contract', () {
    expect(dependencies.createProviderMetaRepository(TestEnv.apiClient()), isA<IProviderMetaRepository>());
  });

  test('app dependencies expose the shared statement runner, which the SQL editor runs through', () {
    final queryTimeouts = ConnectionQueryTimeouts();
    final statements = dependencies.createStatementRepository(TestEnv.apiClient(), queryTimeouts);

    expect(statements, isA<IStatementRepository>());
    expect(
      dependencies.createSqlEditorRepository(TestEnv.apiClient(), statements, queryTimeouts),
      isA<ISqlEditorRepository>(),
    );
  });

  test('app dependencies expose the encrypted statement text store, keyed through the secure storage', () {
    expect(dependencies.createStatementTextStore(dependencies.createSecureStorage()), isA<IStatementTextStore>());
  });

  test('every feature reads provider-meta and the object routes through the in-memory caches', () {
    expect(dependencies.createProviderMetaRepository(TestEnv.apiClient()), isA<CachedProviderMetaRepository>());
    expect(dependencies.createObjectBrowserRepository(TestEnv.apiClient()), isA<CachedObjectBrowserRepository>());
  });
}
