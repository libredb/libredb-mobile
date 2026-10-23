import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:libredb_mobile/features/auth/data/repositories/auth_session_repository_impl.dart';
import 'package:libredb_mobile/infrastructure/storage/secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

/// ISecureStorage that throws on the configured delete key. Used to
/// exercise the best-effort sequential cleanup path in logout.
class _FlakyDeleteSecureStorage implements ISecureStorage {
  _FlakyDeleteSecureStorage({required this.failOn});
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

LoginRepository _repository(ISecureStorage secure) =>
    LoginRepository(sessionRepository: AuthSessionRepository(secureStorage: secure));

void main() {
  group('LoginRepository.logout', () {
    test('clears the stored session', () async {
      final secure = FlutterSecureStorageAdapter();
      await secure.write(SecureStorageKeys.jwtToken.key, 'MOCK_TOKEN');

      final result = await _repository(secure).logout();

      expect(result, isA<Success<void>>());
      // The secure store no longer holds the token, so AuthInterceptor cannot re-attach it.
      expect(await secure.read(SecureStorageKeys.jwtToken.key), isNull);
    });

    test('keeps wiping even if one secure delete throws', () async {
      // A partial failure must not skip the later cleanup steps: any leftover token would let AuthInterceptor
      // re-attach it on the next request.
      final secure = _FlakyDeleteSecureStorage(failOn: SecureStorageKeys.jwtToken.key);
      await secure.write(SecureStorageKeys.refreshToken.key, 'REFRESH');

      final result = await _repository(secure).logout();

      expect(result, isA<Failure<void>>(), reason: 'partial failure surfaced as Failure');
      expect(
        await secure.read(SecureStorageKeys.refreshToken.key),
        isNull,
        reason: 'refresh delete ran even though jwt delete threw',
      );
    });

    test('wipes the access token and the refresh token', () async {
      final secure = FlutterSecureStorageAdapter();
      await secure.write(SecureStorageKeys.jwtToken.key, 'JWT_VALUE');
      await secure.write(SecureStorageKeys.refreshToken.key, 'REFRESH_VALUE');

      final result = await _repository(secure).logout();

      expect(result, isA<Success<void>>());
      expect(await secure.read(SecureStorageKeys.jwtToken.key), isNull, reason: 'the token must not survive logout');
      expect(
        await secure.read(SecureStorageKeys.refreshToken.key),
        isNull,
        reason: 'the refresh token must not survive logout',
      );
    });
  });
}
