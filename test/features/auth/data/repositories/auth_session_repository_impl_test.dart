import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/auth/data/repositories/auth_session_repository_impl.dart';
import 'package:libredb_mobile/features/auth/domain/entities/auth_session.dart';
import 'package:libredb_mobile/infrastructure/cache/cache_storage.dart';
import 'package:libredb_mobile/infrastructure/cache/shared_prefs_cache_storage.dart';
import 'package:libredb_mobile/infrastructure/http/interceptors/auth_interceptor.dart';
import 'package:libredb_mobile/infrastructure/http/interceptors/token_refresh_interceptor.dart';
import 'package:libredb_mobile/infrastructure/http/token_rotation.dart';
import 'package:libredb_mobile/infrastructure/storage/local_storage.dart';
import 'package:libredb_mobile/infrastructure/storage/secure_storage.dart';
import 'package:libredb_mobile/infrastructure/storage/session_generation.dart';
import 'package:libredb_mobile/infrastructure/storage/temporary_share_files.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// In-memory ISecureStorage for tests.
class _MemorySecureStorage implements ISecureStorage {
  final Map<String, String> _store = {};
  @override
  Future<String?> read(String key) async => _store[key];
  @override
  Future<void> write(String key, String value) async => _store[key] = value;
  @override
  Future<void> delete(String key) async => _store.remove(key);
  @override
  Future<void> deleteAll() async => _store.clear();

  @override
  Future<Set<String>> keys() => throw UnimplementedError('not used by this test');
}

/// ISecureStorage whose read() always throws. Exercises the
/// Result-on-snapshot-failure contract in persist().
class _ReadThrowsSecureStorage implements ISecureStorage {
  @override
  Future<String?> read(String key) async => throw StateError('boom on read $key');
  @override
  Future<void> write(String key, String value) async {}
  @override
  Future<void> delete(String key) async {}
  @override
  Future<void> deleteAll() async {}

  @override
  Future<Set<String>> keys() => throw UnimplementedError('not used by this test');
}

/// ISecureStorage that throws on the configured delete key. Exercises
/// the best-effort sequential cleanup path in clear().
class _SelectiveFailSecureStorage implements ISecureStorage {
  _SelectiveFailSecureStorage({required this.failOn});
  final String failOn;
  final Map<String, String> _store = {};
  @override
  Future<String?> read(String key) async => _store[key];
  @override
  Future<void> write(String key, String value) async => _store[key] = value;
  @override
  Future<void> delete(String key) async {
    if (key == failOn) throw StateError('boom on $key');
    _store.remove(key);
  }

  @override
  Future<void> deleteAll() async => _store.clear();

  @override
  Future<Set<String>> keys() => throw UnimplementedError('not used by this test');
}

/// ISecureStorage whose write of [failOnWrite] stores the value and then throws, as an adapter that fails after it
/// changed the platform store. Exercises the rollback of a key whose write failed.
class _WriteFailSecureStorage extends _MemorySecureStorage {
  _WriteFailSecureStorage({required this.failOnWrite});
  final String failOnWrite;
  @override
  Future<void> write(String key, String value) async {
    await super.write(key, value);
    if (key == failOnWrite) throw StateError('boom on write $key');
  }
}

/// In-memory ISecureStorage that records every call as `<method> <key>`, in order.
class _CallRecordingSecureStorage extends _MemorySecureStorage {
  final calls = <String>[];
  @override
  Future<String?> read(String key) {
    calls.add('read $key');
    return super.read(key);
  }

  @override
  Future<void> write(String key, String value) {
    calls.add('write $key');
    return super.write(key, value);
  }

  @override
  Future<void> delete(String key) {
    calls.add('delete $key');
    return super.delete(key);
  }
}

/// Cache whose `clear` fails, as SharedPrefsCacheStorage.clear does when SharedPreferences keeps an entry.
class _FailingClearCacheStorage implements ICacheStorage {
  @override
  Future<CacheEntry?> read(String key) async => null;
  @override
  Future<void> write(String key, String data, {Duration? ttl}) async {}
  @override
  Future<void> remove(String key) async {}
  @override
  Future<void> clear() async => throw StateError('Cache clear left 1 of 2 entries');
}

void main() {
  late AppLocalStorage storage;
  late _MemorySecureStorage secure;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = AppLocalStorage();
    storage.setPreferencesInstance(await SharedPreferences.getInstance());
    secure = _MemorySecureStorage();
  });

  group('AuthSessionRepository', () {
    test('persist writes the tokens to secure storage and no username or role anywhere', () async {
      final repo = AuthSessionRepository(secureStorage: secure, storage: storage);
      const session = AuthSession(idToken: 'TOKEN', refreshToken: 'REFRESH');

      final result = await repo.persist(session);

      expect(result, isA<Success<void>>());
      expect(await secure.read(SecureStorageKeys.jwtToken.key), 'TOKEN');
      expect(await secure.read(SecureStorageKeys.refreshToken.key), 'REFRESH');
      expect(await storage.read('username'), isNull);
      expect(await storage.read('roles'), isNull);
    });

    test('persist deletes refreshToken from secure storage when null', () async {
      await secure.write(SecureStorageKeys.refreshToken.key, 'STALE');
      final repo = AuthSessionRepository(secureStorage: secure, storage: storage);
      const session = AuthSession(idToken: 'TOKEN');

      await repo.persist(session);

      expect(await secure.read(SecureStorageKeys.refreshToken.key), isNull);
    });

    test('persist rolls back the token it wrote when a later write fails', () async {
      final failing = _WriteFailSecureStorage(failOnWrite: SecureStorageKeys.refreshToken.key);
      final repo = AuthSessionRepository(secureStorage: failing, storage: storage);
      const session = AuthSession(idToken: 'TOKEN', refreshToken: 'REFRESH');

      final result = await repo.persist(session);

      expect(result, isA<Failure<void>>());
      expect(await failing.read(SecureStorageKeys.jwtToken.key), isNull, reason: 'secure token rolled back');
      expect(await failing.read(SecureStorageKeys.refreshToken.key), isNull, reason: 'secure refresh rolled back');
    });

    test('rollback restores prior secure values, not just deletes', () async {
      final failing = _WriteFailSecureStorage(failOnWrite: SecureStorageKeys.accessTokenExpiresAt.key);
      await failing.write(SecureStorageKeys.jwtToken.key, 'OLD_JWT');
      await failing.write(SecureStorageKeys.refreshToken.key, 'OLD_REFRESH');
      final repo = AuthSessionRepository(secureStorage: failing, storage: storage);
      final session = AuthSession(
        idToken: 'NEW_JWT',
        refreshToken: 'NEW_REFRESH',
        accessTokenExpiresAt: DateTime.utc(2100),
      );

      final result = await repo.persist(session);

      expect(result, isA<Failure<void>>());
      expect(await failing.read(SecureStorageKeys.jwtToken.key), 'OLD_JWT');
      expect(await failing.read(SecureStorageKeys.refreshToken.key), 'OLD_REFRESH');
    });

    test('rollback restores stale refreshToken that persist had deleted', () async {
      // The new session has no refresh token, so persist deletes the stale one, then a later write fails.
      final failing = _WriteFailSecureStorage(failOnWrite: SecureStorageKeys.accessTokenExpiresAt.key);
      await failing.write(SecureStorageKeys.refreshToken.key, 'STALE_REFRESH');
      final repo = AuthSessionRepository(secureStorage: failing, storage: storage);

      final result = await repo.persist(AuthSession(idToken: 'NEW_JWT', accessTokenExpiresAt: DateTime.utc(2100)));

      expect(result, isA<Failure<void>>());
      expect(await failing.read(SecureStorageKeys.refreshToken.key), 'STALE_REFRESH');
    });

    test('persist returns Failure (does not throw) when snapshot read fails', () async {
      // ISecureStorage.read is allowed to throw on platform failure.
      // Repository contract: persist always returns a Result — never
      // propagates a raw exception, including from the pre-write
      // snapshot.
      final flaky = _ReadThrowsSecureStorage();
      final repo = AuthSessionRepository(secureStorage: flaky, storage: storage);
      const session = AuthSession(idToken: 'TOKEN');

      final result = await repo.persist(session);

      expect(result, isA<Failure<void>>());
    });

    test('clear keeps wiping even if one secure delete throws', () async {
      // _MemorySecureStorage that selectively throws on one key — proves
      // clear() doesn't bail on the first failure and leave the other
      // secure key behind.
      final flaky = _SelectiveFailSecureStorage(failOn: SecureStorageKeys.jwtToken.key);
      await flaky.write(SecureStorageKeys.refreshToken.key, 'REFRESH');
      final repo = AuthSessionRepository(secureStorage: flaky, storage: storage);

      final result = await repo.clear();

      expect(result, isA<Failure<void>>(), reason: 'partial failure surfaces as Failure');
      expect(await flaky.read(SecureStorageKeys.refreshToken.key), isNull);
    });

    test('clear removes the stored token', () async {
      await secure.write(SecureStorageKeys.jwtToken.key, 'TOKEN');
      final repo = AuthSessionRepository(secureStorage: secure, storage: storage);

      final result = await repo.clear();

      expect(result, isA<Success<void>>());
      expect(await secure.read(SecureStorageKeys.jwtToken.key), isNull);
    });

    test('clear keeps the device preferences', () async {
      await storage.save(StorageKeys.language.key, 'tr');
      await storage.save(StorageKeys.theme.key, 'nature');
      await storage.save(StorageKeys.brightness.key, 'dark');
      final repo = AuthSessionRepository(secureStorage: secure, storage: storage);
      await repo.persist(const AuthSession(idToken: 'TOKEN'));

      final result = await repo.clear();

      expect(result, isA<Success<void>>());
      expect(await storage.read(StorageKeys.language.key), 'tr');
      expect(await storage.read(StorageKeys.theme.key), 'nature');
      expect(await storage.read(StorageKeys.brightness.key), 'dark');
    });

    test('clear removes the session keys', () async {
      final repo = AuthSessionRepository(secureStorage: secure, storage: storage);
      await repo.persist(const AuthSession(idToken: 'TOKEN', refreshToken: 'REFRESH'));

      final result = await repo.clear();

      expect(result, isA<Success<void>>());
      expect(await secure.read(SecureStorageKeys.jwtToken.key), isNull);
      expect(await secure.read(SecureStorageKeys.refreshToken.key), isNull);
    });

    // Guards the switch from wiping everything to removing session keys: the cache is no longer wiped with them.
    test('clear removes the cached responses', () async {
      final cache = SharedPrefsCacheStorage();
      await cache.write('GET_/account', '{"login":"alice"}');
      await cache.write('GET_/admin/users', '[{"login":"bob"}]');
      final repo = AuthSessionRepository(secureStorage: secure, storage: storage, cacheStorage: cache);

      final result = await repo.clear();

      expect(result, isA<Success<void>>());
      expect(await cache.read('GET_/account'), isNull);
      expect(await cache.read('GET_/admin/users'), isNull);
    });

    test('clear reports cached responses that stay behind and still removes the session', () async {
      final repo = AuthSessionRepository(
        secureStorage: secure,
        storage: storage,
        cacheStorage: _FailingClearCacheStorage(),
      );
      await repo.persist(const AuthSession(idToken: 'TOKEN', refreshToken: 'REFRESH'));

      final result = await repo.clear();

      expect(result, isA<Failure<void>>());
      expect((result as Failure<void>).error.message, contains('Cache clear left 1 of 2 entries'));
      expect(await secure.read(SecureStorageKeys.jwtToken.key), isNull);
      expect(await secure.read(SecureStorageKeys.refreshToken.key), isNull);
    });

    // Regression (#202): a source shared as a file stayed in the temporary directory for the next account.
    test('clear removes the files the share sheet got', () async {
      final temporary = Directory.systemTemp.createTempSync('session_share_files');
      addTearDown(() => temporary.deleteSync(recursive: true));
      final shareFiles = TemporaryShareFiles(temporaryDirectory: () async => temporary);
      final shared = await shareFiles.write('order_totals-definition.sql', [1]);
      final copy = File('${temporary.path}/share_plus/order_totals-definition.sql')..createSync(recursive: true);
      final repo = AuthSessionRepository(secureStorage: secure, storage: storage, shareFiles: shareFiles);

      final result = await repo.clear();

      expect(result, isA<Success<void>>());
      expect(shared.existsSync(), isFalse);
      expect(copy.existsSync(), isFalse);
    });

    test('clear reports share files that stay behind, without their path, and still removes the session', () async {
      final repo = AuthSessionRepository(
        secureStorage: secure,
        storage: storage,
        shareFiles: TemporaryShareFiles(
          temporaryDirectory: () async => throw const FileSystemException('refused', '/cache/share_files/a.sql'),
        ),
      );
      await repo.persist(const AuthSession(idToken: 'TOKEN', refreshToken: 'REFRESH'));

      final result = await repo.clear();

      expect(result, isA<Failure<void>>());
      final message = (result as Failure<void>).error.message;
      expect(message, contains('share files: FileSystemException'));
      expect(message, isNot(contains('a.sql')));
      expect(await secure.read(SecureStorageKeys.jwtToken.key), isNull);
      expect(await secure.read(SecureStorageKeys.refreshToken.key), isNull);
    });

    // A token refresh drops its rotated tokens once the session it was asked for has ended. Unless the wipe counts as
    // that end from its first storage call until it finishes, and a generation read while it ran counts as ended once
    // it finishes, a refresh can store its tokens during or after the wipe, and a relaunch restores the session.
    test('clear ends the session generation for the whole wipe and again when it finishes', () async {
      final before = SessionGeneration.current;
      final recording = _GenerationRecordingSecureStorage();
      final cache = _GenerationRecordingCacheStorage();
      await recording.write(SecureStorageKeys.jwtToken.key, 'TOKEN');
      recording.calls.clear();

      await AuthSessionRepository(secureStorage: recording, storage: storage, cacheStorage: cache).clear();

      expect(SessionGeneration.hasEnded(before), isTrue);
      // The deletes of the access token, the refresh token, the ID token and the expiry, and the cache clear: the first
      // and the last storage calls of the wipe.
      expect(recording.calls, hasLength(4));
      expect(recording.calls.map((call) => call.ended), everyElement(isTrue));
      expect(cache.endedWhenCleared, isTrue);
      expect(SessionGeneration.hasEnded(recording.calls.first.generation), isTrue);
    });
  });

  group('AuthSessionRepository with the OIDC keys', () {
    final expiresAt = DateTime.utc(2026, 10, 21, 12);
    final idTokenKey = SecureStorageKeys.oidcIdToken.key;
    final expiryKey = SecureStorageKeys.accessTokenExpiresAt.key;

    test('persists the OIDC ID token and the expiry next to the tokens', () async {
      final recording = _CallRecordingSecureStorage();
      final repo = AuthSessionRepository(secureStorage: recording, storage: storage);
      final session = AuthSession(
        idToken: 'ACCESS',
        refreshToken: 'REFRESH',
        oidcIdToken: 'ID_TOKEN',
        accessTokenExpiresAt: expiresAt,
      );

      final result = await repo.persist(session);

      expect(result, isA<Success<void>>());
      expect(recording.calls.where((call) => call.startsWith('write ')), [
        'write ${SecureStorageKeys.jwtToken.key}',
        'write ${SecureStorageKeys.refreshToken.key}',
        'write $idTokenKey',
        'write $expiryKey',
      ]);
      expect(await recording.read(idTokenKey), 'ID_TOKEN');
      expect(await recording.read(expiryKey), encodeAccessTokenExpiry(expiresAt));
      expect(readAccessTokenExpiry(await recording.read(expiryKey)), expiresAt);
    });

    test('deletes a stored OIDC ID token and expiry when the new session has none', () async {
      await secure.write(idTokenKey, 'OLD_ID_TOKEN');
      await secure.write(expiryKey, encodeAccessTokenExpiry(expiresAt));
      final repo = AuthSessionRepository(secureStorage: secure, storage: storage);

      final result = await repo.persist(const AuthSession(idToken: 'ACCESS'));

      expect(result, isA<Success<void>>());
      expect(await secure.read(idTokenKey), isNull);
      expect(await secure.read(expiryKey), isNull);
    });

    test('rolls the OIDC ID token and expiry back when a later write fails', () async {
      final failing = _WriteFailSecureStorage(failOnWrite: expiryKey);
      await failing.write(SecureStorageKeys.jwtToken.key, 'OLD_ACCESS');
      await failing.write(SecureStorageKeys.refreshToken.key, 'OLD_REFRESH');
      await failing.write(idTokenKey, 'OLD_ID_TOKEN');
      final repo = AuthSessionRepository(secureStorage: failing, storage: storage);
      final session = AuthSession(
        idToken: 'NEW_ACCESS',
        refreshToken: 'NEW_REFRESH',
        oidcIdToken: 'NEW_ID_TOKEN',
        accessTokenExpiresAt: expiresAt,
      );

      final result = await repo.persist(session);

      expect(result, isA<Failure<void>>());
      expect(await failing.read(SecureStorageKeys.jwtToken.key), 'OLD_ACCESS');
      expect(await failing.read(SecureStorageKeys.refreshToken.key), 'OLD_REFRESH');
      expect(await failing.read(idTokenKey), 'OLD_ID_TOKEN');
      expect(await failing.read(expiryKey), isNull, reason: 'the expiry the failed write stored is removed');
    });

    test('restores a stored expiry and ID token when a later write fails', () async {
      final priorExpiry = encodeAccessTokenExpiry(expiresAt);
      final failing = _WriteFailSecureStorage(failOnWrite: expiryKey);
      await failing.write(idTokenKey, 'OLD_ID_TOKEN');
      // Stored directly: a write of the expiry fails on this store.
      failing._store[expiryKey] = priorExpiry;
      final repo = AuthSessionRepository(secureStorage: failing, storage: storage);
      final session = AuthSession(
        idToken: 'NEW_ACCESS',
        oidcIdToken: 'NEW_ID_TOKEN',
        accessTokenExpiresAt: expiresAt.add(const Duration(minutes: 5)),
      );

      final result = await repo.persist(session);

      expect(result, isA<Failure<void>>());
      expect(await failing.read(idTokenKey), 'OLD_ID_TOKEN');
      expect(await failing.read(expiryKey), priorExpiry);
    });

    test('clear deletes the OIDC ID token and the expiry', () async {
      final repo = AuthSessionRepository(secureStorage: secure, storage: storage);
      await repo.persist(AuthSession(idToken: 'ACCESS', oidcIdToken: 'ID_TOKEN', accessTokenExpiresAt: expiresAt));

      final result = await repo.clear();

      expect(result, isA<Success<void>>());
      expect(await secure.read(SecureStorageKeys.jwtToken.key), isNull);
      expect(await secure.read(idTokenKey), isNull);
      expect(await secure.read(expiryKey), isNull);
    });

    test('clear keeps deleting the OIDC keys when the bearer delete throws', () async {
      final flaky = _SelectiveFailSecureStorage(failOn: SecureStorageKeys.jwtToken.key);
      await flaky.write(idTokenKey, 'ID_TOKEN');
      await flaky.write(expiryKey, encodeAccessTokenExpiry(expiresAt));
      final repo = AuthSessionRepository(secureStorage: flaky, storage: storage);

      final result = await repo.clear();

      expect(result, isA<Failure<void>>());
      expect(await flaky.read(idTokenKey), isNull);
      expect(await flaky.read(expiryKey), isNull);
    });

    test('clear reports an OIDC key it cannot delete and still removes the rest', () async {
      final flaky = _SelectiveFailSecureStorage(failOn: idTokenKey);
      await flaky.write(SecureStorageKeys.jwtToken.key, 'ACCESS');
      await flaky.write(expiryKey, encodeAccessTokenExpiry(expiresAt));
      final repo = AuthSessionRepository(secureStorage: flaky, storage: storage);

      final result = await repo.clear();

      expect(result, isA<Failure<void>>());
      expect((result as Failure<void>).error.message, contains('oidcIdToken'));
      expect(await flaky.read(SecureStorageKeys.jwtToken.key), isNull);
      expect(await flaky.read(expiryKey), isNull);
    });
  });

  // A logout or the end of the session wipes the stored session while requests may still get 401 and ask for a token
  // refresh. TokenRefreshInterceptor must not store the rotated tokens of a session the wipe ended, or a relaunch
  // restores it.
  group('AuthSessionRepository.clear during a token refresh', () {
    late Dio dio;
    late _CountingRotation refreshStub;
    late int sessionExpiredCalls;

    setUp(() {
      dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'))..interceptors.add(_OkStub());
      refreshStub = _CountingRotation();
      sessionExpiredCalls = 0;
    });

    tearDown(() => dio.close());

    TokenRefreshInterceptor refreshInterceptor(ISecureStorage secureStorage) => TokenRefreshInterceptor(
      dio: dio,
      secureStorage: secureStorage,
      onSessionExpired: () => sessionExpiredCalls++,
      rotation: refreshStub,
    );

    // Regression: a logout that started while the 401 read the stored token let the refresh read the refresh token
    // before the wipe deleted it, and the refresh stored the rotated tokens after the wipe, so a relaunch restored the
    // session the user ended.
    test('stores no tokens when the wipe starts while the 401 reads the stored token', () async {
      final inOrder = _InOrderSecureStorage()
        ..store[SecureStorageKeys.jwtToken.key] = 'old-jwt'
        ..store[SecureStorageKeys.refreshToken.key] = 'old-refresh';
      final sent = await _send(AuthInterceptor(secureStorage: inOrder), RequestOptions(path: '/account'));
      final unauthorized = DioException(
        requestOptions: sent,
        response: Response(requestOptions: sent, statusCode: 401),
      );
      final handler = _TestErrorHandler();

      final handled = refreshInterceptor(inOrder).onError(unauthorized, handler);
      // The user logs out while the 401 reads the stored token.
      final cleared = AuthSessionRepository(secureStorage: inOrder, storage: storage).clear();
      await Future.wait([handled, cleared]);

      expect(inOrder.store, isEmpty, reason: 'a relaunch restores the tokens that are stored');
      expect(refreshStub.requests, 0, reason: 'the session the logout ended is not refreshed');
      expect(handler.passedOn, same(unauthorized), reason: 'the request fails with its 401');
      expect(sessionExpiredCalls, 0);
    });

    // The refresh token stored after a logout belongs to the session the user signed in to since, not to the request.
    test('does not refresh the next session for a request sent before the logout', () async {
      await secure.write(SecureStorageKeys.refreshToken.key, 'old-refresh');
      // No token is stored, so the request goes out without one.
      final sent = await _send(AuthInterceptor(secureStorage: secure), RequestOptions(path: '/account'));
      await AuthSessionRepository(secureStorage: secure, storage: storage).clear();
      await secure.write(SecureStorageKeys.jwtToken.key, 'signed-in-jwt');
      await secure.write(SecureStorageKeys.refreshToken.key, 'signed-in-refresh');
      final unauthorized = DioException(
        requestOptions: sent,
        response: Response(requestOptions: sent, statusCode: 401),
      );
      final handler = _TestErrorHandler();

      await refreshInterceptor(secure).onError(unauthorized, handler);

      expect(refreshStub.requests, 0);
      expect(handler.passedOn, same(unauthorized), reason: 'the request fails with its 401');
      expect(await secure.read(SecureStorageKeys.jwtToken.key), 'signed-in-jwt');
      expect(await secure.read(SecureStorageKeys.refreshToken.key), 'signed-in-refresh');
      expect(sessionExpiredCalls, 0);
    });

    // A logout must never wait behind a refresh that a slow server holds up.
    test('does not make logout wait for a refresh on its way', () async {
      await secure.write(SecureStorageKeys.jwtToken.key, 'old-jwt');
      await secure.write(SecureStorageKeys.refreshToken.key, 'old-refresh');
      final rotation = _HangingRotation();
      final sent = await _send(AuthInterceptor(secureStorage: secure), RequestOptions(path: '/account'));
      final unauthorized = DioException(
        requestOptions: sent,
        response: Response(requestOptions: sent, statusCode: 401),
      );
      final handled = TokenRefreshInterceptor(
        dio: dio,
        secureStorage: secure,
        rotation: rotation,
        onSessionExpired: () => sessionExpiredCalls++,
      ).onError(unauthorized, _TestErrorHandler());
      await rotation.started.future;

      final cleared = await AuthSessionRepository(
        secureStorage: secure,
        storage: storage,
      ).clear().timeout(const Duration(seconds: 1));

      expect(cleared, isA<Success<void>>());
      expect(await secure.read(SecureStorageKeys.refreshToken.key), isNull);
      rotation.answer.complete(const RotationRefused());
      await handled;
    });
  });
}

/// In-memory ISecureStorage that records, at each call, the session generation and whether it counts as ended.
class _GenerationRecordingSecureStorage extends _MemorySecureStorage {
  final calls = <({int generation, bool ended})>[];

  void _record() {
    final generation = SessionGeneration.current;
    calls.add((generation: generation, ended: SessionGeneration.hasEnded(generation)));
  }

  @override
  Future<String?> read(String key) {
    _record();
    return super.read(key);
  }

  @override
  Future<void> write(String key, String value) {
    _record();
    return super.write(key, value);
  }

  @override
  Future<void> delete(String key) {
    _record();
    return super.delete(key);
  }
}

/// Cache that records whether the session generation counted as ended when it was cleared.
class _GenerationRecordingCacheStorage implements ICacheStorage {
  bool? endedWhenCleared;

  @override
  Future<CacheEntry?> read(String key) async => null;
  @override
  Future<void> write(String key, String data, {Duration? ttl}) async {}
  @override
  Future<void> remove(String key) async {}
  @override
  Future<void> clear() async => endedWhenCleared = SessionGeneration.hasEnded(SessionGeneration.current);
}

/// ISecureStorage that answers like the platform store: each call takes effect when it is made, and the answers come
/// back in the order of the calls, each a moment after the one before.
class _InOrderSecureStorage implements ISecureStorage {
  final store = <String, String>{};
  Future<void> _lastAnswer = Future<void>.value();

  Future<T> _answer<T>(T value) {
    final answer = _lastAnswer.then((_) => Future<void>.delayed(const Duration(milliseconds: 1)));
    _lastAnswer = answer;
    return answer.then((_) => value);
  }

  @override
  Future<String?> read(String key) => _answer(store[key]);

  @override
  Future<void> write(String key, String value) {
    store[key] = value;
    return _answer<void>(null);
  }

  @override
  Future<void> delete(String key) {
    store.remove(key);
    return _answer<void>(null);
  }

  @override
  Future<void> deleteAll() {
    store.clear();
    return _answer<void>(null);
  }

  @override
  Future<Set<String>> keys() => throw UnimplementedError('not used by this test');
}

/// Sends [options] through [interceptor], as the client sends every request, and returns them as they leave it.
Future<RequestOptions> _send(AuthInterceptor interceptor, RequestOptions options) async {
  final handler = _TestRequestHandler();
  await interceptor.onRequest(options, handler);
  return handler.sent!;
}

class _TestRequestHandler extends RequestInterceptorHandler {
  RequestOptions? sent;

  @override
  void next(RequestOptions requestOptions) => sent = requestOptions;
}

class _TestErrorHandler extends ErrorInterceptorHandler {
  DioException? passedOn;

  @override
  void next(DioException err) => passedOn = err;

  @override
  void resolve(Response<dynamic> response) {}

  @override
  void reject(DioException error, [bool callFollowingErrorInterceptor = false]) {}
}

/// Answers the token refresh with rotated tokens and counts the refresh requests.
class _CountingRotation implements TokenRotation {
  int requests = 0;

  @override
  Future<TokenRotationResult> rotate(String refreshToken) async {
    requests++;
    return const TokensRotated(accessToken: 'new-jwt', refreshToken: 'new-refresh');
  }
}

/// Answers every request with 200, as the server answers a request sent again with a fresh token.
class _OkStub extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) =>
      handler.resolve(Response(requestOptions: options, statusCode: 200, data: '{}'));
}

/// A rotation whose server takes the refresh token and answers only when the test completes [answer].
class _HangingRotation implements TokenRotation {
  final started = Completer<void>();
  final answer = Completer<TokenRotationResult>();

  @override
  Future<TokenRotationResult> rotate(String refreshToken) {
    started.complete();
    return answer.future;
  }
}
