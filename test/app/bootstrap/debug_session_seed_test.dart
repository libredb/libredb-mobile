import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/app/bootstrap/debug_session_seed.dart';
import 'package:libredb_mobile/infrastructure/storage/secure_storage.dart';
import 'package:libredb_mobile/shared/models/session_target.dart';

/// [DebugSessionSeed] seeds a signed-in session into secure storage for the on-device local twin, so the app lands on
/// the connection list without driving the Keycloak Custom Tab. Debug + `main_local` only; see the on-device test
/// architecture spec. These tests drive the pure parser and the seeding, both headless.
void main() {
  group('DebugSessionSeed.parse', () {
    test('returns null when SEED_SESSION is not enabled', () {
      expect(
        DebugSessionSeed.parse(enabled: false, target: 'studio', accessToken: 'a', refreshToken: 'r', oidcIdToken: ''),
        isNull,
      );
    });

    test('throws when enabled without an access token to seed', () {
      expect(
        () => DebugSessionSeed.parse(
          enabled: true,
          target: 'studio',
          accessToken: '',
          refreshToken: 'r',
          oidcIdToken: '',
        ),
        throwsArgumentError,
      );
    });

    test('throws when enabled without a refresh token (the seeded access token is always expired, so a refresh is the '
        'only way the session survives startup)', () {
      expect(
        () => DebugSessionSeed.parse(
          enabled: true,
          target: 'studio',
          accessToken: 'a',
          refreshToken: '',
          oidcIdToken: '',
        ),
        throwsArgumentError,
      );
    });

    test('reads the target from its stored value', () {
      final seed = DebugSessionSeed.parse(
        enabled: true,
        target: 'platform',
        accessToken: 'a',
        refreshToken: 'r',
        oidcIdToken: 'id',
      );
      expect(seed!.target, SessionTarget.platform);
    });

    test('defaults an unreadable target to Studio', () {
      final seed = DebugSessionSeed.parse(
        enabled: true,
        target: 'nonsense',
        accessToken: 'a',
        refreshToken: 'r',
        oidcIdToken: '',
      );
      expect(seed!.target, SessionTarget.studio);
    });
  });

  group('DebugSessionSeed.seedInto', () {
    test('writes a session whose access token is already expired, so the app refreshes it at startup', () async {
      final storage = _MemorySecureStorage();
      final seed = DebugSessionSeed.parse(
        enabled: true,
        target: 'studio',
        accessToken: 'ACCESS',
        refreshToken: 'REFRESH',
        oidcIdToken: 'OIDC_ID',
      )!;

      await seed.seedInto(storage);

      expect(await storage.read(SecureStorageKeys.sessionTarget.key), SessionTarget.studio.storedValue);
      expect(await storage.read(SecureStorageKeys.jwtToken.key), 'ACCESS');
      expect(await storage.read(SecureStorageKeys.refreshToken.key), 'REFRESH');
      expect(await storage.read(SecureStorageKeys.oidcIdToken.key), 'OIDC_ID');

      final expiry = readAccessTokenExpiry(await storage.read(SecureStorageKeys.accessTokenExpiresAt.key));
      expect(expiry, isNotNull);
      expect(
        expiry!.isBefore(DateTime.now().toUtc()),
        isTrue,
        reason: 'the seeded expiry must be in the past so SsoSessionStartup refreshes the token',
      );
    });

    test('omits the ID token when none was seeded', () async {
      final storage = _MemorySecureStorage();
      final seed = DebugSessionSeed.parse(
        enabled: true,
        target: 'studio',
        accessToken: 'ACCESS',
        refreshToken: 'REFRESH',
        oidcIdToken: '',
      )!;

      await seed.seedInto(storage);

      expect(await storage.read(SecureStorageKeys.oidcIdToken.key), isNull);
      expect(await storage.read(SecureStorageKeys.jwtToken.key), 'ACCESS');
    });
  });
}

/// A stateful in-memory [ISecureStorage]; the seed only writes, so reads come straight back.
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
  Future<Set<String>> keys() async => _store.keys.toSet();
}
