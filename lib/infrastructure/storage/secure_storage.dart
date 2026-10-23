import 'package:libredb_mobile/core/logging/app_logger.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Abstract interface for secure key-value storage.
///
/// Used for sensitive data like JWT tokens that should not be stored
/// in plaintext SharedPreferences.
///
/// Failure contract: every method MUST throw on platform failure so
/// that callers using Result/rollback semantics, such as the
/// session-persist repository, can react correctly.
/// Silently swallowing errors here makes Success reports meaningless.
/// In particular, [read] does NOT collapse platform failures to null
/// — a transient read failure during a rollback snapshot must not be
/// misread as "no prior value" and lead to deleting an existing token.
///
/// [read] returns null only when the key is absent. Platform / decryption
/// failures throw.
///
/// Android exception: [FlutterSecureStorageAdapter] keeps the plugin default
/// `resetOnError: true`. When an entry can no longer be decrypted (for
/// example after a backup restore without its Keystore key), the plugin
/// deletes it and [read] returns null, so the caller sees an absent key.
/// With `resetOnError: false`, a lost Keystore key would leave the whole
/// store unusable, including writes, which blocks sign-in.
abstract interface class ISecureStorage {
  /// Read a value by [key]. Returns null only when the key is absent.
  /// Throws on platform / decryption failure so transactional callers
  /// can distinguish "missing" from "unknown".
  Future<String?> read(String key);

  /// Write a [value] for the given [key]. Throws on platform failure.
  Future<void> write(String key, String value);

  /// Delete the value for the given [key]. Throws on platform failure.
  Future<void> delete(String key);

  /// Delete all stored values. Throws on platform failure.
  Future<void> deleteAll();

  /// The names of every stored value, so an owner can find its own by a prefix. Throws on platform failure, and on
  /// Android when any value cannot be decrypted; it never deletes a value.
  Future<Set<String>> keys();
}

/// Production implementation backed by [FlutterSecureStorage].
///
/// Platform configuration is pinned explicitly so future package
/// upgrades or default flips cannot silently weaken the security
/// posture of stored secrets:
///
/// - **Android:** `flutter_secure_storage` ≥ 11 encrypts with AES-GCM
///   under an RSA-OAEP wrapped Android Keystore key. The legacy
///   RSA-PKCS1 / AES-CBC ciphers and the Jetpack EncryptedSharedPreferences
///   backend were removed in 11.0.0; data written by 10.x is read as-is.
///   The plugin's min SDK is 24, so all targets support hardware-backed
///   key storage. No extra options are needed beyond accepting the
///   library defaults — flagged here so an audit reader does not
///   wonder whether plaintext fallback is possible.
/// - **iOS:** Keychain accessibility is pinned to
///   [KeychainAccessibility.first_unlock_this_device]: secrets are
///   readable after the first unlock until a restart, so a background
///   refresh can read them while the device is locked, and they never
///   move to another device through a backup or iCloud Keychain. The
///   library default, [KeychainAccessibility.unlocked], reads only while
///   the device is unlocked and lets an item move to a new device in an
///   encrypted backup; keeping session tokens on this device is the part
///   that matters for them.
class FlutterSecureStorageAdapter implements ISecureStorage {
  static final _log = AppLogger.getLogger('FlutterSecureStorageAdapter');

  static const _iosOptions = IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device);

  final FlutterSecureStorage _storage;

  FlutterSecureStorageAdapter({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage(iOptions: _iosOptions);

  @override
  Future<String?> read(String key) async {
    _log.trace('Reading secure storage key: {}', [key]);
    return await _storage.read(key: key);
  }

  @override
  Future<void> write(String key, String value) async {
    _log.trace('Writing secure storage key: {}', [key]);
    await _storage.write(key: key, value: value);
  }

  @override
  Future<void> delete(String key) async {
    _log.trace('Deleting secure storage key: {}', [key]);
    await _storage.delete(key: key);
  }

  @override
  Future<void> deleteAll() async {
    _log.info('Deleting all secure storage data');
    await _storage.deleteAll();
  }

  /// The plugin has no call that lists names only, so this reads every value: the values cross into memory and are
  /// dropped here, never returned or logged. On Android it passes `resetOnError: false` for this call alone, because
  /// readAll decrypts every value and the plugin's default answers one that fails by deleting the whole store; a
  /// corrupt entry then throws instead, and nothing is deleted.
  @override
  Future<Set<String>> keys() async {
    _log.trace('Listing secure storage keys');
    return (await _storage.readAll(aOptions: _listingAndroidOptions)).keys.toSet();
  }

  static const _listingAndroidOptions = AndroidOptions(resetOnError: false);
}

/// Keys for values that must be stored in the platform-backed secure
/// store (iOS Keychain, Android Keystore-backed ciphers).
///
/// Each enum value carries an explicit [key] string, so renaming an enum
/// value does not change the stored key.
///
/// [oidcIdToken] and [accessTokenExpiresAt] are used only in an `oidc`
/// build. The OIDC ID token has its own name so it cannot be confused
/// with [jwtToken], which holds the bearer. The
/// expiry is stored with [encodeAccessTokenExpiry] and read with
/// [readAccessTokenExpiry].
enum SecureStorageKeys {
  jwtToken('jwtToken'),
  refreshToken('refreshToken'),
  oidcIdToken('oidcIdToken'),
  accessTokenExpiresAt('accessTokenExpiresAt');

  const SecureStorageKeys(this.key);

  final String key;
}

/// The stored form of an access token expiry: milliseconds since the epoch in UTC, as a decimal string.
String encodeAccessTokenExpiry(DateTime expiresAt) => expiresAt.toUtc().millisecondsSinceEpoch.toString();

/// Reads an expiry stored by [encodeAccessTokenExpiry] as a UTC [DateTime]; null when none is stored.
///
/// Throws [FormatException] when [stored] is not an integer.
DateTime? readAccessTokenExpiry(String? stored) {
  if (stored == null) return null;
  return DateTime.fromMillisecondsSinceEpoch(int.parse(stored), isUtc: true);
}
