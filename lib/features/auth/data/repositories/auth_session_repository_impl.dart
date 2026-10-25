import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:libredb_mobile/core/logging/app_logger.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/auth/domain/entities/auth_session.dart';
import 'package:libredb_mobile/features/auth/domain/repositories/auth_session_repository.dart';
import 'package:libredb_mobile/infrastructure/cache/cache_storage.dart';
import 'package:libredb_mobile/infrastructure/cache/shared_prefs_cache_storage.dart';
import 'package:libredb_mobile/infrastructure/storage/local_storage.dart';
import 'package:libredb_mobile/infrastructure/storage/secure_storage.dart';
import 'package:libredb_mobile/infrastructure/storage/session_generation.dart';
import 'package:libredb_mobile/infrastructure/storage/temporary_share_files.dart';
import 'package:libredb_mobile/shared/models/session_target.dart';

/// Persistence-layer implementation of [IAuthSessionRepository].
///
/// Writes the session's target and tokens to [ISecureStorage] (Keychain / EncryptedSharedPreferences).
///
/// The store supports no transactions, so atomicity is emulated: writes
/// happen in order, and on any failure every key that was written during
/// this call is restored to its pre-call value (or deleted if there was
/// none) before the failure is reported. Callers therefore never observe a
/// half-written session.
///
/// [clear] removes what belongs to the session: its target and tokens, every [StorageKeys] value of
/// [StorageScope.session], the HTTP responses cached in [ICacheStorage] and the files the share sheet got
/// ([TemporaryShareFiles]). Device preferences such as the language and theme stay.
///
/// The session also owns [SecureStorageKeys.oidcIdToken] and [SecureStorageKeys.accessTokenExpiresAt]: [persist] writes
/// them after the refresh token, and the rollback and [clear] cover them.
///
/// [SecureStorageKeys.sessionTarget] is the first write of [persist], before the access token, so a process killed
/// after it leaves a target without a token in an empty store, which restores as signed out, never a new token next
/// to a missing target. The rollback and [clear] cover it like the tokens. A token refresh rewrites only the tokens,
/// so the target written at sign-in stays for the whole session.
class AuthSessionRepository implements IAuthSessionRepository {
  AuthSessionRepository({
    required this._secureStorage,
    AppLocalStorage? storage,
    ICacheStorage? cacheStorage,
    TemporaryShareFiles? shareFiles,
  }) : _storage = storage ?? AppLocalStorage(),
       _cacheStorage = cacheStorage ?? SharedPrefsCacheStorage(),
       _shareFiles = shareFiles ?? TemporaryShareFiles();

  static final _log = AppLogger.getLogger('AuthSessionRepository');

  final ISecureStorage _secureStorage;
  final AppLocalStorage _storage;
  final ICacheStorage _cacheStorage;
  final TemporaryShareFiles _shareFiles;

  @override
  Future<Result<void>> persist(AuthSession session) async {
    final mutatedSecure = <SecureStorageKeys>{};
    // Snapshot pre-persist values so rollback restores
    // them — including the "delete stale refreshToken when the new
    // session has none" path, where the delete itself is the mutation
    // we need to be able to undo. The snapshot itself must live inside
    // the try block: ISecureStorage.read can throw on platform /
    // decryption failure, and the contract is that persist always
    // returns a Result — never propagates a raw exception.
    String? priorTarget;
    String? priorJwt;
    String? priorRefresh;
    String? priorOidcIdToken;
    String? priorExpiry;
    try {
      priorTarget = await _secureStorage.read(SecureStorageKeys.sessionTarget.key);
      priorJwt = await _secureStorage.read(SecureStorageKeys.jwtToken.key);
      priorRefresh = await _secureStorage.read(SecureStorageKeys.refreshToken.key);
      priorOidcIdToken = await _secureStorage.read(SecureStorageKeys.oidcIdToken.key);
      priorExpiry = await _secureStorage.read(SecureStorageKeys.accessTokenExpiresAt.key);

      // Record the key as mutated BEFORE the await so that if the
      // adapter throws after partially mutating platform state, the
      // rollback path still knows to restore it. If the write throws
      // cleanly (state unchanged), the rollback is a no-op against
      // the snapshot (write same value back, or delete an absent key).
      // The target goes first, see the class comment.
      await _writeOrDelete(SecureStorageKeys.sessionTarget, session.target.storedValue, mutatedSecure);
      mutatedSecure.add(SecureStorageKeys.jwtToken);
      await _secureStorage.write(SecureStorageKeys.jwtToken.key, session.idToken);
      // Owner-of-keys contract: a session without a refresh token must
      // not inherit one from a previous login. Treat null AND empty
      // string equivalently — TokenRefreshInterceptor reads
      // `refreshToken.isEmpty` as "absent", so persisting an empty
      // string here would leave the key present but unusable.
      mutatedSecure.add(SecureStorageKeys.refreshToken);
      final hasRefresh = session.refreshToken != null && session.refreshToken!.isNotEmpty;
      if (hasRefresh) {
        await _secureStorage.write(SecureStorageKeys.refreshToken.key, session.refreshToken!);
      } else {
        await _secureStorage.delete(SecureStorageKeys.refreshToken.key);
      }
      // Same owner-of-keys contract: a session without an ID token or an expiry must not inherit the previous one.
      final expiresAt = session.accessTokenExpiresAt;
      await _writeOrDelete(SecureStorageKeys.oidcIdToken, session.oidcIdToken, mutatedSecure);
      await _writeOrDelete(
        SecureStorageKeys.accessTokenExpiresAt,
        expiresAt == null ? null : encodeAccessTokenExpiry(expiresAt),
        mutatedSecure,
      );
      _log.info('persist: session written ({} secure)', [mutatedSecure.length]);
      return const Success(null);
    } catch (e) {
      _log.error('persist failed after {} secure mutations; rolling back: {}', [mutatedSecure.length, e]);
      await _rollback(
        mutatedSecure: mutatedSecure,
        priorTarget: priorTarget,
        priorJwt: priorJwt,
        priorRefresh: priorRefresh,
        priorOidcIdToken: priorOidcIdToken,
        priorExpiry: priorExpiry,
      );
      return Failure(UnknownError('Session persistence failed: $e'));
    }
  }

  /// The target is snapshot, written and, on a failed write, restored, like the target of [persist]. The session
  /// generation is checked before the snapshot and again once the write has ended: a wipe that ran meanwhile may have
  /// run before the write landed, so the target this call wrote is deleted again, and any other value stays.
  @override
  Future<Result<void>> persistTarget(SessionTarget target, {required int generation}) async {
    if (SessionGeneration.hasEnded(generation)) {
      _log.warn('persistTarget: the session ended before the target was written, so nothing is written');
      return const Failure(UnknownError('The session ended before its target was written'));
    }
    final key = SecureStorageKeys.sessionTarget.key;
    final value = target.storedValue;
    String? prior;
    try {
      prior = await _secureStorage.read(key);
    } catch (e) {
      _log.error('persistTarget: reading the stored target failed, so nothing is written: {}', [e]);
      return Failure(UnknownError('Reading the session target failed: $e'));
    }
    try {
      await _secureStorage.write(key, value);
    } catch (e) {
      _log.error('persistTarget: writing the target failed; restoring the prior one: {}', [e]);
      try {
        if (prior == null) {
          await _secureStorage.delete(key);
        } else {
          await _secureStorage.write(key, prior);
        }
      } catch (e) {
        _log.warn('persistTarget: restoring the prior target failed: {}', [e]);
      }
      return Failure(UnknownError('Writing the session target failed: $e'));
    }
    if (SessionGeneration.hasEnded(generation)) {
      _log.warn('persistTarget: the session ended while the target was written, so it is taken back');
      try {
        if (await _secureStorage.read(key) == value) await _secureStorage.delete(key);
      } catch (e) {
        _log.error('persistTarget: taking the target back failed: {}', [e]);
      }
      return const Failure(UnknownError('The session ended while its target was written'));
    }
    _log.info('persistTarget: target {} written', [target.name]);
    return const Success(null);
  }

  /// The whole wipe runs inside [SessionGeneration.wipe], so a token refresh on its way when the session ends does not
  /// leave the rotated tokens stored: it drops them, or takes back what it stored when the wipe ran meanwhile.
  @override
  Future<Result<void>> clear() => SessionGeneration.wipe(_clear);

  Future<Result<void>> _clear() async {
    // Best-effort across BOTH backends: a throw on the first secure
    // delete must not skip the second key or the local clear. Any
    // leftover token would let AuthInterceptor re-attach it on the
    // next request and silently defeat a clear/logout.
    final errors = <String>[];
    try {
      await _secureStorage.delete(SecureStorageKeys.sessionTarget.key);
    } catch (e) {
      errors.add('sessionTarget: $e');
    }
    try {
      await _secureStorage.delete(SecureStorageKeys.jwtToken.key);
    } catch (e) {
      errors.add('jwt: $e');
    }
    try {
      await _secureStorage.delete(SecureStorageKeys.refreshToken.key);
    } catch (e) {
      errors.add('refresh: $e');
    }
    try {
      await _secureStorage.delete(SecureStorageKeys.oidcIdToken.key);
    } catch (e) {
      errors.add('oidcIdToken: $e');
    }
    try {
      await _secureStorage.delete(SecureStorageKeys.accessTokenExpiresAt.key);
    } catch (e) {
      errors.add('accessTokenExpiresAt: $e');
    }
    // Only the session keys: the device preferences, such as the language and theme, stay for whoever signs in next.
    final sessionKeys = StorageKeys.values.where((key) => key.scope == StorageScope.session).toList();
    for (final key in sessionKeys) {
      try {
        if (!await _storage.remove(key.key)) errors.add('${key.key}: remove refused');
      } catch (e) {
        errors.add('${key.key}: $e');
      }
    }
    // Cached GET responses, such as /connections/managed, are this user's data too.
    try {
      await _cacheStorage.clear();
    } catch (e) {
      errors.add('cache: $e');
    }
    // A source shared as a file is this user's data too. The error's type only: its message holds the file's path,
    // which names the object.
    try {
      await _shareFiles.clear();
    } catch (e) {
      errors.add('share files: ${e.runtimeType}');
    }
    if (errors.isNotEmpty) {
      final msg = errors.join('; ');
      _log.error('clear: partial failures: {}', [msg]);
      return Failure(UnknownError('Session clear failed: $msg'));
    }
    _log.info('clear: target, tokens, {} session keys, cached responses and share files removed', [sessionKeys.length]);
    return const Success(null);
  }

  /// Writes [value] under [key], or deletes [key] when [value] is null. The key is recorded as mutated before the
  /// call, as for the tokens, so a call that fails after changing the platform store is still rolled back.
  Future<void> _writeOrDelete(SecureStorageKeys key, String? value, Set<SecureStorageKeys> mutated) async {
    mutated.add(key);
    if (value != null) {
      await _secureStorage.write(key.key, value);
    } else {
      await _secureStorage.delete(key.key);
    }
  }

  Future<void> _rollback({
    required Set<SecureStorageKeys> mutatedSecure,
    required String? priorTarget,
    required String? priorJwt,
    required String? priorRefresh,
    required String? priorOidcIdToken,
    required String? priorExpiry,
  }) async {
    for (final key in mutatedSecure) {
      try {
        final prior = switch (key) {
          SecureStorageKeys.sessionTarget => priorTarget,
          SecureStorageKeys.jwtToken => priorJwt,
          SecureStorageKeys.refreshToken => priorRefresh,
          SecureStorageKeys.oidcIdToken => priorOidcIdToken,
          SecureStorageKeys.accessTokenExpiresAt => priorExpiry,
        };
        if (prior == null) {
          await _secureStorage.delete(key.key);
        } else {
          await _secureStorage.write(key.key, prior);
        }
      } catch (e) {
        _log.warn('secure rollback failed for {}: {}', [key.key, e]);
      }
    }
  }
}
