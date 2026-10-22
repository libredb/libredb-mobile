import 'dart:async';
import 'dart:convert';

import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/auth/data/repositories/sso_sign_out_auth_repository.dart';
import 'package:libredb_mobile/features/auth/data/services/sso_session_startup_impl.dart';
import 'package:libredb_mobile/features/auth/domain/entities/auth_entity.dart';
import 'package:libredb_mobile/features/auth/domain/repositories/auth_repository.dart';
import 'package:libredb_mobile/features/auth/domain/repositories/studio_identity_repository.dart';
import 'package:libredb_mobile/features/auth/domain/services/sso_auto_redirect_gate.dart';
import 'package:libredb_mobile/infrastructure/auth/oidc/oidc_client.dart';
import 'package:libredb_mobile/infrastructure/config/auth_config.dart';
import 'package:libredb_mobile/infrastructure/http/token_rotation.dart';
import 'package:libredb_mobile/infrastructure/storage/secure_storage.dart';
import 'package:libredb_mobile/shared/models/studio_identity.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mock_classes.dart';

/// The secure store of the session in memory, which records each read in [calls] and throws on a read when
/// [readError] is set.
class _RecordingSecureStorage implements ISecureStorage {
  _RecordingSecureStorage(this.calls);

  final List<String> calls;
  final values = <String, String>{};
  Object? readError;

  @override
  Future<String?> read(String key) async {
    calls.add('read $key');
    final error = readError;
    if (error != null) throw error;
    return values[key];
  }

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<void> deleteAll() async => values.clear();
}

/// The local logout, which records itself in [calls], wipes [storage] and answers [logoutResult].
class _RecordingAuthRepository implements IAuthRepository {
  _RecordingAuthRepository(this.calls, this.storage);

  final List<String> calls;
  final _RecordingSecureStorage storage;
  Result<void> logoutResult = const Success(null);

  @override
  Future<Result<void>> logout() async {
    calls.add('wipe');
    await storage.deleteAll();
    return logoutResult;
  }

  @override
  Future<Result<AuthTokenEntity>> authenticate(AuthCredentialsEntity userJWT) =>
      throw UnimplementedError('a logout never authenticates');

  @override
  Future<Result<void>> sendOtp(SendOtpEntity request) => throw UnimplementedError('a logout never sends an OTP');

  @override
  Future<Result<AuthTokenEntity>> verifyOtp(VerifyOtpEntity request) =>
      throw UnimplementedError('a logout never verifies an OTP');
}

/// Ends the provider session with [outcome], recording the hint of each call in [calls].
class _FakeOidcClient implements IOidcClient {
  _FakeOidcClient(this.calls);

  final List<String> calls;
  OidcLogoutOutcome outcome = const ProviderSessionEnded();
  final hints = <String?>[];

  @override
  Future<OidcLogoutOutcome> endProviderSession({String? idTokenHint}) async {
    calls.add('endProviderSession');
    hints.add(idTokenHint);
    return outcome;
  }

  @override
  Future<OidcSignInOutcome> signIn() => throw UnimplementedError('a logout never signs in');

  @override
  Future<TokenRotationResult> refresh({
    required String refreshToken,
    required String idToken,
    required String accessToken,
    required DateTime accessTokenExpiresAt,
  }) => throw UnimplementedError('a logout never refreshes');
}

/// Ends the provider session when the test completes [logout], as a browser flow does once the provider answers;
/// records each call in [calls].
class _PendingLogoutClient extends _FakeOidcClient {
  _PendingLogoutClient(super.calls);

  final logout = Completer<OidcLogoutOutcome>();

  @override
  Future<OidcLogoutOutcome> endProviderSession({String? idTokenHint}) {
    calls.add('endProviderSession');
    hints.add(idTokenHint);
    return logout.future;
  }
}

/// Records the sign-out at Studio through [record], noting each call in [calls].
class _RecordingStudioIdentity implements IStudioIdentityRepository {
  _RecordingStudioIdentity(this.calls);

  final List<String> calls;
  Future<Result<void>> Function() record = () async => const Success(null);

  @override
  Future<Result<void>> recordSignOut() {
    calls.add('recordSignOut');
    return record();
  }

  @override
  Future<Result<StudioIdentity>> fetch() => throw UnimplementedError('a logout never reads the identity');
}

OidcSettings _settings({bool logoutHint = true}) =>
    OidcSettings(issuer: Uri.parse('https://id.example.com/realms/demo'), clientId: 'app', logoutHint: logoutHint);

/// An unsigned JWT whose payload carries [exp], in seconds since the epoch.
String _jwt({required int exp}) {
  String part(Map<String, Object> json) => base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');
  return '${part({'alg': 'none'})}.${part({'sub': 'subject-1', 'exp': exp})}.';
}

final _now = DateTime.utc(2026, 10, 22, 12);

/// The read of the stored access token expiry, with which every sign-out starts.
final _readExpiry = 'read ${SecureStorageKeys.accessTokenExpiresAt.key}';

void main() {
  late List<String> calls;
  late _RecordingSecureStorage storage;
  late _RecordingAuthRepository inner;
  late _FakeOidcClient client;
  late _RecordingStudioIdentity studioIdentity;
  late MockTokenRotation rotation;
  late MockIAuthSessionRepository sessionRepository;

  /// The startup step's refresh of an expired access token, over the session store of the test.
  SsoSessionStartup sessionRefresh() => SsoSessionStartup(
    rotation: rotation,
    secureStorage: storage,
    sessionRepository: sessionRepository,
    gate: SsoAutoRedirectGate(),
    now: () => _now,
  );

  SsoSignOutAuthRepository repository({bool logoutHint = true}) => SsoSignOutAuthRepository(
    inner: inner,
    client: client,
    secureStorage: storage,
    settings: _settings(logoutHint: logoutHint),
    studioIdentity: studioIdentity,
    sessionRefresh: sessionRefresh(),
    studioSignOutTimeout: const Duration(milliseconds: 50),
  );

  setUp(() {
    calls = [];
    storage = _RecordingSecureStorage(calls);
    inner = _RecordingAuthRepository(calls, storage);
    client = _FakeOidcClient(calls);
    studioIdentity = _RecordingStudioIdentity(calls);
    rotation = MockTokenRotation();
    sessionRepository = MockIAuthSessionRepository();
    when(() => sessionRepository.clear()).thenAnswer((_) async {
      calls.add('clear session');
      await storage.deleteAll();
      return const Success(null);
    });
    storage.values[SecureStorageKeys.oidcIdToken.key] = 'stored-id-token';
  });

  group('SsoSignOutAuthRepository.logout', () {
    test('records the sign-out at Studio, reads the ID token before the wipe, then ends the provider session with it '
        'as the hint', () async {
      final result = await repository().logout();

      expect(result, const Success<void>(null));
      expect(calls, [
        _readExpiry,
        'recordSignOut',
        'read ${SecureStorageKeys.oidcIdToken.key}',
        'wipe',
        'endProviderSession',
      ]);
      expect(client.hints, ['stored-id-token']);
    });

    // Studio's audit line is a record, not a step of the sign-out: an unreachable or failing Studio must not keep the
    // user signed in.
    group('signs out when recording the sign-out at Studio', () {
      final outcomes = <String, Future<Result<void>> Function()>{
        'fails': () async => const Failure(ServerError('Internal Server Error')),
        'throws': () async => throw StateError('unexpected'),
        'hangs past the timeout': () => Completer<Result<void>>().future,
      };
      for (final MapEntry(key: name, value: record) in outcomes.entries) {
        test(name, () async {
          studioIdentity.record = record;

          final result = await repository().logout();

          expect(result, const Success<void>(null));
          expect(calls, [
            _readExpiry,
            'recordSignOut',
            'read ${SecureStorageKeys.oidcIdToken.key}',
            'wipe',
            'endProviderSession',
          ]);
          expect(storage.values, isEmpty);
        });
      }
    });

    // Studio writes no audit line for an expired bearer and still answers 200, so the token is refreshed first.
    group('with an access token that has expired', () {
      setUp(() {
        storage.values
          ..[SecureStorageKeys.jwtToken.key] = 'expired-access-token'
          ..[SecureStorageKeys.refreshToken.key] = 'stored-refresh-token'
          ..[SecureStorageKeys.accessTokenExpiresAt.key] = encodeAccessTokenExpiry(
            _now.subtract(const Duration(minutes: 5)),
          );
      });

      test('refreshes it, records the sign-out with the new token, then wipes', () async {
        when(() => rotation.rotate('stored-refresh-token')).thenAnswer((_) async {
          calls.add('rotate');
          return TokensRotated(
            accessToken: 'fresh-access-token',
            refreshToken: 'fresh-refresh-token',
            accessTokenExpiresAt: _now.add(const Duration(minutes: 1)),
          );
        });
        String? bearerAtRecord;
        studioIdentity.record = () async {
          bearerAtRecord = storage.values[SecureStorageKeys.jwtToken.key];
          return const Success(null);
        };

        final result = await repository().logout();

        expect(result, const Success<void>(null));
        expect(calls.where((call) => !call.startsWith('read ')), [
          'rotate',
          'recordSignOut',
          'wipe',
          'endProviderSession',
        ]);
        expect(bearerAtRecord, 'fresh-access-token');
        expect(storage.values, isEmpty);
      });

      test('records nothing when the provider refuses the refresh, and still signs out', () async {
        when(() => rotation.rotate('stored-refresh-token')).thenAnswer((_) async {
          calls.add('rotate');
          return const RotationRefused();
        });

        final result = await repository().logout();

        expect(result, const Success<void>(null));
        expect(calls.where((call) => !call.startsWith('read ')), [
          'rotate',
          'clear session',
          'wipe',
          'endProviderSession',
        ]);
      });

      test('signs out when the refresh does not answer within the timeout', () async {
        when(() => rotation.rotate('stored-refresh-token')).thenAnswer((_) {
          calls.add('rotate');
          return Completer<TokenRotationResult>().future;
        });

        final result = await repository().logout();

        expect(result, const Success<void>(null));
        expect(calls.where((call) => !call.startsWith('read ')), ['rotate', 'wipe', 'endProviderSession']);
        expect(storage.values, isEmpty);
      });
    });

    test('sends the record without a refresh while the access token is valid', () async {
      storage.values[SecureStorageKeys.accessTokenExpiresAt.key] = encodeAccessTokenExpiry(
        _now.add(const Duration(minutes: 1)),
      );

      await repository().logout();

      expect(calls.where((call) => !call.startsWith('read ')), ['recordSignOut', 'wipe', 'endProviderSession']);
      verifyNever(() => rotation.rotate(any()));
    });

    test('sends no hint when OIDC_LOGOUT_HINT is off', () async {
      await repository(logoutHint: false).logout();

      expect(client.hints, [null]);
      expect(calls.last, 'endProviderSession');
    });

    // Keycloak gives the ID token the access token's short life, and accepts an expired one at end_session.
    test('sends an expired ID token as the hint, with no expiry check of its own', () async {
      final expired = _jwt(exp: DateTime.utc(2020).millisecondsSinceEpoch ~/ 1000);
      storage.values[SecureStorageKeys.oidcIdToken.key] = expired;

      await repository().logout();

      expect(client.hints, [expired]);
    });

    test('sends no hint when no ID token is stored', () async {
      storage.values.clear();

      await repository().logout();

      expect(client.hints, [null]);
    });

    // An unreadable store also hides the access token expiry, so the refresh ends the session and Studio gets no record.
    test('sends no hint when the store cannot be read, and still wipes and ends the provider session', () async {
      storage.readError = Exception('keystore locked');

      final result = await repository().logout();

      expect(result, const Success<void>(null));
      expect(calls, [
        _readExpiry,
        'clear session',
        'read ${SecureStorageKeys.oidcIdToken.key}',
        'wipe',
        'endProviderSession',
      ]);
      expect(client.hints, [null]);
    });

    group('answers', () {
      const wipeFailure = Failure<void>(UnknownError('Session clear failed: jwtToken'));

      for (final (name, outcome) in <(String, OidcLogoutOutcome)>[
        ('the provider session ended', const ProviderSessionEnded()),
        ('the provider has no logout', const NoProviderLogout()),
      ]) {
        test('the local result when $name', () async {
          client.outcome = outcome;
          expect(await repository().logout(), const Success<void>(null));

          inner.logoutResult = wipeFailure;
          expect(await repository().logout(), wipeFailure);
        });
      }

      test('the incomplete provider logout when the provider logout failed after a clean wipe', () async {
        client.outcome = const ProviderLogoutFailed();

        final result = await repository().logout();

        expect(
          result,
          isA<Failure<void>>().having(
            (failure) => failure.error,
            'error',
            isA<AuthError>().having((error) => error.code, 'code', AppErrorCode.authOidcLogoutIncomplete.key),
          ),
        );
      });

      // The data left on this device is the more serious of the two, and the user can only be told one of them.
      test('the wipe failure when both the wipe and the provider logout failed', () async {
        client.outcome = const ProviderLogoutFailed();
        inner.logoutResult = wipeFailure;

        expect(await repository().logout(), wipeFailure);
      });
    });
  });

  // The provider logout waits for the browser and for the provider.
  group('SsoSignOutAuthRepository.signOut', () {
    late _PendingLogoutClient pending;

    SsoSignOutAuthRepository pendingRepository() => SsoSignOutAuthRepository(
      inner: inner,
      client: pending,
      secureStorage: storage,
      settings: _settings(),
      studioIdentity: studioIdentity,
      sessionRefresh: sessionRefresh(),
    );

    setUp(() => pending = _PendingLogoutClient(calls));

    test('answers once the wipe has returned, with the provider logout started and not yet ended', () async {
      final signedOut = await pendingRepository().signOut();
      var providerLogoutEnded = false;
      unawaited(signedOut.providerLogout.then((_) => providerLogoutEnded = true));
      await Future<void>.delayed(Duration.zero);

      expect(signedOut.cleared, const Success<void>(null));
      expect(calls, [
        _readExpiry,
        'recordSignOut',
        'read ${SecureStorageKeys.oidcIdToken.key}',
        'wipe',
        'endProviderSession',
      ]);
      expect(pending.hints, ['stored-id-token']);
      expect(providerLogoutEnded, isFalse);

      pending.logout.complete(const ProviderSessionEnded());
      expect(await signedOut.providerLogout, const Success<void>(null));
    });

    test('answers the wipe failure as cleared', () async {
      const wipeFailure = Failure<void>(UnknownError('Session clear failed: jwtToken'));
      inner.logoutResult = wipeFailure;

      final signedOut = await pendingRepository().signOut();

      expect(signedOut.cleared, wipeFailure);
      pending.logout.complete(const ProviderSessionEnded());
      await signedOut.providerLogout;
    });

    test('ends the provider logout with the incomplete provider logout when it failed', () async {
      final signedOut = await pendingRepository().signOut();
      pending.logout.complete(const ProviderLogoutFailed());

      expect(
        await signedOut.providerLogout,
        isA<Failure<void>>().having(
          (failure) => failure.error,
          'error',
          isA<AuthError>().having((error) => error.code, 'code', AppErrorCode.authOidcLogoutIncomplete.key),
        ),
      );
    });

    test('ends the provider logout with success when the provider has no logout', () async {
      final signedOut = await pendingRepository().signOut();
      pending.logout.complete(const NoProviderLogout());

      expect(await signedOut.providerLogout, const Success<void>(null));
    });
  });

  group('SsoSignOutAuthRepository delegates the password sign-in to the repository it wraps', () {
    late MockIAuthRepository wrapped;
    late SsoSignOutAuthRepository delegating;

    setUp(() {
      wrapped = MockIAuthRepository();
      delegating = SsoSignOutAuthRepository(
        inner: wrapped,
        client: client,
        secureStorage: storage,
        settings: _settings(),
        studioIdentity: studioIdentity,
        sessionRefresh: sessionRefresh(),
      );
    });

    test('authenticate', () async {
      const credentials = AuthCredentialsEntity(username: 'admin', password: 'password');
      const token = Success(AuthTokenEntity(idToken: 'token'));
      when(() => wrapped.authenticate(credentials)).thenAnswer((_) async => token);

      expect(await delegating.authenticate(credentials), token);
    });

    test('sendOtp', () async {
      const request = SendOtpEntity(email: 'user@example.com');
      when(() => wrapped.sendOtp(request)).thenAnswer((_) async => const Success(null));

      expect(await delegating.sendOtp(request), const Success<void>(null));
    });

    test('verifyOtp', () async {
      const request = VerifyOtpEntity(email: 'user@example.com', otp: '123456');
      const token = Success(AuthTokenEntity(idToken: 'token'));
      when(() => wrapped.verifyOtp(request)).thenAnswer((_) async => token);

      expect(await delegating.verifyOtp(request), token);
    });
  });
}
