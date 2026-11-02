import 'package:flutter/foundation.dart';
import 'package:libredb_mobile/infrastructure/storage/secure_storage.dart';
import 'package:libredb_mobile/shared/models/session_target.dart';

/// Seeds a signed-in session straight into secure storage, so the on-device **local twin** lands on the connection
/// list without driving the Keycloak Custom Tab (which `integration_test` cannot reach). It is the `main_local`-only
/// counterpart of [MockSignInDependencies], which does the same for the mock twin; see the on-device test
/// architecture spec.
///
/// Debug builds only. [seedInto] throws in a profile or release build, and only `main_local.dart` and the tests
/// reference it (`test/architecture/debug_session_seed_isolation_test.dart`), so no store build can carry it.
///
/// **How the token stays valid.** The seeded access token comes from a one-time host sign-in and is minutes old by the
/// time a build finishes, so it is seeded *already expired*. The still-valid refresh token rides along, and
/// `SsoSessionStartup` refreshes the access token at startup from it — the same rotation the app uses for any expired
/// session. So the seed never needs to call Keycloak itself.
class DebugSessionSeed {
  const DebugSessionSeed({
    required this.target,
    required this.accessToken,
    required this.refreshToken,
    this.oidcIdToken,
  });

  /// The backend the seeded session belongs to.
  final SessionTarget target;

  /// The bearer Studio (or Platform) accepts; stored under [SecureStorageKeys.jwtToken]. Seeded already expired.
  final String accessToken;

  /// The refresh token the startup rotation exchanges for a fresh access token; without it the seed cannot survive.
  final String refreshToken;

  /// The provider's ID token, stored under [SecureStorageKeys.oidcIdToken]; optional.
  final String? oidcIdToken;

  /// Builds a seed from the raw `--dart-define` values, or null when `SEED_SESSION` is off.
  ///
  /// Throws [ArgumentError] when enabled without an access token or without a refresh token: a seed without a refresh
  /// token cannot outlive the build, so it is a configuration error rather than a silently dead session. An unreadable
  /// [target] defaults to Studio.
  @visibleForTesting
  static DebugSessionSeed? parse({
    required bool enabled,
    required String target,
    required String accessToken,
    required String refreshToken,
    required String oidcIdToken,
  }) {
    if (!enabled) return null;
    if (accessToken.isEmpty) throw ArgumentError('SEED_SESSION needs a SEED_ACCESS_TOKEN to seed');
    if (refreshToken.isEmpty) {
      throw ArgumentError('SEED_SESSION needs a SEED_REFRESH_TOKEN; the access token is seeded expired');
    }
    return DebugSessionSeed(
      target: SessionTarget.fromStoredValue(target) ?? SessionTarget.studio,
      accessToken: accessToken,
      refreshToken: refreshToken,
      oidcIdToken: oidcIdToken.isEmpty ? null : oidcIdToken,
    );
  }

  /// The seed read from this build's `--dart-define`s, or null when `SEED_SESSION` is off.
  static DebugSessionSeed? fromEnvironment() => parse(
    enabled: const bool.fromEnvironment('SEED_SESSION'),
    target: const String.fromEnvironment('SEED_SESSION_TARGET', defaultValue: 'studio'),
    accessToken: const String.fromEnvironment('SEED_ACCESS_TOKEN'),
    refreshToken: const String.fromEnvironment('SEED_REFRESH_TOKEN'),
    oidcIdToken: const String.fromEnvironment('SEED_ID_TOKEN'),
  );

  /// Seeds into the device's real secure storage. The `main_local` entry point calls this; [seedInto] takes an
  /// [ISecureStorage] for the tests. Keeping the adapter here leaves `main_local` free of a secure-store import, which
  /// the per-account data registry (`test/architecture/user_data_registry_test.dart`) would otherwise flag.
  Future<void> seed() => seedInto(FlutterSecureStorageAdapter());

  /// Writes the session into [storage] in the same key order [AuthSessionRepository.persist] uses — the target first,
  /// so a process killed mid-seed leaves a target without a token, which restores as signed out. The expiry is set to
  /// the epoch, so the stored access token always reads as expired and the startup rotation replaces it.
  Future<void> seedInto(ISecureStorage storage) async {
    if (!kDebugMode) throw StateError('The debug session seed runs only in a debug build');
    await storage.write(SecureStorageKeys.sessionTarget.key, target.storedValue);
    await storage.write(SecureStorageKeys.jwtToken.key, accessToken);
    await storage.write(SecureStorageKeys.refreshToken.key, refreshToken);
    if (oidcIdToken != null) await storage.write(SecureStorageKeys.oidcIdToken.key, oidcIdToken!);
    await storage.write(
      SecureStorageKeys.accessTokenExpiresAt.key,
      encodeAccessTokenExpiry(DateTime.fromMillisecondsSinceEpoch(0, isUtc: true)),
    );
  }

  /// Leaves the tokens out: this object carries an access and a refresh token, which a log line, the dev console or a
  /// Sentry event would otherwise print (`test/architecture/credential_to_string_test.dart`).
  @override
  String toString() => 'DebugSessionSeed(target: ${target.storedValue})';
}
