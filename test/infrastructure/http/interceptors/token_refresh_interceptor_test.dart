import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:libredb_mobile/infrastructure/http/interceptors/auth_interceptor.dart';
import 'package:libredb_mobile/infrastructure/http/interceptors/resilience_interceptor.dart';
import 'package:libredb_mobile/infrastructure/http/interceptors/token_refresh_interceptor.dart';
import 'package:libredb_mobile/infrastructure/http/token_rotation.dart';
import 'package:libredb_mobile/infrastructure/storage/secure_storage.dart';
import 'package:libredb_mobile/infrastructure/storage/session_generation.dart';
import 'package:libredb_mobile/infrastructure/studio/studio_session_policy.dart';
import 'package:flutter_test/flutter_test.dart';

/// ISecureStorage whose jwtToken read throws (refresh token is normal).
/// Exercises the stale-header check's graceful-fallback path.
class _ReadThrowsOnJwtSecureStorage implements ISecureStorage {
  final Map<String, String> _store = {};
  @override
  Future<String?> read(String key) async {
    if (key == SecureStorageKeys.jwtToken.key) throw StateError('boom on jwt read');
    return _store[key];
  }

  @override
  Future<void> write(String key, String value) async => _store[key] = value;
  @override
  Future<void> delete(String key) async => _store.remove(key);
  @override
  Future<void> deleteAll() async => _store.clear();

  @override
  Future<Set<String>> keys() => throw UnimplementedError('not used by this test');
}

/// In-memory ISecureStorage for tests. Counts reads of the refresh-token
/// key, the proxy several tests use for whether a refresh started.
class _MemorySecureStorage implements ISecureStorage {
  final Map<String, String> _store = {};
  int refreshTokenReadCount = 0;
  @override
  Future<String?> read(String key) async {
    if (key == SecureStorageKeys.refreshToken.key) refreshTokenReadCount++;
    return _store[key];
  }

  @override
  Future<void> write(String key, String value) async => _store[key] = value;
  @override
  Future<void> delete(String key) async => _store.remove(key);
  @override
  Future<void> deleteAll() async => _store.clear();

  @override
  Future<Set<String>> keys() => throw UnimplementedError('not used by this test');
}

/// A request to [path] as AuthInterceptor sends it, which records the session generation the request goes out under.
RequestOptions _sentRequest(String path, {String? method, Map<String, dynamic>? headers}) => RequestOptions(
  path: path,
  method: method,
  headers: headers,
  extra: {AuthInterceptor.sessionGenerationKey: SessionGeneration.current},
);

/// The public endpoints the app calls before sign-in: Studio's liveness and readiness.
const _publicEndpoints = [('GET', '/health'), ('GET', '/ready')];

void main() {
  late Dio dio;
  late _MemorySecureStorage secureStorage;

  setUp(() async {
    secureStorage = _MemorySecureStorage();
    dio = Dio(BaseOptions(baseUrl: 'https://test.api', responseType: ResponseType.plain));
  });

  tearDown(() async {
    dio.close();
  });

  group('TokenRefreshInterceptor', () {
    // Not a QueuedInterceptor: the retry after a refresh goes back through the same Dio, and a queued
    // onError would hold the retry's error behind the call waiting for it, so both would hang.
    // Concurrent 401s share one refresh through the in-flight Future instead.
    test('should be a plain Interceptor, not a QueuedInterceptor', () {
      final interceptor = TokenRefreshInterceptor(rotation: const _NoServerRotation(), dio: dio);
      expect(interceptor, isA<Interceptor>());
      expect(interceptor, isNot(isA<QueuedInterceptor>()));
    });

    test('should accept optional onSessionExpired callback', () {
      // Should not throw with null callback
      final interceptor1 = TokenRefreshInterceptor(rotation: const _NoServerRotation(), dio: dio);
      expect(interceptor1, isA<TokenRefreshInterceptor>());

      // Should not throw with provided callback
      final interceptor2 = TokenRefreshInterceptor(
        rotation: const _NoServerRotation(),
        dio: dio,
        onSessionExpired: () {},
      );
      expect(interceptor2, isA<TokenRefreshInterceptor>());
    });
  });

  group('TokenRefreshInterceptor - non-401 errors', () {
    test('should pass through 400 errors without attempting refresh', () async {
      final interceptor = TokenRefreshInterceptor(rotation: const _NoServerRotation(), dio: dio);
      final handler = _TestErrorHandler();
      final requestOptions = RequestOptions(path: '/api/users');

      final error = DioException(
        requestOptions: requestOptions,
        response: Response(requestOptions: requestOptions, statusCode: 400, data: 'Bad Request'),
      );

      await interceptor.onError(error, handler);

      expect(handler.nextCalled, isTrue);
      expect(handler.resolveCalled, isFalse);
    });

    test('should pass through 500 errors without attempting refresh', () async {
      final interceptor = TokenRefreshInterceptor(rotation: const _NoServerRotation(), dio: dio);
      final handler = _TestErrorHandler();
      final requestOptions = RequestOptions(path: '/api/users');

      final error = DioException(
        requestOptions: requestOptions,
        response: Response(requestOptions: requestOptions, statusCode: 500, data: 'Server Error'),
      );

      await interceptor.onError(error, handler);

      expect(handler.nextCalled, isTrue);
      expect(handler.resolveCalled, isFalse);
    });

    test('should pass through 403 errors without attempting refresh', () async {
      final interceptor = TokenRefreshInterceptor(rotation: const _NoServerRotation(), dio: dio);
      final handler = _TestErrorHandler();
      final requestOptions = RequestOptions(path: '/api/users');

      final error = DioException(
        requestOptions: requestOptions,
        response: Response(requestOptions: requestOptions, statusCode: 403, data: 'Forbidden'),
      );

      await interceptor.onError(error, handler);

      expect(handler.nextCalled, isTrue);
    });

    test('should not call onSessionExpired for non-401 errors', () async {
      var sessionExpiredCalled = false;
      final interceptor = TokenRefreshInterceptor(
        rotation: const _NoServerRotation(),
        dio: dio,
        onSessionExpired: () => sessionExpiredCalled = true,
      );
      final handler = _TestErrorHandler();
      final requestOptions = RequestOptions(path: '/api/users');

      for (final statusCode in [400, 403, 404, 500, 502, 503]) {
        sessionExpiredCalled = false;

        final error = DioException(
          requestOptions: requestOptions,
          response: Response(requestOptions: requestOptions, statusCode: statusCode),
        );

        await interceptor.onError(error, handler);

        expect(sessionExpiredCalled, isFalse, reason: 'Should not expire session for $statusCode');
      }
    });

    test('should pass through errors with null response', () async {
      final interceptor = TokenRefreshInterceptor(rotation: const _NoServerRotation(), dio: dio);
      final handler = _TestErrorHandler();
      final requestOptions = RequestOptions(path: '/api/users');

      final error = DioException(
        requestOptions: requestOptions,
        type: DioExceptionType.connectionError,
        // No response — null statusCode
      );

      await interceptor.onError(error, handler);

      expect(handler.nextCalled, isTrue);
    });
  });

  group('TokenRefreshInterceptor - 401 from a public endpoint', () {
    // A public endpoint serves requests without a session, so its 401 is not about the session.
    test('passes the 401 on without refreshing or ending the session', () async {
      await secureStorage.write(SecureStorageKeys.jwtToken.key, 'expired-jwt');
      await secureStorage.write(SecureStorageKeys.refreshToken.key, 'valid-refresh-token');
      var sessionExpiredCalls = 0;
      final interceptor = TokenRefreshInterceptor(
        rotation: const _NoServerRotation(),
        dio: dio,
        secureStorage: secureStorage,
        onSessionExpired: () => sessionExpiredCalls++,
      );

      for (final (method, path) in _publicEndpoints) {
        // With a session generation recorded, as if the endpoint were not public, so only the public check stops the
        // refresh.
        final requestOptions = RequestOptions(
          path: path,
          method: method,
          extra: {'_basePath': path, AuthInterceptor.sessionGenerationKey: SessionGeneration.current},
        );
        final error = DioException(
          requestOptions: requestOptions,
          response: Response(requestOptions: requestOptions, statusCode: 401),
        );
        final handler = _TestErrorHandler();

        await interceptor.onError(error, handler);

        expect(handler.nextError, same(error), reason: '$method $path');
        expect(handler.resolveCalled, isFalse, reason: '$method $path');
      }
      expect(secureStorage.refreshTokenReadCount, 0, reason: 'the refresh-token read is the proxy for a refresh');
      expect(sessionExpiredCalls, 0);
    });

    // The public list held paths without methods, so a 401 from a protected request on the path of a public endpoint
    // would have been taken for rejected credentials and never refreshed the session. No shipped request sends one yet.
  });

  // AuthInterceptor sends no token to another origin, so a 401 from there is not about the session, and sending the
  // request again after a refresh would carry the rotated token there.
  group('TokenRefreshInterceptor - 401 from another origin', () {
    DioException unauthorizedFrom(String url, {Map<String, dynamic>? headers}) {
      final requestOptions = RequestOptions(
        baseUrl: 'https://test.api',
        path: url,
        headers: headers,
        extra: {AuthInterceptor.sessionGenerationKey: SessionGeneration.current},
      );
      return DioException(
        requestOptions: requestOptions,
        response: Response(requestOptions: requestOptions, statusCode: 401),
      );
    }

    test('passes the 401 on without refreshing, sending it again or ending the session', () async {
      await secureStorage.write(SecureStorageKeys.jwtToken.key, 'old-jwt');
      await secureStorage.write(SecureStorageKeys.refreshToken.key, 'valid-refresh');
      final retryStub = _CapturingSuccessStub();
      dio.interceptors.add(retryStub);
      var refreshRequests = 0;
      var sessionExpiredCalls = 0;
      final interceptor = TokenRefreshInterceptor(
        dio: dio,
        secureStorage: secureStorage,
        onSessionExpired: () => sessionExpiredCalls++,
        rotation: _DioRotation((source) {
          refreshRequests++;
          return Dio(BaseOptions(baseUrl: source.options.baseUrl))
            ..interceptors.add(_StubInterceptor()..stubSuccess(data: '{"id_token":"new-jwt"}'));
        }),
      );
      final error = unauthorizedFrom('https://other.example/collect');
      final handler = _TestErrorHandler();

      await interceptor.onError(error, handler);

      expect(handler.nextError, same(error));
      expect(handler.resolveCalled, isFalse);
      expect(refreshRequests, 0);
      expect(secureStorage.refreshTokenReadCount, 0);
      expect(retryStub.lastAuthorization, isNull, reason: 'the request must not be sent again with a token');
      expect(sessionExpiredCalls, 0);
    });

    test('does not send the current token there when the token was rotated since the request was sent', () async {
      await secureStorage.write(SecureStorageKeys.jwtToken.key, 'current-jwt');
      final retryStub = _CapturingSuccessStub();
      dio.interceptors.add(retryStub);
      final interceptor = TokenRefreshInterceptor(
        rotation: const _NoServerRotation(),
        dio: dio,
        secureStorage: secureStorage,
      );
      final error = unauthorizedFrom('https://other.example/collect', headers: {'Authorization': 'Bearer old-jwt'});
      final handler = _TestErrorHandler();

      await interceptor.onError(error, handler);

      expect(handler.nextError, same(error));
      expect(retryStub.lastAuthorization, isNull, reason: 'the request must not be sent again with a token');
    });

    test('still refreshes for a 401 from the API origin', () async {
      await secureStorage.write(SecureStorageKeys.refreshToken.key, 'valid-refresh');
      final retryStub = _CapturingSuccessStub();
      dio.interceptors.add(retryStub);
      final interceptor = TokenRefreshInterceptor(
        dio: dio,
        secureStorage: secureStorage,
        rotation: _DioRotation(
          (source) =>
              Dio(BaseOptions(baseUrl: source.options.baseUrl))
                ..interceptors.add(_StubInterceptor()..stubSuccess(data: '{"id_token":"new-jwt"}')),
        ),
      );
      final handler = _TestErrorHandler();

      await interceptor.onError(unauthorizedFrom('https://test.api/api/users'), handler);

      expect(handler.resolveCalled, isTrue);
      expect(retryStub.lastAuthorization, 'Bearer new-jwt');
    });
  });

  group('TokenRefreshInterceptor - 401 with no refresh token', () {
    test('should call onSessionExpired when no refresh token is stored', () async {
      var sessionExpiredCalled = false;
      final interceptor = TokenRefreshInterceptor(
        rotation: const _NoServerRotation(),
        dio: dio,
        onSessionExpired: () => sessionExpiredCalled = true,
      );
      final handler = _TestErrorHandler();
      final requestOptions = _sentRequest('/api/users');

      final error = DioException(
        requestOptions: requestOptions,
        response: Response(requestOptions: requestOptions, statusCode: 401),
      );

      // No refresh token in storage
      await interceptor.onError(error, handler);

      expect(sessionExpiredCalled, isTrue);
      expect(handler.nextCalled, isTrue);
    });

    test('should call onSessionExpired when refresh token is empty string', () async {
      await secureStorage.write(SecureStorageKeys.refreshToken.key, '');

      var sessionExpiredCalled = false;
      final interceptor = TokenRefreshInterceptor(
        rotation: const _NoServerRotation(),
        dio: dio,
        onSessionExpired: () => sessionExpiredCalled = true,
        secureStorage: secureStorage,
      );
      final handler = _TestErrorHandler();
      final requestOptions = _sentRequest('/api/users');

      final error = DioException(
        requestOptions: requestOptions,
        response: Response(requestOptions: requestOptions, statusCode: 401),
      );

      await interceptor.onError(error, handler);

      expect(sessionExpiredCalled, isTrue);
      expect(handler.nextCalled, isTrue);
    });
  });

  group('TokenRefreshInterceptor - 401 with refresh token', () {
    test('should attempt refresh and call onSessionExpired when refresh fails', () async {
      await secureStorage.write(SecureStorageKeys.refreshToken.key, 'valid-refresh-token');
      await secureStorage.write(SecureStorageKeys.jwtToken.key, 'old-jwt-token');

      var sessionExpiredCalled = false;
      final interceptor = TokenRefreshInterceptor(
        rotation: const _NoServerRotation(),
        dio: dio,
        onSessionExpired: () => sessionExpiredCalled = true,
        secureStorage: secureStorage,
      );
      final handler = _TestErrorHandler();
      final requestOptions = _sentRequest('/api/users');

      final error = DioException(
        requestOptions: requestOptions,
        response: Response(requestOptions: requestOptions, statusCode: 401),
      );

      // The identity provider refuses the refresh, which ends the session.
      await interceptor.onError(error, handler);

      expect(sessionExpiredCalled, isTrue);
      expect(handler.nextCalled, isTrue);
    });
  });

  group('TokenRefreshInterceptor - concurrent refresh coalescing', () {
    test('coalesces concurrent 401s into a single refresh request', () async {
      await secureStorage.write(SecureStorageKeys.refreshToken.key, 'valid-refresh-token');
      var refreshRequests = 0;

      final interceptor = TokenRefreshInterceptor(
        dio: dio,
        secureStorage: secureStorage,
        rotation: _DioRotation((source) {
          refreshRequests++;
          return Dio(BaseOptions(baseUrl: source.options.baseUrl))
            ..interceptors.add(_StubInterceptor()..stubError(statusCode: 401));
        }),
      );
      DioException makeErr() {
        final ro = _sentRequest('/api/users');
        return DioException(
          requestOptions: ro,
          response: Response(requestOptions: ro, statusCode: 401),
        );
      }

      final h1 = _TestErrorHandler();
      final h2 = _TestErrorHandler();
      final h3 = _TestErrorHandler();

      await Future.wait([
        interceptor.onError(makeErr(), h1),
        interceptor.onError(makeErr(), h2),
        interceptor.onError(makeErr(), h3),
      ]);

      // Without coalescing this would be 3, one refresh request per
      // concurrent 401. With the in-flight Future shared, all three
      // queued callers await the same refresh.
      expect(refreshRequests, 1, reason: 'concurrent 401s should share a single refresh attempt');
    });

    test('does not attempt a second refresh when the retried request 401s again', () async {
      // Simulates a request that has already been retried after a
      // refresh — RequestOptions.extra carries the _retriedAfterRefresh
      // marker. A second 401 must short-circuit to logout instead of
      // entering another refresh round (which would just rotate
      // tokens forever against a backend that keeps rejecting them).
      var sessionExpiredCalls = 0;
      await secureStorage.write(SecureStorageKeys.refreshToken.key, 'valid-refresh-token');
      final baselineRefreshReads = secureStorage.refreshTokenReadCount;

      final interceptor = TokenRefreshInterceptor(
        rotation: const _NoServerRotation(),
        dio: dio,
        secureStorage: secureStorage,
        onSessionExpired: () => sessionExpiredCalls++,
      );
      final ro = _sentRequest('/api/users', headers: {'Authorization': 'Bearer SOME_JWT'});
      // Marker is an Expando keyed on RequestOptions (typed, per-
      // instance, no map collisions). debugMarkAsRetried is the
      // sanctioned test-only path to set it without driving a full
      // refresh+retry round.
      TokenRefreshInterceptor.debugMarkAsRetried(ro);
      final error = DioException(
        requestOptions: ro,
        response: Response(requestOptions: ro, statusCode: 401),
      );
      final handler = _TestErrorHandler();

      await interceptor.onError(error, handler);

      expect(sessionExpiredCalls, 1, reason: 'must surface logout on second 401');
      expect(handler.nextCalled, isTrue);
      expect(
        secureStorage.refreshTokenReadCount - baselineRefreshReads,
        0,
        reason: 'must NOT enter the refresh path — refresh-token read is the proxy',
      );
    });

    test('stale-header check survives a throwing secure read (graceful fallback)', () async {
      // Failing-but-readable secure store: jwtToken throws, refreshToken
      // exists. The stale-header optimization read should be swallowed
      // and we should fall through to the normal refresh path — letting
      // the throw escape would break the request pipeline.
      final flaky = _ReadThrowsOnJwtSecureStorage();
      await flaky.write(SecureStorageKeys.refreshToken.key, 'valid-refresh-token');

      final interceptor = TokenRefreshInterceptor(rotation: const _NoServerRotation(), dio: dio, secureStorage: flaky);
      final ro = _sentRequest('/api/users', headers: {'Authorization': 'Bearer OLD_JWT'});
      final error = DioException(
        requestOptions: ro,
        response: Response(requestOptions: ro, statusCode: 401),
      );
      final handler = _TestErrorHandler();

      // Must NOT throw; falls through to refresh attempt which will
      // also fail (no real server), so onSessionExpired is reached.
      await interceptor.onError(error, handler);
      expect(handler.nextCalled, isTrue);
    });

    test('skips refresh when JWT was already rotated since the failing request was sent', () async {
      // Secure store already has the rotated token; the failing
      // request carries the previous one. Interceptor should detect
      // that and NOT call refresh again.
      await secureStorage.write(SecureStorageKeys.jwtToken.key, 'NEW_JWT');
      await secureStorage.write(SecureStorageKeys.refreshToken.key, 'valid-refresh-token');
      final baselineRefreshReads = secureStorage.refreshTokenReadCount;
      final retryStub = _CapturingSuccessStub();
      dio.interceptors.add(retryStub);

      final interceptor = TokenRefreshInterceptor(
        rotation: const _NoServerRotation(),
        dio: dio,
        secureStorage: secureStorage,
      );
      final requestOptions = _sentRequest('/api/users', headers: {'Authorization': 'Bearer OLD_JWT'});
      final error = DioException(
        requestOptions: requestOptions,
        response: Response(requestOptions: requestOptions, statusCode: 401),
      );
      final handler = _TestErrorHandler();

      await interceptor.onError(error, handler);

      expect(
        secureStorage.refreshTokenReadCount - baselineRefreshReads,
        0,
        reason: 'stale header path must NOT call refresh; refresh-token read is the proxy for that',
      );
      expect(retryStub.lastAuthorization, 'Bearer NEW_JWT');
    });

    test('clears in-flight Future so a later 401 starts a fresh refresh', () async {
      await secureStorage.write(SecureStorageKeys.refreshToken.key, 'valid-refresh-token');
      final interceptor = TokenRefreshInterceptor(
        rotation: const _NoServerRotation(),
        dio: dio,
        secureStorage: secureStorage,
      );
      DioException makeErr() {
        final ro = _sentRequest('/api/users');
        return DioException(
          requestOptions: ro,
          response: Response(requestOptions: ro, statusCode: 401),
        );
      }

      // First wave completes…
      await interceptor.onError(makeErr(), _TestErrorHandler());
      final after1 = secureStorage.refreshTokenReadCount;

      // …then a later 401 (after the in-flight Future cleared) starts
      // its own refresh sequence.
      await interceptor.onError(makeErr(), _TestErrorHandler());
      final after2 = secureStorage.refreshTokenReadCount;

      expect(after2, greaterThan(after1), reason: 'next 401 must trigger a new refresh');
    });
  });

  group('TokenRefreshInterceptor - onSessionExpired null safety', () {
    test('should not crash when onSessionExpired is null with no refresh token', () async {
      final interceptor = TokenRefreshInterceptor(rotation: const _NoServerRotation(), dio: dio);
      final handler = _TestErrorHandler();
      final requestOptions = _sentRequest('/api/users');

      final error = DioException(
        requestOptions: requestOptions,
        response: Response(requestOptions: requestOptions, statusCode: 401),
      );

      // No refresh token, no callback — should not throw
      await interceptor.onError(error, handler);

      expect(handler.nextCalled, isTrue);
    });
  });

  group('TokenRefreshInterceptor - Dio integration', () {
    test('should pass through non-401 errors in Dio pipeline', () async {
      final stubInterceptor = _StubInterceptor();
      final interceptor = TokenRefreshInterceptor(rotation: const _NoServerRotation(), dio: dio);

      dio.interceptors.addAll([stubInterceptor, interceptor]);
      stubInterceptor.stubError(statusCode: 400, data: 'Bad Request');

      await expectLater(
        () => dio.get('/api/users'),
        throwsA(predicate<DioException>((e) => e.response?.statusCode == 400)),
      );
    });

    test('should pass through 500 errors in Dio pipeline', () async {
      final stubInterceptor = _StubInterceptor();
      final interceptor = TokenRefreshInterceptor(rotation: const _NoServerRotation(), dio: dio);

      dio.interceptors.addAll([stubInterceptor, interceptor]);
      stubInterceptor.stubError(statusCode: 500, data: 'Server Error');

      await expectLater(
        () => dio.get('/api/users'),
        throwsA(predicate<DioException>((e) => e.response?.statusCode == 500)),
      );
    });

    test('should not interfere with successful requests', () async {
      final stubInterceptor = _StubInterceptor();
      final interceptor = TokenRefreshInterceptor(rotation: const _NoServerRotation(), dio: dio);

      dio.interceptors.addAll([stubInterceptor, interceptor]);
      stubInterceptor.stubSuccess(data: '{"result":"ok"}');

      final response = await dio.get('/api/users');

      expect(response.statusCode, 200);
      expect(response.data, '{"result":"ok"}');
    });

    test('logs out without a second refresh when the retry is rejected with 401 again', () async {
      // The retry comes back through this interceptor, where the retry marker ends the session. The call is
      // bounded because a queued interceptor used to hang here.
      await secureStorage.write(SecureStorageKeys.jwtToken.key, 'old-jwt');
      await secureStorage.write(SecureStorageKeys.refreshToken.key, 'valid-refresh');
      var refreshRequests = 0;
      var sessionExpiredCalls = 0;
      final server = _UnauthorizedServerStub();

      dio.interceptors.addAll([
        AuthInterceptor(secureStorage: secureStorage),
        TokenRefreshInterceptor(
          dio: dio,
          secureStorage: secureStorage,
          onSessionExpired: () => sessionExpiredCalls++,
          rotation: _DioRotation((source) {
            refreshRequests++;
            final refreshDio = Dio(BaseOptions(baseUrl: source.options.baseUrl));
            refreshDio.interceptors.add(_StubInterceptor()..stubSuccess(data: '{"id_token":"new-jwt"}'));
            return refreshDio;
          }),
        ),
        server,
      ]);

      await expectLater(
        dio
            .get<String>('/api/users', options: Options(headers: {'Authorization': 'Bearer old-jwt'}))
            .timeout(const Duration(seconds: 5)),
        throwsA(isA<DioException>().having((e) => e.response?.statusCode, 'statusCode', 401)),
      );

      expect(server.authorizations, ['Bearer old-jwt', 'Bearer new-jwt']);
      expect(sessionExpiredCalls, 1);
      expect(refreshRequests, 1, reason: 'exactly one refresh');
    });
  });

  group('TokenRefreshInterceptor - 401 followed by successful refresh', () {
    // Drives [TokenRefreshInterceptor.onError] directly (mirroring the
    // existing 401-with-refresh-token test) and short-circuits the
    // retry's _dio.fetch by adding a [_CapturingSuccessStub] to the
    // production Dio. This isolates the assertions to the interceptor's
    // own contract — no full Dio pipeline, no real HTTP.

    test('persists rotated tokens, retries original request with new Bearer, marker stamped', () async {
      await secureStorage.write(SecureStorageKeys.jwtToken.key, 'old-jwt');
      await secureStorage.write(SecureStorageKeys.refreshToken.key, 'valid-refresh');

      final retryStub = _CapturingSuccessStub();
      dio.interceptors.add(retryStub);

      final interceptor = TokenRefreshInterceptor(
        dio: dio,
        secureStorage: secureStorage,
        rotation: _DioRotation((source) {
          final refreshDio = Dio(BaseOptions(baseUrl: source.options.baseUrl));
          refreshDio.interceptors.add(
            _StubInterceptor()..stubSuccess(data: '{"id_token":"new-jwt","refresh_token":"new-refresh"}'),
          );
          return refreshDio;
        }),
      );

      final requestOptions = _sentRequest('/api/users', headers: {'Authorization': 'Bearer old-jwt'});
      final error = DioException(
        requestOptions: requestOptions,
        response: Response(requestOptions: requestOptions, statusCode: 401),
      );
      final handler = _TestErrorHandler();

      await interceptor.onError(error, handler);

      // Retry succeeded → resolve.
      expect(handler.resolveCalled, isTrue, reason: 'retried request must resolve, not surface 401');
      expect(handler.nextCalled, isFalse);

      // Retry used the rotated token and was marked.
      expect(retryStub.lastAuthorization, 'Bearer new-jwt');
      expect(retryStub.lastRetryMarker, isTrue);

      // Rotated tokens persisted, ready for next outgoing call.
      expect(await secureStorage.read(SecureStorageKeys.jwtToken.key), 'new-jwt');
      expect(await secureStorage.read(SecureStorageKeys.refreshToken.key), 'new-refresh');
    });

    // The target is written once, at sign-in; a refresh rotates the tokens of the same session.
    test('leaves the stored session target as it is', () async {
      await secureStorage.write(SecureStorageKeys.sessionTarget.key, 'platform');
      await secureStorage.write(SecureStorageKeys.jwtToken.key, 'old-jwt');
      await secureStorage.write(SecureStorageKeys.refreshToken.key, 'valid-refresh');
      dio.interceptors.add(_CapturingSuccessStub());
      final interceptor = TokenRefreshInterceptor(
        dio: dio,
        secureStorage: secureStorage,
        rotation: _DioRotation((source) {
          final refreshDio = Dio(BaseOptions(baseUrl: source.options.baseUrl));
          refreshDio.interceptors.add(
            _StubInterceptor()..stubSuccess(data: '{"id_token":"new-jwt","refresh_token":"new-refresh"}'),
          );
          return refreshDio;
        }),
      );
      final requestOptions = _sentRequest('/api/users', headers: {'Authorization': 'Bearer old-jwt'});
      final handler = _TestErrorHandler();

      await interceptor.onError(
        DioException(
          requestOptions: requestOptions,
          response: Response(requestOptions: requestOptions, statusCode: 401),
        ),
        handler,
      );

      expect(handler.resolveCalled, isTrue);
      expect(await secureStorage.read(SecureStorageKeys.jwtToken.key), 'new-jwt');
      expect(await secureStorage.read(SecureStorageKeys.sessionTarget.key), 'platform');
    });

    test('persists only id_token when refresh response omits new refresh_token', () async {
      await secureStorage.write(SecureStorageKeys.jwtToken.key, 'old-jwt');
      await secureStorage.write(SecureStorageKeys.refreshToken.key, 'still-valid-refresh');

      dio.interceptors.add(_CapturingSuccessStub());

      final interceptor = TokenRefreshInterceptor(
        dio: dio,
        secureStorage: secureStorage,
        rotation: _DioRotation((source) {
          final refreshDio = Dio(BaseOptions(baseUrl: source.options.baseUrl));
          refreshDio.interceptors.add(_StubInterceptor()..stubSuccess(data: '{"id_token":"new-jwt"}'));
          return refreshDio;
        }),
      );

      final requestOptions = _sentRequest('/api/users');
      final error = DioException(
        requestOptions: requestOptions,
        response: Response(requestOptions: requestOptions, statusCode: 401),
      );
      await interceptor.onError(error, _TestErrorHandler());

      expect(await secureStorage.read(SecureStorageKeys.jwtToken.key), 'new-jwt');
      expect(
        await secureStorage.read(SecureStorageKeys.refreshToken.key),
        'still-valid-refresh',
        reason: 'omitted refresh_token in response must leave the existing one intact',
      );
    });

    test('logs out when refresh response is missing id_token', () async {
      await secureStorage.write(SecureStorageKeys.jwtToken.key, 'old-jwt');
      await secureStorage.write(SecureStorageKeys.refreshToken.key, 'valid-refresh');

      var logoutCount = 0;
      final interceptor = TokenRefreshInterceptor(
        dio: dio,
        secureStorage: secureStorage,
        onSessionExpired: () => logoutCount++,
        rotation: _DioRotation((source) {
          final refreshDio = Dio(BaseOptions(baseUrl: source.options.baseUrl));
          refreshDio.interceptors.add(_StubInterceptor()..stubSuccess(data: '{}'));
          return refreshDio;
        }),
      );

      final requestOptions = _sentRequest('/api/users');
      final error = DioException(
        requestOptions: requestOptions,
        response: Response(requestOptions: requestOptions, statusCode: 401),
      );
      final handler = _TestErrorHandler();

      await interceptor.onError(error, handler);

      expect(logoutCount, 1, reason: 'malformed refresh response must trigger session-expired');
      expect(handler.nextCalled, isTrue, reason: 'original 401 must surface');
      // Original token unchanged; no garbage persisted.
      expect(await secureStorage.read(SecureStorageKeys.jwtToken.key), 'old-jwt');
    });

    test('logs out when refresh response returns id_token=""', () async {
      await secureStorage.write(SecureStorageKeys.jwtToken.key, 'old-jwt');
      await secureStorage.write(SecureStorageKeys.refreshToken.key, 'valid-refresh');

      var logoutCount = 0;
      final interceptor = TokenRefreshInterceptor(
        dio: dio,
        secureStorage: secureStorage,
        onSessionExpired: () => logoutCount++,
        rotation: _DioRotation((source) {
          final refreshDio = Dio(BaseOptions(baseUrl: source.options.baseUrl));
          refreshDio.interceptors.add(_StubInterceptor()..stubSuccess(data: '{"id_token":""}'));
          return refreshDio;
        }),
      );

      final requestOptions = _sentRequest('/api/users');
      final error = DioException(
        requestOptions: requestOptions,
        response: Response(requestOptions: requestOptions, statusCode: 401),
      );
      await interceptor.onError(error, _TestErrorHandler());

      expect(logoutCount, 1);
      expect(await secureStorage.read(SecureStorageKeys.jwtToken.key), 'old-jwt');
    });

    test('logs out (no crash) when refresh response is a JSON array instead of an object', () async {
      // Defense against backend/proxy misconfiguration: if the body is
      // a JSON array (or any non-Map shape), parsing must not crash
      // the interceptor — surface as session-expired with a
      // diagnosable log.
      await secureStorage.write(SecureStorageKeys.jwtToken.key, 'old-jwt');
      await secureStorage.write(SecureStorageKeys.refreshToken.key, 'valid-refresh');

      var logoutCount = 0;
      final interceptor = TokenRefreshInterceptor(
        dio: dio,
        secureStorage: secureStorage,
        onSessionExpired: () => logoutCount++,
        rotation: _DioRotation((source) {
          final refreshDio = Dio(BaseOptions(baseUrl: source.options.baseUrl));
          refreshDio.interceptors.add(_StubInterceptor()..stubSuccess(data: '["not", "a", "map"]'));
          return refreshDio;
        }),
      );

      final requestOptions = _sentRequest('/api/users');
      final error = DioException(
        requestOptions: requestOptions,
        response: Response(requestOptions: requestOptions, statusCode: 401),
      );
      final handler = _TestErrorHandler();

      await interceptor.onError(error, handler);

      expect(logoutCount, 1, reason: 'non-object body must trigger session-expired');
      expect(handler.nextCalled, isTrue);
      expect(await secureStorage.read(SecureStorageKeys.jwtToken.key), 'old-jwt', reason: 'no garbage persisted');
    });

    test('rolls back rotated tokens to prior values when refresh_token write throws', () async {
      // Setup: prior tokens exist. Refresh returns new pair. Secure
      // storage succeeds writing the new id_token but throws on the
      // refresh_token write. The interceptor must restore both keys
      // to their prior values so the user re-authenticates cleanly
      // instead of running with a torn id/refresh pair.
      final torn = _RefreshWriteFailsSecureStorage();
      await torn.seed(jwt: 'prior-jwt', refresh: 'prior-refresh');

      final interceptor = TokenRefreshInterceptor(
        dio: dio,
        secureStorage: torn,
        rotation: _DioRotation((source) {
          final refreshDio = Dio(BaseOptions(baseUrl: source.options.baseUrl));
          refreshDio.interceptors.add(
            _StubInterceptor()..stubSuccess(data: '{"id_token":"new-jwt","refresh_token":"new-refresh"}'),
          );
          return refreshDio;
        }),
      );

      final requestOptions = _sentRequest('/api/users');
      final error = DioException(
        requestOptions: requestOptions,
        response: Response(requestOptions: requestOptions, statusCode: 401),
      );
      final handler = _TestErrorHandler();

      await interceptor.onError(error, handler);

      // The failed persist must surface as session-expired, not as a
      // half-applied rotation.
      expect(handler.nextCalled, isTrue, reason: 'original 401 must surface after rollback');
      expect(handler.resolveCalled, isFalse);

      // Both keys restored to prior values — no torn pair.
      expect(await torn.read(SecureStorageKeys.jwtToken.key), 'prior-jwt');
      expect(await torn.read(SecureStorageKeys.refreshToken.key), 'prior-refresh');
    });
  });

  // A logout or the idle timeout wipes the stored session and starts a new session generation. A refresh that was on
  // its way stored the rotated tokens after the wipe, so a relaunch restored the session the user had ended.
  // AuthInterceptor records on each request the session generation it is sent under. A refresh for a request whose
  // session a logout or the end of the session wiped, or is wiping, would spend a refresh token on a session that is
  // over, or on the one the user signed in to since.
  group('TokenRefreshInterceptor - the session a request was sent under', () {
    test('does not refresh while the session the request was sent under is being wiped', () async {
      await secureStorage.write(SecureStorageKeys.jwtToken.key, 'old-jwt');
      await secureStorage.write(SecureStorageKeys.refreshToken.key, 'valid-refresh-token');
      var sessionExpiredCalls = 0;
      final interceptor = TokenRefreshInterceptor(
        rotation: const _NoServerRotation(),
        dio: dio,
        secureStorage: secureStorage,
        onSessionExpired: () => sessionExpiredCalls++,
      );
      // The wipe has started but not yet deleted the stored tokens when the request goes out.
      final releaseWipe = Completer<void>();
      final wipe = SessionGeneration.wipe(() => releaseWipe.future);
      final requestOptions = _sentRequest('/api/users', headers: {'Authorization': 'Bearer old-jwt'});
      final error = DioException(
        requestOptions: requestOptions,
        response: Response(requestOptions: requestOptions, statusCode: 401),
      );
      final handler = _TestErrorHandler();

      await interceptor.onError(error, handler);
      releaseWipe.complete();
      await wipe;

      expect(handler.nextError, same(error), reason: 'the request fails with its 401');
      expect(secureStorage.refreshTokenReadCount, 0, reason: 'the refresh-token read is the proxy for a refresh');
      expect(sessionExpiredCalls, 0);
    });

    test('fails a 401 for a request without a session generation and spends no refresh token', () async {
      await secureStorage.write(SecureStorageKeys.refreshToken.key, 'valid-refresh-token');
      var sessionExpiredCalls = 0;
      final interceptor = TokenRefreshInterceptor(
        rotation: const _NoServerRotation(),
        dio: dio,
        secureStorage: secureStorage,
        onSessionExpired: () => sessionExpiredCalls++,
      );
      // Not sent through AuthInterceptor, so nothing shows which session it belongs to.
      final requestOptions = RequestOptions(path: '/api/users');
      final error = DioException(
        requestOptions: requestOptions,
        response: Response(requestOptions: requestOptions, statusCode: 401),
      );
      final handler = _TestErrorHandler();

      await interceptor.onError(error, handler);

      expect(handler.nextError, same(error), reason: 'the request fails with its 401');
      expect(secureStorage.refreshTokenReadCount, 0, reason: 'the refresh-token read is the proxy for a refresh');
      expect(sessionExpiredCalls, 0);
    });

    // Regression: the stale-header check ran first, so the 401 of a request that one user sent, arriving after that
    // user signed out and another signed in, sent the request again with the token of the user signed in now.
    test('does not send a request again with the token of a user who signed in after its session ended', () async {
      await secureStorage.write(SecureStorageKeys.jwtToken.key, 'user-a-jwt');
      await secureStorage.write(SecureStorageKeys.refreshToken.key, 'user-a-refresh');
      final retryStub = _CapturingSuccessStub();
      dio.interceptors.add(retryStub);
      var sessionExpiredCalls = 0;
      final interceptor = TokenRefreshInterceptor(
        rotation: const _NoServerRotation(),
        dio: dio,
        secureStorage: secureStorage,
        onSessionExpired: () => sessionExpiredCalls++,
      );
      final requestOptions = _sentRequest('/account', method: 'POST', headers: {'Authorization': 'Bearer user-a-jwt'});
      // User A signs out while the request is on its way, and user B signs in.
      await SessionGeneration.wipe(() async {
        await secureStorage.delete(SecureStorageKeys.jwtToken.key);
        await secureStorage.delete(SecureStorageKeys.refreshToken.key);
      });
      await secureStorage.write(SecureStorageKeys.jwtToken.key, 'user-b-jwt');
      await secureStorage.write(SecureStorageKeys.refreshToken.key, 'user-b-refresh');
      final error = DioException(
        requestOptions: requestOptions,
        response: Response(requestOptions: requestOptions, statusCode: 401),
      );
      final handler = _TestErrorHandler();

      await interceptor.onError(error, handler);

      expect(handler.nextError, same(error), reason: 'the request fails with its 401');
      expect(retryStub.lastAuthorization, isNull, reason: 'the action user A started must not run as user B');
      expect(secureStorage.refreshTokenReadCount, 0, reason: 'the refresh-token read is the proxy for a refresh');
      expect(sessionExpiredCalls, 0, reason: 'ending the session would sign out user B');
    });

    test('does not send a request without a session generation again with the token stored now', () async {
      await secureStorage.write(SecureStorageKeys.jwtToken.key, 'stored-jwt');
      await secureStorage.write(SecureStorageKeys.refreshToken.key, 'valid-refresh-token');
      final retryStub = _CapturingSuccessStub();
      dio.interceptors.add(retryStub);
      final interceptor = TokenRefreshInterceptor(
        rotation: const _NoServerRotation(),
        dio: dio,
        secureStorage: secureStorage,
      );
      // Not sent through AuthInterceptor, so nothing shows that the token stored now is of the session it was sent
      // under.
      final requestOptions = RequestOptions(path: '/api/users', headers: {'Authorization': 'Bearer sent-jwt'});
      final error = DioException(
        requestOptions: requestOptions,
        response: Response(requestOptions: requestOptions, statusCode: 401),
      );
      final handler = _TestErrorHandler();

      await interceptor.onError(error, handler);

      expect(handler.nextError, same(error), reason: 'the request fails with its 401');
      expect(retryStub.lastAuthorization, isNull);
    });

    test('does not end the session signed in since when a request sent again after a refresh gets 401 again', () async {
      var sessionExpiredCalls = 0;
      final interceptor = TokenRefreshInterceptor(
        rotation: const _NoServerRotation(),
        dio: dio,
        secureStorage: secureStorage,
        onSessionExpired: () => sessionExpiredCalls++,
      );
      final requestOptions = _sentRequest('/api/users', headers: {'Authorization': 'Bearer refreshed-jwt'});
      TokenRefreshInterceptor.debugMarkAsRetried(requestOptions);
      // The session ends while the request is sent again, and the user signs in again.
      await SessionGeneration.wipe(() async {});
      await secureStorage.write(SecureStorageKeys.jwtToken.key, 'signed-in-jwt');
      await secureStorage.write(SecureStorageKeys.refreshToken.key, 'signed-in-refresh');
      final error = DioException(
        requestOptions: requestOptions,
        response: Response(requestOptions: requestOptions, statusCode: 401),
      );
      final handler = _TestErrorHandler();

      await interceptor.onError(error, handler);

      expect(handler.nextError, same(error), reason: 'the request fails with its 401');
      expect(sessionExpiredCalls, 0, reason: 'ending the session would sign out the session signed in since');
    });
  });

  group('TokenRefreshInterceptor - session ended during the refresh', () {
    /// What the session wipe does: it deletes the stored tokens inside [SessionGeneration.wipe].
    Future<void> endSession(ISecureStorage storage) => SessionGeneration.wipe(() async {
      await storage.delete(SecureStorageKeys.jwtToken.key);
      await storage.delete(SecureStorageKeys.refreshToken.key);
    });

    DioException unauthorized() {
      final requestOptions = _sentRequest('/api/users', headers: {'Authorization': 'Bearer old-jwt'});
      return DioException(
        requestOptions: requestOptions,
        response: Response(requestOptions: requestOptions, statusCode: 401),
      );
    }

    test('drops the rotated tokens and fails the request when the session ends before the refresh answers', () async {
      final storage = _InterleavingSecureStorage();
      await storage.write(SecureStorageKeys.jwtToken.key, 'old-jwt');
      await storage.write(SecureStorageKeys.refreshToken.key, 'valid-refresh');
      final retryStub = _CapturingSuccessStub();
      dio.interceptors.add(retryStub);
      var sessionExpiredCalls = 0;
      final interceptor = TokenRefreshInterceptor(
        dio: dio,
        secureStorage: storage,
        onSessionExpired: () => sessionExpiredCalls++,
        rotation: _DioRotation(
          (source) => Dio(BaseOptions(baseUrl: source.options.baseUrl))
            ..interceptors.add(
              _RefreshInFlightStub(
                body: '{"id_token":"new-jwt","refresh_token":"new-refresh"}',
                whileInFlight: () => endSession(storage),
              ),
            ),
        ),
      );
      final error = unauthorized();
      final handler = _TestErrorHandler();

      await interceptor.onError(error, handler);

      expect(handler.nextError, same(error), reason: 'the request fails with its 401');
      expect(handler.resolveCalled, isFalse);
      expect(retryStub.lastAuthorization, isNull, reason: 'the request is not sent again with the dropped token');
      // Never stored, not even for a moment: an app closed right then would keep them.
      expect(storage.writes, ['jwtToken=old-jwt', 'refreshToken=valid-refresh']);
      expect(await storage.read(SecureStorageKeys.jwtToken.key), isNull);
      expect(await storage.read(SecureStorageKeys.refreshToken.key), isNull);
      // The session already ended, and a new one may have started since: ending it again would sign that one out.
      expect(sessionExpiredCalls, 0);
    });

    test('takes back the rotated tokens when the session ends while they are being stored', () async {
      final storage = _InterleavingSecureStorage();
      await storage.write(SecureStorageKeys.jwtToken.key, 'old-jwt');
      await storage.write(SecureStorageKeys.refreshToken.key, 'valid-refresh');
      // The wipe runs while the rotated JWT is being written, so the rotated refresh token lands after it.
      storage.onWrite = (key) async {
        if (key == SecureStorageKeys.jwtToken.key) await endSession(storage);
      };
      final retryStub = _CapturingSuccessStub();
      dio.interceptors.add(retryStub);
      var sessionExpiredCalls = 0;
      final interceptor = TokenRefreshInterceptor(
        dio: dio,
        secureStorage: storage,
        onSessionExpired: () => sessionExpiredCalls++,
        rotation: _DioRotation(
          (source) => Dio(BaseOptions(baseUrl: source.options.baseUrl))
            ..interceptors.add(
              _StubInterceptor()..stubSuccess(data: '{"id_token":"new-jwt","refresh_token":"new-refresh"}'),
            ),
        ),
      );
      final error = unauthorized();
      final handler = _TestErrorHandler();

      await interceptor.onError(error, handler);

      expect(handler.nextError, same(error), reason: 'the request fails with its 401');
      expect(retryStub.lastAuthorization, isNull);
      expect(await storage.read(SecureStorageKeys.jwtToken.key), isNull);
      expect(await storage.read(SecureStorageKeys.refreshToken.key), isNull);
      expect(sessionExpiredCalls, 0);
    });

    test('ends the session when the rotated tokens cannot be taken back', () async {
      final storage = _InterleavingSecureStorage();
      await storage.write(SecureStorageKeys.jwtToken.key, 'old-jwt');
      await storage.write(SecureStorageKeys.refreshToken.key, 'valid-refresh');
      storage.onWrite = (key) async {
        if (key != SecureStorageKeys.jwtToken.key) return;
        await endSession(storage);
        storage.failDeletes = true;
      };
      dio.interceptors.add(_CapturingSuccessStub());
      var sessionExpiredCalls = 0;
      final interceptor = TokenRefreshInterceptor(
        dio: dio,
        secureStorage: storage,
        onSessionExpired: () => sessionExpiredCalls++,
        rotation: _DioRotation(
          (source) => Dio(BaseOptions(baseUrl: source.options.baseUrl))
            ..interceptors.add(
              _StubInterceptor()..stubSuccess(data: '{"id_token":"new-jwt","refresh_token":"new-refresh"}'),
            ),
        ),
      );
      final error = unauthorized();
      final handler = _TestErrorHandler();

      await interceptor.onError(error, handler);

      // The rotated refresh token is still stored, so the session is ended again, which wipes it.
      expect(await storage.read(SecureStorageKeys.refreshToken.key), 'new-refresh');
      expect(sessionExpiredCalls, 1);
      expect(handler.nextError, same(error));
    });

    test('leaves the tokens of a session stored after the end alone', () async {
      final storage = _InterleavingSecureStorage();
      await storage.write(SecureStorageKeys.jwtToken.key, 'old-jwt');
      await storage.write(SecureStorageKeys.refreshToken.key, 'valid-refresh');
      // The session ends while the rotated JWT is being written, and the user signs in again before the refresh
      // token is written.
      storage.onWrite = (key) async {
        if (key != SecureStorageKeys.jwtToken.key) return;
        await endSession(storage);
        await storage.write(SecureStorageKeys.jwtToken.key, 'signed-in-jwt');
        await storage.write(SecureStorageKeys.refreshToken.key, 'signed-in-refresh');
      };
      dio.interceptors.add(_CapturingSuccessStub());
      final interceptor = TokenRefreshInterceptor(
        dio: dio,
        secureStorage: storage,
        rotation: _DioRotation(
          (source) =>
              Dio(BaseOptions(baseUrl: source.options.baseUrl))
                ..interceptors.add(_StubInterceptor()..stubSuccess(data: '{"id_token":"new-jwt"}')),
        ),
      );

      await interceptor.onError(unauthorized(), _TestErrorHandler());

      expect(await storage.read(SecureStorageKeys.jwtToken.key), 'signed-in-jwt');
      expect(await storage.read(SecureStorageKeys.refreshToken.key), 'signed-in-refresh');
    });

    // Regression: a refresh that failed after the session ended still ended the session, which wiped the session the
    // user had signed in to while the refresh was on its way.
    test('does not end the session signed in after the end when the refresh then fails', () async {
      final storage = _InterleavingSecureStorage();
      await storage.write(SecureStorageKeys.jwtToken.key, 'old-jwt');
      await storage.write(SecureStorageKeys.refreshToken.key, 'valid-refresh');
      var sessionExpiredCalls = 0;
      final interceptor = TokenRefreshInterceptor(
        dio: dio,
        secureStorage: storage,
        onSessionExpired: () => sessionExpiredCalls++,
        rotation: _DioRotation(
          (source) => Dio(BaseOptions(baseUrl: source.options.baseUrl))
            ..interceptors.add(
              _RefreshInFlightStub(
                statusCode: 401,
                whileInFlight: () async {
                  await endSession(storage);
                  await storage.write(SecureStorageKeys.jwtToken.key, 'signed-in-jwt');
                  await storage.write(SecureStorageKeys.refreshToken.key, 'signed-in-refresh');
                },
              ),
            ),
        ),
      );
      final error = unauthorized();
      final handler = _TestErrorHandler();

      await interceptor.onError(error, handler);

      expect(sessionExpiredCalls, 0, reason: 'ending the session would wipe the session signed in to since');
      expect(handler.nextError, same(error), reason: 'the request fails with its 401');
      expect(await storage.read(SecureStorageKeys.jwtToken.key), 'signed-in-jwt');
      expect(await storage.read(SecureStorageKeys.refreshToken.key), 'signed-in-refresh');
    });
  });

  // The startup step refreshes through the same rotation and goes on after its time limit, so the
  // stored session can be rotated or cleared while this refresh is on its way. The refresh reads the stored refresh
  // token again before it acts on the answer.
  group('TokenRefreshInterceptor - the stored session changes during the refresh', () {
    late _CapturingSuccessStub retryStub;
    late int sessionExpiredCalls;

    setUp(() async {
      await secureStorage.write(SecureStorageKeys.jwtToken.key, 'old-jwt');
      await secureStorage.write(SecureStorageKeys.refreshToken.key, 'valid-refresh');
      retryStub = _CapturingSuccessStub();
      dio.interceptors.add(retryStub);
      sessionExpiredCalls = 0;
    });

    DioException unauthorized() {
      final requestOptions = _sentRequest('/api/users', headers: {'Authorization': 'Bearer old-jwt'});
      return DioException(
        requestOptions: requestOptions,
        response: Response(requestOptions: requestOptions, statusCode: 401),
      );
    }

    /// The interceptor whose refresh request is answered with [statusCode] and [body] once [whileInFlight] has run.
    TokenRefreshInterceptor interceptor({
      required Future<void> Function() whileInFlight,
      int statusCode = 200,
      String body = '{"id_token":"new-jwt","refresh_token":"new-refresh"}',
    }) => TokenRefreshInterceptor(
      dio: dio,
      secureStorage: secureStorage,
      onSessionExpired: () => sessionExpiredCalls++,
      rotation: _DioRotation(
        (source) => Dio(BaseOptions(baseUrl: source.options.baseUrl))
          ..interceptors.add(_RefreshInFlightStub(statusCode: statusCode, body: body, whileInFlight: whileInFlight)),
      ),
    );

    /// Another refresh rotates the stored session: it stores the JWT, then the refresh token.
    Future<void> rotateElsewhere() async {
      await secureStorage.write(SecureStorageKeys.jwtToken.key, 'jwt-of-other-refresh');
      await secureStorage.write(SecureStorageKeys.refreshToken.key, 'refresh-of-other-refresh');
    }

    /// The stored session is cleared outside this refresh's session generation: the JWT, then the refresh token.
    Future<void> clearElsewhere() async {
      await secureStorage.delete(SecureStorageKeys.jwtToken.key);
      await secureStorage.delete(SecureStorageKeys.refreshToken.key);
    }

    test('drops the rotated tokens when the stored session is cleared while the refresh is on its way', () async {
      final error = unauthorized();
      final handler = _TestErrorHandler();

      await interceptor(whileInFlight: clearElsewhere).onError(error, handler);

      expect(secureStorage._store, isEmpty, reason: 'the cleared session stays cleared');
      expect(handler.nextError, same(error), reason: 'the request fails with its 401');
      expect(retryStub.lastAuthorization, isNull);
      expect(sessionExpiredCalls, 0, reason: 'what is stored now is not the session this refresh was for');
    });

    test('does not end the session when the stored session is cleared while a failing refresh is on its way', () async {
      final error = unauthorized();
      final handler = _TestErrorHandler();

      await interceptor(statusCode: 503, body: '', whileInFlight: clearElsewhere).onError(error, handler);

      // A session the user signs in to next may hold no refresh token, so ending the session here could wipe it.
      expect(sessionExpiredCalls, 0, reason: 'what is stored now is not the session this refresh was for');
      expect(handler.nextError, same(error), reason: 'the request fails with its 401');
      expect(secureStorage._store, isEmpty);
    });

    test('keeps the tokens another refresh rotated while this one was on its way and retries with them', () async {
      final handler = _TestErrorHandler();

      await interceptor(whileInFlight: rotateElsewhere).onError(unauthorized(), handler);

      expect(secureStorage._store, {
        SecureStorageKeys.jwtToken.key: 'jwt-of-other-refresh',
        SecureStorageKeys.refreshToken.key: 'refresh-of-other-refresh',
      });
      expect(handler.resolveCalled, isTrue);
      expect(retryStub.lastAuthorization, 'Bearer jwt-of-other-refresh');
      expect(sessionExpiredCalls, 0);
    });

    test('keeps the session another refresh rotated when the server refuses the refresh token it replaced', () async {
      // A server that accepts a refresh token once refuses the second refresh that sends it.
      final handler = _TestErrorHandler();

      await interceptor(statusCode: 401, body: '', whileInFlight: rotateElsewhere).onError(unauthorized(), handler);

      expect(sessionExpiredCalls, 0, reason: 'ending the session would undo the refresh that rotated it');
      expect(handler.resolveCalled, isTrue);
      expect(retryStub.lastAuthorization, 'Bearer jwt-of-other-refresh');
      expect(secureStorage._store, {
        SecureStorageKeys.jwtToken.key: 'jwt-of-other-refresh',
        SecureStorageKeys.refreshToken.key: 'refresh-of-other-refresh',
      });
    });

    test('drops the answer when the session another refresh rotated is being cleared', () async {
      final error = unauthorized();
      final handler = _TestErrorHandler();

      await interceptor(
        whileInFlight: () async {
          await rotateElsewhere();
          // The clear has deleted the JWT but not yet the refresh token.
          await secureStorage.delete(SecureStorageKeys.jwtToken.key);
        },
      ).onError(error, handler);

      expect(secureStorage._store, {SecureStorageKeys.refreshToken.key: 'refresh-of-other-refresh'});
      expect(handler.nextError, same(error), reason: 'the request fails with its 401');
      expect(retryStub.lastAuthorization, isNull);
      expect(sessionExpiredCalls, 0);
    });

    test('still ends the session when the refresh fails and nothing else changed it', () async {
      final error = unauthorized();
      final handler = _TestErrorHandler();

      await interceptor(statusCode: 401, body: '', whileInFlight: () async {}).onError(error, handler);

      expect(sessionExpiredCalls, 1);
      expect(handler.nextError, same(error));
    });
  });

  group('TokenRefreshInterceptor - with a rotation strategy', () {
    final expiresAt = DateTime.utc(2026, 10, 21, 12, 30);
    final priorExpiresAt = DateTime.utc(2026, 10, 21, 12);
    late _KeyRecordingSecureStorage storage;
    late _CapturingSuccessStub retryStub;
    late int sessionExpiredCalls;

    setUp(() async {
      storage = _KeyRecordingSecureStorage();
      await storage.write(SecureStorageKeys.jwtToken.key, 'old-access');
      await storage.write(SecureStorageKeys.refreshToken.key, 'valid-refresh');
      storage.writes.clear();
      storage.touched.clear();
      retryStub = _CapturingSuccessStub();
      sessionExpiredCalls = 0;
    });

    /// Seeds the OIDC ID token and the expiry of the session that is stored before the refresh.
    Future<void> seedOidcKeys() async {
      await storage.write(SecureStorageKeys.oidcIdToken.key, 'prior-id');
      await storage.write(SecureStorageKeys.accessTokenExpiresAt.key, encodeAccessTokenExpiry(priorExpiresAt));
      storage.writes.clear();
      storage.touched.clear();
    }

    TokenRefreshInterceptor interceptorWith(TokenRotation rotation) => TokenRefreshInterceptor(
      dio: dio,
      secureStorage: storage,
      onSessionExpired: () => sessionExpiredCalls++,
      rotation: rotation,
    );

    DioException unauthorized([String path = '/api/users']) {
      final requestOptions = _sentRequest(path, headers: {'Authorization': 'Bearer old-access'});
      return DioException(
        requestOptions: requestOptions,
        response: Response(requestOptions: requestOptions, statusCode: 401),
      );
    }

    /// What the wipe of a session does: it deletes every stored key inside [SessionGeneration.wipe].
    Future<void> endSession() => SessionGeneration.wipe(() async {
      for (final key in SecureStorageKeys.values) {
        await storage.delete(key.key);
      }
    });

    final rotatedWithOidcKeys = TokensRotated(
      accessToken: 'new-access',
      refreshToken: 'new-refresh',
      oidcIdToken: 'new-id',
      accessTokenExpiresAt: expiresAt,
    );

    test('TokensRotated with an ID token and an expiry stores all four keys, then retries', () async {
      dio.interceptors.add(retryStub);
      final rotation = _FakeRotation(rotatedWithOidcKeys);
      final handler = _TestErrorHandler();

      await interceptorWith(rotation).onError(unauthorized(), handler);

      expect(rotation.sent, ['valid-refresh']);
      expect(storage.writes, [
        'jwtToken=new-access',
        'refreshToken=new-refresh',
        'oidcIdToken=new-id',
        'accessTokenExpiresAt=${encodeAccessTokenExpiry(expiresAt)}',
      ], reason: 'the bearer, the refresh token, the ID token and the expiry, in this order');
      expect(handler.resolveCalled, isTrue);
      expect(retryStub.lastAuthorization, 'Bearer new-access');
      expect(sessionExpiredCalls, 0);
    });

    test('RotationRefused ends the session once and fails the request with its 401', () async {
      final rotation = _FakeRotation(const RotationRefused());
      final error = unauthorized();
      final handler = _TestErrorHandler();

      await interceptorWith(rotation).onError(error, handler);

      expect(rotation.sent, hasLength(1));
      expect(sessionExpiredCalls, 1);
      expect(handler.nextError, same(error));
      expect(await storage.read(SecureStorageKeys.jwtToken.key), 'old-access');
    });

    test('RotationUnavailable keeps the session and fails the request as a network error', () async {
      final rotation = _FakeRotation(const RotationUnavailable());
      final server = _UnauthorizedServerStub();
      dio.interceptors.addAll([AuthInterceptor(secureStorage: storage), interceptorWith(rotation), server]);

      await expectLater(
        dio.get<String>('/api/users').timeout(const Duration(seconds: 5)),
        throwsA(
          isA<DioException>()
              .having((e) => e.type, 'type', DioExceptionType.connectionError)
              .having((e) => e.message, 'message', 'The identity provider could not be reached'),
        ),
      );

      expect(sessionExpiredCalls, 0);
      expect(rotation.sent, hasLength(1));
      expect(server.authorizations, ['Bearer old-access'], reason: 'the request is not sent again');
      expect(await storage.read(SecureStorageKeys.jwtToken.key), 'old-access');
      expect(await storage.read(SecureStorageKeys.refreshToken.key), 'valid-refresh');
    });

    // The network error would otherwise reach ResilienceInterceptor, which sends a GET again: its 401 would start
    // another rotation, against a provider that has just not answered.
    test('RotationUnavailable for a GET is not retried by ResilienceInterceptor', () async {
      addTearDown(ResilienceInterceptor.instance.resetAll);
      final rotation = _FakeRotation(const RotationUnavailable());
      final server = _UnauthorizedServerStub();
      dio.interceptors.addAll([
        AuthInterceptor(secureStorage: storage),
        interceptorWith(rotation),
        ResilienceInterceptor.instance.forDio(dio),
        server,
      ]);

      await expectLater(
        dio.get<String>('/api/users').timeout(const Duration(seconds: 10)),
        throwsA(isA<DioException>().having((e) => e.type, 'type', DioExceptionType.connectionError)),
      );

      expect(rotation.sent, hasLength(1));
      expect(server.authorizations, hasLength(1));
      expect(sessionExpiredCalls, 0);
    });

    test('a failed write of the expiry restores the prior bearer, refresh token, ID token and expiry', () async {
      await seedOidcKeys();
      storage.failWriteOf = SecureStorageKeys.accessTokenExpiresAt.key;
      dio.interceptors.add(retryStub);
      final error = unauthorized();
      final handler = _TestErrorHandler();

      await interceptorWith(_FakeRotation(rotatedWithOidcKeys)).onError(error, handler);

      expect(await storage.read(SecureStorageKeys.jwtToken.key), 'old-access');
      expect(await storage.read(SecureStorageKeys.refreshToken.key), 'valid-refresh');
      expect(await storage.read(SecureStorageKeys.oidcIdToken.key), 'prior-id');
      expect(await storage.read(SecureStorageKeys.accessTokenExpiresAt.key), encodeAccessTokenExpiry(priorExpiresAt));
      expect(sessionExpiredCalls, 1);
      expect(handler.nextError, same(error));
      expect(retryStub.lastAuthorization, isNull);
    });

    test('a session ended while the rotated tokens are stored takes back the ID token and the expiry', () async {
      await seedOidcKeys();
      // The wipe runs while the rotated bearer is being written, so the rest of the rotated tokens land after it.
      storage.onWrite = (key) async {
        if (key == SecureStorageKeys.jwtToken.key) await endSession();
      };
      dio.interceptors.add(retryStub);
      final error = unauthorized();
      final handler = _TestErrorHandler();

      await interceptorWith(_FakeRotation(rotatedWithOidcKeys)).onError(error, handler);

      expect(storage.writes, contains('oidcIdToken=new-id'), reason: 'the ID token landed after the wipe');
      expect(storage.writes, contains('accessTokenExpiresAt=${encodeAccessTokenExpiry(expiresAt)}'));
      for (final key in SecureStorageKeys.values) {
        expect(await storage.read(key.key), isNull, reason: '${key.key} must be taken back');
      }
      expect(sessionExpiredCalls, 0);
      expect(handler.nextError, same(error));
      expect(retryStub.lastAuthorization, isNull);
    });

    test('TokensRotated without an ID token or an expiry touches only the bearer and the refresh token', () async {
      dio.interceptors.add(retryStub);

      await interceptorWith(_FakeRotation(const TokensRotated(accessToken: 'new-access', refreshToken: 'new-refresh')))
          .onError(unauthorized(), _TestErrorHandler());

      expect(storage.writes, ['jwtToken=new-access', 'refreshToken=new-refresh']);
      expect(storage.touched, {SecureStorageKeys.jwtToken.key, SecureStorageKeys.refreshToken.key});
    });

    test('TokensRotated without an ID token or an expiry rolls back only the bearer and the refresh token', () async {
      storage.failWriteOf = SecureStorageKeys.refreshToken.key;

      await interceptorWith(_FakeRotation(const TokensRotated(accessToken: 'new-access', refreshToken: 'new-refresh')))
          .onError(unauthorized(), _TestErrorHandler());

      expect(await storage.read(SecureStorageKeys.jwtToken.key), 'old-access');
      expect(sessionExpiredCalls, 1);
      expect(storage.touched, {SecureStorageKeys.jwtToken.key, SecureStorageKeys.refreshToken.key});
    });

    test('TokensRotated without an ID token or an expiry takes back only the bearer and the refresh token', () async {
      storage.onWrite = (key) async {
        if (key != SecureStorageKeys.jwtToken.key) return;
        await SessionGeneration.wipe(() async {
          await storage.delete(SecureStorageKeys.jwtToken.key);
          await storage.delete(SecureStorageKeys.refreshToken.key);
        });
      };

      await interceptorWith(_FakeRotation(const TokensRotated(accessToken: 'new-access', refreshToken: 'new-refresh')))
          .onError(unauthorized(), _TestErrorHandler());

      expect(await storage.read(SecureStorageKeys.jwtToken.key), isNull);
      expect(await storage.read(SecureStorageKeys.refreshToken.key), isNull);
      expect(storage.touched, {SecureStorageKeys.jwtToken.key, SecureStorageKeys.refreshToken.key});
    });

    test('two concurrent 401s share one rotation', () async {
      dio.interceptors.add(retryStub);
      final release = Completer<void>();
      final rotation = _FakeRotation(rotatedWithOidcKeys, whileRotating: () => release.future);
      final interceptor = interceptorWith(rotation);
      final first = _TestErrorHandler();
      final second = _TestErrorHandler();

      final both = Future.wait([
        interceptor.onError(unauthorized('/api/users'), first),
        interceptor.onError(unauthorized('/api/authorities'), second),
      ]);
      await pumpEventQueue();
      release.complete();
      await both;

      expect(rotation.sent, hasLength(1));
      expect(first.resolveCalled, isTrue);
      expect(second.resolveCalled, isTrue);
    });

    test('with no stored refresh token a 401 ends the session and never calls rotate', () async {
      await storage.delete(SecureStorageKeys.refreshToken.key);
      final rotation = _FakeRotation(rotatedWithOidcKeys);
      final error = unauthorized();
      final handler = _TestErrorHandler();

      await interceptorWith(rotation).onError(error, handler);

      expect(rotation.sent, isEmpty);
      expect(sessionExpiredCalls, 1);
      expect(handler.nextError, same(error));
    });
  });

  // A backend such as LibreDB Studio also answers 401 when a database or a model refuses its own credentials. Only its
  // AUTH_REQUIRED code means the bearer is no longer valid, so the app narrows the predicate to it.
  group('TokenRefreshInterceptor - with a narrowed 401 predicate', () {
    bool authRequired(DioException error) {
      final body = error.response?.data;
      if (error.response?.statusCode != 401 || body is! String || body.isEmpty) return false;
      final decoded = jsonDecode(body);
      return decoded is Map<String, dynamic> && decoded['code'] == 'AUTH_REQUIRED';
    }

    late _FakeRotation rotation;
    late int sessionExpiredCalls;
    late TokenRefreshInterceptor interceptor;

    setUp(() async {
      await secureStorage.write(SecureStorageKeys.jwtToken.key, 'old-access');
      await secureStorage.write(SecureStorageKeys.refreshToken.key, 'valid-refresh');
      dio.interceptors.add(_CapturingSuccessStub());
      rotation = _FakeRotation(const TokensRotated(accessToken: 'new-access'));
      sessionExpiredCalls = 0;
      interceptor = TokenRefreshInterceptor(
        dio: dio,
        secureStorage: secureStorage,
        onSessionExpired: () => sessionExpiredCalls++,
        rotation: rotation,
        isSessionExpired: authRequired,
      );
    });

    DioException unauthorizedWith(String body) {
      final requestOptions = _sentRequest('/api/db/query', headers: {'Authorization': 'Bearer old-access'});
      return DioException(
        requestOptions: requestOptions,
        response: Response(requestOptions: requestOptions, statusCode: 401, data: body),
      );
    }

    test('passes a 401 the predicate refuses on with no rotation and no end of the session', () async {
      final error = unauthorizedWith('{"code":"AUTH_ERROR"}');
      final handler = _TestErrorHandler();

      await interceptor.onError(error, handler);

      expect(handler.nextError, same(error));
      expect(rotation.sent, isEmpty);
      expect(secureStorage.refreshTokenReadCount, 0, reason: 'the refresh-token read is the proxy for a refresh');
      expect(sessionExpiredCalls, 0);
    });

    test('still refreshes a 401 the predicate accepts', () async {
      final handler = _TestErrorHandler();

      await interceptor.onError(unauthorizedWith('{"code":"AUTH_REQUIRED"}'), handler);

      expect(rotation.sent, ['valid-refresh']);
      expect(handler.resolveCalled, isTrue);
      expect(sessionExpiredCalls, 0);
    });
  });
  // GET /api/auth/me answers 401 without a code both for a refused token and when Studio cannot reach Keycloak. After
  // a refresh at Keycloak succeeded, only a refusal predicate's 401 ends the session; any other 401 reaches the caller.
  group('TokenRefreshInterceptor - a 401 again after a refresh', () {
    late int sessionExpiredCalls;

    setUp(() async {
      await secureStorage.write(SecureStorageKeys.jwtToken.key, 'old-access');
      await secureStorage.write(SecureStorageKeys.refreshToken.key, 'valid-refresh');
      sessionExpiredCalls = 0;
    });

    /// A client with Studio's 401 rules whose server answers every request with 401 and [body].
    ({_UnauthorizedServerStub server, _FakeRotation rotation}) studioClient(
      String body, {
      TokenRotationResult rotated = const TokensRotated(accessToken: 'new-access'),
      Future<void> Function()? beforeFirstAnswer,
      OnSessionRefused? onSessionRefused,
    }) {
      final server = _UnauthorizedServerStub(body, beforeFirstAnswer);
      final rotation = _FakeRotation(rotated);
      dio.interceptors.addAll([
        AuthInterceptor(secureStorage: secureStorage),
        TokenRefreshInterceptor(
          dio: dio,
          secureStorage: secureStorage,
          onSessionExpired: () => sessionExpiredCalls++,
          onSessionRefused: onSessionRefused,
          rotation: rotation,
          isSessionExpired: isStudioSessionExpired,
          isSessionRefused: isStudioSessionRefused,
        ),
        server,
      ]);
      return (server: server, rotation: rotation);
    }

    Future<void> expectUnauthorized(String path) => expectLater(
      dio.get<String>(path).timeout(const Duration(seconds: 5)),
      throwsA(isA<DioException>().having((e) => e.response?.statusCode, 'statusCode', 401)),
    );

    test('keeps the session and passes the 401 on when the retry gets 401 without a code again', () async {
      final (:server, :rotation) = studioClient('{"authenticated":false}');

      await expectUnauthorized('/auth/me');

      expect(rotation.sent, ['valid-refresh'], reason: 'exactly one refresh');
      expect(server.authorizations, ['Bearer old-access', 'Bearer new-access']);
      expect(sessionExpiredCalls, 0);
      expect(await secureStorage.read(SecureStorageKeys.jwtToken.key), 'new-access');
      expect(await secureStorage.read(SecureStorageKeys.refreshToken.key), 'valid-refresh');
    });

    test('ends the session when the retry gets 401 AUTH_REQUIRED again', () async {
      final (:server, :rotation) = studioClient('{"error":"Invalid access token","code":"AUTH_REQUIRED"}');

      await expectUnauthorized('/connections/managed');

      expect(rotation.sent, ['valid-refresh'], reason: 'exactly one refresh');
      expect(server.authorizations, ['Bearer old-access', 'Bearer new-access']);
      expect(sessionExpiredCalls, 1);
    });

    // The refusal of a token just issued is the one server's answer, so the app decides per session target whether it
    // ends the session; a refresh token the identity provider refused is dead for every server.
    test('tells onSessionRefused, not onSessionExpired, when the retry gets 401 AUTH_REQUIRED again', () async {
      var sessionRefusedCalls = 0;
      studioClient(
        '{"error":"Invalid access token","code":"AUTH_REQUIRED"}',
        onSessionRefused: () => sessionRefusedCalls++,
      );

      await expectUnauthorized('/connections/managed');

      expect(sessionRefusedCalls, 1);
      expect(sessionExpiredCalls, 0);
    });

    test('tells onSessionExpired, not onSessionRefused, when the refresh fails at the identity provider', () async {
      var sessionRefusedCalls = 0;
      studioClient(
        '{"authenticated":false}',
        rotated: const RotationRefused(),
        onSessionRefused: () => sessionRefusedCalls++,
      );

      await expectUnauthorized('/auth/me');

      expect(sessionRefusedCalls, 0);
      expect(sessionExpiredCalls, 1);
    });

    test('ends the session when the refresh fails at the identity provider', () async {
      final (:server, :rotation) = studioClient('{"authenticated":false}', rotated: const RotationRefused());

      await expectUnauthorized('/auth/me');

      expect(rotation.sent, ['valid-refresh']);
      expect(server.authorizations, ['Bearer old-access'], reason: 'nothing to send the request again with');
      expect(sessionExpiredCalls, 1);
    });

    // Another request rotated the token while this one was on its way, so it is sent again with the stored token and
    // without a refresh of its own; a second 401 there follows the same rule.
    Future<void> rotateWhileInFlight() => secureStorage.write(SecureStorageKeys.jwtToken.key, 'new-access');

    test('keeps the session when the retry with a token rotated meanwhile gets 401 without a code again', () async {
      final (:server, :rotation) = studioClient('{"authenticated":false}', beforeFirstAnswer: rotateWhileInFlight);

      await expectUnauthorized('/auth/me');

      expect(rotation.sent, isEmpty, reason: 'the stored token was already rotated');
      expect(server.authorizations, ['Bearer old-access', 'Bearer new-access']);
      expect(sessionExpiredCalls, 0);
      expect(await secureStorage.read(SecureStorageKeys.jwtToken.key), 'new-access');
    });

    test('ends the session when the retry with a token rotated meanwhile gets 401 AUTH_REQUIRED again', () async {
      final (:server, :rotation) = studioClient(
        '{"error":"Invalid access token","code":"AUTH_REQUIRED"}',
        beforeFirstAnswer: rotateWhileInFlight,
      );

      await expectUnauthorized('/connections/managed');

      expect(rotation.sent, isEmpty, reason: 'the stored token was already rotated');
      expect(server.authorizations, ['Bearer old-access', 'Bearer new-access']);
      expect(sessionExpiredCalls, 1);
    });

    test('ends the session on any 401 after a refresh by default', () async {
      final server = _UnauthorizedServerStub('{"authenticated":false}');
      dio.interceptors.addAll([
        AuthInterceptor(secureStorage: secureStorage),
        TokenRefreshInterceptor(
          dio: dio,
          secureStorage: secureStorage,
          onSessionExpired: () => sessionExpiredCalls++,
          rotation: _FakeRotation(const TokensRotated(accessToken: 'new-access')),
        ),
        server,
      ]);

      await expectUnauthorized('/auth/me');

      expect(server.authorizations, ['Bearer old-access', 'Bearer new-access']);
      expect(sessionExpiredCalls, 1);
    });
  });
  // From libredb-studio#1922 on, Studio refuses a verified token whose account it does not accept with 403
  // BEARER_NO_ROLE or BEARER_NO_IDENTITY, and answers 503 IDENTITY_PROVIDER_UNAVAILABLE when it cannot reach the
  // identity provider to check a token (src/proxy.ts). A new token is refused the same way and an outage is not the
  // token's fault, so none of them starts a refresh, ends the session or touches the stored tokens.
  group('TokenRefreshInterceptor - Studio refuses the account or cannot reach the identity provider', () {
    late int sessionExpiredCalls;

    setUp(() async {
      await secureStorage.write(SecureStorageKeys.jwtToken.key, 'old-access');
      await secureStorage.write(SecureStorageKeys.refreshToken.key, 'valid-refresh');
      sessionExpiredCalls = 0;
    });

    const answers = [
      (403, '{"error":"This account has no role in Studio. Ask an administrator for access.","code":"BEARER_NO_ROLE"}'),
      (403, '{"error":"The access token carries no user name Studio can use.","code":"BEARER_NO_IDENTITY"}'),
      (
        503,
        '{"error":"The identity provider could not be reached to verify the access token. Try again.",'
            '"code":"IDENTITY_PROVIDER_UNAVAILABLE"}',
      ),
    ];

    for (final (status, body) in answers) {
      for (final path in ['/auth/me', '/connections/managed']) {
        test('passes $status ${jsonDecode(body)['code']} on $path with no refresh and no end of the session', () async {
          final server = _UnauthorizedServerStub(body, null, status);
          final rotation = _FakeRotation(const TokensRotated(accessToken: 'new-access'));
          dio.interceptors.addAll([
            AuthInterceptor(secureStorage: secureStorage),
            TokenRefreshInterceptor(
              dio: dio,
              secureStorage: secureStorage,
              onSessionExpired: () => sessionExpiredCalls++,
              rotation: rotation,
              isSessionExpired: isStudioSessionExpired,
              isSessionRefused: isStudioSessionRefused,
            ),
            server,
          ]);

          await expectLater(
            dio.get<String>(path).timeout(const Duration(seconds: 5)),
            throwsA(isA<DioException>().having((e) => e.response?.statusCode, 'statusCode', status)),
          );

          expect(rotation.sent, isEmpty, reason: 'no refresh');
          expect(server.authorizations, ['Bearer old-access'], reason: 'sent once, never again');
          expect(secureStorage.refreshTokenReadCount, 0, reason: 'the refresh-token read is the proxy for a refresh');
          expect(sessionExpiredCalls, 0);
          expect(await secureStorage.read(SecureStorageKeys.jwtToken.key), 'old-access');
          expect(await secureStorage.read(SecureStorageKeys.refreshToken.key), 'valid-refresh');
        });
      }
    }
  });
}

/// In-memory ISecureStorage that records its writes as `key=value` and runs [onWrite], once, after it applies a write
/// and before the write completes, as a call that runs while the write is still on its way does. With [failDeletes]
/// set, its deletes throw.
class _InterleavingSecureStorage extends _MemorySecureStorage {
  Future<void> Function(String key)? onWrite;
  final writes = <String>[];

  /// When true, every delete throws, as a store that fails does.
  bool failDeletes = false;

  @override
  Future<void> delete(String key) async {
    if (failDeletes) throw StateError('boom on delete $key');
    await super.delete(key);
  }

  @override
  Future<void> write(String key, String value) async {
    writes.add('$key=$value');
    await super.write(key, value);
    final hook = onWrite;
    onWrite = null;
    if (hook != null) await hook(key);
  }
}

/// Answers the refresh request with [statusCode] and [body] once [whileInFlight] has run, which stands for what the app
/// does while the refresh request is on its way. A status other than 200 is rejected, as the server's error response.
class _RefreshInFlightStub extends Interceptor {
  _RefreshInFlightStub({this.body = '', this.statusCode = 200, required this.whileInFlight});

  final String body;
  final int statusCode;
  final Future<void> Function() whileInFlight;

  @override
  Future<void> onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    await whileInFlight();
    final response = Response(requestOptions: options, statusCode: statusCode, data: body);
    if (statusCode == 200) {
      handler.resolve(response);
      return;
    }
    handler.reject(DioException(requestOptions: options, type: DioExceptionType.badResponse, response: response));
  }
}

/// ISecureStorage that lets the jwtToken write succeed but throws on
/// the refresh_token write — used to exercise the rollback path in
/// `_performRefresh`. Read/delete behave normally so the rollback can
/// actually restore values.
class _RefreshWriteFailsSecureStorage implements ISecureStorage {
  final Map<String, String> _store = {};
  bool _jwtWriteSeen = false;

  Future<void> seed({required String jwt, required String refresh}) async {
    _store[SecureStorageKeys.jwtToken.key] = jwt;
    _store[SecureStorageKeys.refreshToken.key] = refresh;
  }

  @override
  Future<String?> read(String key) async => _store[key];

  @override
  Future<void> write(String key, String value) async {
    if (key == SecureStorageKeys.jwtToken.key) {
      _jwtWriteSeen = true;
      _store[key] = value;
      return;
    }
    if (key == SecureStorageKeys.refreshToken.key && _jwtWriteSeen) {
      throw StateError('refresh_token write torn after id_token landed');
    }
    _store[key] = value;
  }

  @override
  Future<void> delete(String key) async => _store.remove(key);

  @override
  Future<void> deleteAll() async => _store.clear();

  @override
  Future<Set<String>> keys() => throw UnimplementedError('not used by this test');
}

/// Captures the Authorization header and the loop-prevention marker on
/// any incoming request, then resolves it with 200. Used to short-circuit
/// the retry's `_dio.fetch(retryOptions)` so the assertions can verify
/// what bearer the retry used and whether the marker was stamped.
class _CapturingSuccessStub extends Interceptor {
  String? lastAuthorization;
  bool lastRetryMarker = false;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    lastAuthorization = options.headers['Authorization'] as String?;
    // Marker is stored in a private Expando on RequestOptions; the
    // interceptor exposes a test-only reader so we can pin the stamp.
    lastRetryMarker = TokenRefreshInterceptor.debugIsMarkedAsRetried(options);
    handler.resolve(Response(requestOptions: options, statusCode: 200, data: '{"ok":true}'));
  }
}

/// Answers every request with 401 the way a server response does: the rejection runs the error
/// interceptors, so the 401 reaches [TokenRefreshInterceptor.onError]. Records each Authorization header.
class _UnauthorizedServerStub extends Interceptor {
  _UnauthorizedServerStub([this.body, this.beforeFirstAnswer, this.statusCode = 401]);

  /// The body of every answer.
  final String? body;

  /// The status of every answer, 401 unless a test asks for another refusal.
  final int statusCode;

  /// Runs once, after the first request is recorded and before it is answered.
  final Future<void> Function()? beforeFirstAnswer;

  final authorizations = <String?>[];

  @override
  Future<void> onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    authorizations.add(options.headers['Authorization'] as String?);
    if (authorizations.length == 1) await beforeFirstAnswer?.call();
    handler.reject(
      DioException(
        requestOptions: options,
        type: DioExceptionType.badResponse,
        response: Response(requestOptions: options, statusCode: statusCode, data: body),
      ),
      true,
    );
  }
}

/// Interceptor that stubs responses or errors before any real HTTP call.
class _StubInterceptor extends Interceptor {
  int? _errorStatusCode;
  String? _errorData;
  String? _successData;
  int _successStatusCode = 200;

  void stubError({required int statusCode, String data = ''}) {
    _errorStatusCode = statusCode;
    _errorData = data;
    _successData = null;
  }

  void stubSuccess({required String data, int statusCode = 200}) {
    _successData = data;
    _successStatusCode = statusCode;
    _errorStatusCode = null;
    _errorData = null;
  }

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (_errorStatusCode != null) {
      // true runs the error interceptors, as a server response does. Without it the error skips every onError,
      // so the pass-through tests would never reach TokenRefreshInterceptor.
      handler.reject(
        DioException(
          requestOptions: options,
          type: DioExceptionType.badResponse,
          response: Response(requestOptions: options, statusCode: _errorStatusCode!, data: _errorData ?? ''),
        ),
        true,
      );
      return;
    }
    if (_successData != null) {
      handler.resolve(Response(requestOptions: options, data: _successData!, statusCode: _successStatusCode));
      return;
    }
    handler.next(options);
  }
}

/// Test handler to capture error interceptor behavior.
class _TestErrorHandler extends ErrorInterceptorHandler {
  bool nextCalled = false;
  bool rejectCalled = false;
  bool resolveCalled = false;
  DioException? nextError;
  DioException? rejectedError;

  @override
  void next(DioException err) {
    nextCalled = true;
    nextError = err;
  }

  @override
  void reject(DioException err, [bool callFollowingErrorInterceptor = false]) {
    rejectCalled = true;
    rejectedError = err;
  }

  @override
  void resolve(Response response) {
    resolveCalled = true;
  }
}

/// A [TokenRotation] that answers every rotation with [result], once [whileRotating] has run, and records the refresh
/// token of each call in [sent].
class _FakeRotation implements TokenRotation {
  _FakeRotation(this.result, {this.whileRotating});

  final TokenRotationResult result;
  final Future<void> Function()? whileRotating;
  final sent = <String>[];

  @override
  Future<TokenRotationResult> rotate(String refreshToken) async {
    sent.add(refreshToken);
    await whileRotating?.call();
    return result;
  }
}

/// An [_InterleavingSecureStorage] that records every key it reads, writes or deletes in [touched], and throws on the
/// write of [failWriteOf].
class _KeyRecordingSecureStorage extends _InterleavingSecureStorage {
  final touched = <String>{};
  String? failWriteOf;

  @override
  Future<String?> read(String key) {
    touched.add(key);
    return super.read(key);
  }

  @override
  Future<void> write(String key, String value) async {
    touched.add(key);
    if (key == failWriteOf) throw StateError('boom on write $key');
    await super.write(key, value);
  }

  @override
  Future<void> delete(String key) {
    touched.add(key);
    return super.delete(key);
  }
}

/// The identity provider as a server behind [_factory]'s Dio: the rotation posts the refresh token there and reads
/// `id_token` and `refresh_token` from a 200 or 201 answer, so a test stubs the provider at the Dio layer. Any other
/// answer, or a failed request, is a refused refresh.
class _DioRotation implements TokenRotation {
  _DioRotation(this._factory);

  final Dio Function(Dio source) _factory;

  @override
  Future<TokenRotationResult> rotate(String refreshToken) async {
    try {
      final response = await _factory(Dio(BaseOptions(baseUrl: 'https://test.api')))
          .post<Object?>('/rotate', data: jsonEncode({'refresh_token': refreshToken}));
      if (response.statusCode != 200 && response.statusCode != 201) return const RotationRefused();
      final body = response.data;
      final decoded = body is String ? jsonDecode(body) : body;
      if (decoded is! Map<String, dynamic>) return const RotationRefused();
      final accessToken = decoded['id_token'];
      if (accessToken is! String || accessToken.isEmpty) return const RotationRefused();
      return TokensRotated(accessToken: accessToken, refreshToken: decoded['refresh_token'] as String?);
    } on DioException {
      return const RotationRefused();
    } on FormatException {
      return const RotationRefused();
    }
  }
}

/// An identity provider that refuses every refresh.
class _NoServerRotation implements TokenRotation {
  const _NoServerRotation();

  @override
  Future<TokenRotationResult> rotate(String refreshToken) async => const RotationRefused();
}
