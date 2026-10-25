import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:fake_async/fake_async.dart';
import 'package:libredb_mobile/app/session/session_cubit.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/features/auth/domain/repositories/auth_session_repository.dart';
import 'package:libredb_mobile/features/auth/domain/entities/auth_session.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/auth/data/services/sso_session_startup_impl.dart';
import 'package:libredb_mobile/features/auth/domain/services/sso_auto_redirect_gate.dart';
import 'package:libredb_mobile/features/auth/domain/services/sso_session_startup.dart';
import 'package:libredb_mobile/infrastructure/storage/local_storage.dart';
import 'package:libredb_mobile/infrastructure/storage/secure_storage.dart';
import 'package:libredb_mobile/shared/models/session_target.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart' show Level, Logger, OutputEvent;
import 'package:mocktail/mocktail.dart';

import '../../mocks/mock_classes.dart';

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

/// Holds a token for every key but cannot delete one.
class _DeleteThrowsSecureStorage implements ISecureStorage {
  @override
  Future<String?> read(String key) async => 'stored-$key';
  @override
  Future<void> write(String key, String value) async {}
  @override
  Future<void> delete(String key) async => throw StateError('boom on delete $key');
  @override
  Future<void> deleteAll() async => throw StateError('boom on deleteAll');

  @override
  Future<Set<String>> keys() => throw UnimplementedError('not used by this test');
}

/// Secure storage whose read of a key in [answers] waits for that completer, and whose other reads answer from [store],
/// as a slow storage that read the stored session before a sign-in replaced it.
class _SlowSecureStorage implements ISecureStorage {
  final store = <String, String>{};
  final answers = <String, Completer<String?>>{};
  @override
  Future<String?> read(String key) => answers[key]?.future ?? Future.value(store[key]);
  @override
  Future<void> write(String key, String value) async => store[key] = value;
  @override
  Future<void> delete(String key) async => store.remove(key);
  @override
  Future<void> deleteAll() async => store.clear();

  @override
  Future<Set<String>> keys() => throw UnimplementedError('not used by this test');
}

/// A session repository that counts its clears, each of which finishes only once [release] completes.
class _HeldClearSessionRepository implements IAuthSessionRepository {
  final release = Completer<void>();
  int clears = 0;

  @override
  Future<Result<void>> clear() async {
    clears++;
    await release.future;
    return const Success(null);
  }

  @override
  Future<Result<void>> persist(AuthSession session) => throw UnimplementedError('a restore never persists');
}

/// A startup step that answers [answer], and counts the times the cubit gave up on it.
class _FakeSsoStartup implements ISsoSessionStartup {
  _FakeSsoStartup(this.answer);

  final Future<SsoStartupResult> answer;
  int giveUps = 0;

  @override
  Future<SsoStartupResult> run() => answer;

  @override
  void giveUp() => giveUps++;
}

/// The targets of a build without a Platform target.
const _studioOnly = {SessionTarget.studio};

/// The targets of a build with a Platform target.
const _bothTargets = {SessionTarget.studio, SessionTarget.platform};

/// A startup step that keeps the stored session, so restore reads that session as it is.
_FakeSsoStartup _storedSessionStep() => _FakeSsoStartup(Future.value(const SsoStartupUseStoredSession()));

/// JWT with `exp` claim already in the past. Built statically so tests
/// can be const-friendly. Payload: `{"sub":"u","exp":1}` (1970-01-01).
const _expiredJwt = 'eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJ1IiwiZXhwIjoxfQ.signature';

void main() {
  group('SessionState — sealed hierarchy', () {
    test('SessionUnknown is the initial state, distinct from unauthenticated', () {
      const unknown = SessionUnknown();
      const unauthenticated = SessionUnauthenticated(reason: SessionExpiredReason.noToken);
      expect(unknown, isNot(equals(unauthenticated)), reason: 'unknown ≠ unauthenticated by type');
    });

    test('SessionAuthenticated equality is its target', () {
      expect(
        const SessionAuthenticated(target: SessionTarget.studio),
        const SessionAuthenticated(target: SessionTarget.studio),
      );
      expect(
        const SessionAuthenticated(target: SessionTarget.studio),
        isNot(const SessionAuthenticated(target: SessionTarget.platform)),
      );
    });

    test('SessionUnauthenticated equality includes the reason', () {
      const noToken = SessionUnauthenticated(reason: SessionExpiredReason.noToken);
      const expired = SessionUnauthenticated(reason: SessionExpiredReason.expired);
      expect(noToken, isNot(equals(expired)));
    });

    test('SessionUnauthenticated equality includes the sign-in error', () {
      const failed = SessionUnauthenticated(reason: SessionExpiredReason.signInFailed);
      const failedWithError = SessionUnauthenticated(
        reason: SessionExpiredReason.signInFailed,
        signInError: AppErrorCode.authOidcFailed,
      );
      expect(failed, isNot(equals(failedWithError)));
    });

    // A state without a sign-in error prints only its reason, as it did before the field existed.
    test('SessionUnauthenticated without a sign-in error prints only the reason', () {
      expect(
        const SessionUnauthenticated(reason: SessionExpiredReason.noToken).toString(),
        'SessionUnauthenticated(SessionExpiredReason.noToken)',
      );
    });

    test('SessionUnauthenticated with a sign-in error prints the reason and the error', () {
      expect(
        const SessionUnauthenticated(
          reason: SessionExpiredReason.signInFailed,
          signInError: AppErrorCode.authOidcFailed,
        ).toString(),
        'SessionUnauthenticated(SessionExpiredReason.signInFailed, AppErrorCode.authOidcFailed)',
      );
    });

    test('exhaustive switch covers all variants without a default', () {
      // Compiler-enforced exhaustiveness — if a new variant is added
      // without updating callers, the analyzer fails this build.
      String label(SessionState s) => switch (s) {
        SessionUnknown() => 'unknown',
        SessionAuthenticated() => 'authenticated',
        SessionUnauthenticated() => 'unauthenticated',
      };
      expect(label(const SessionUnknown()), 'unknown');
      expect(label(const SessionAuthenticated(target: SessionTarget.studio)), 'authenticated');
      expect(label(const SessionUnauthenticated()), 'unauthenticated');
    });
  });

  group('SessionCubit', () {
    test('initial state is SessionUnknown — distinguishable from unauthenticated', () {
      final cubit = SessionCubit(availableTargets: _studioOnly, ssoStartup: _storedSessionStep());
      expect(cubit.state, isA<SessionUnknown>());
      cubit.close();
    });

    blocTest<SessionCubit, SessionState>(
      'markAuthenticated emits SessionAuthenticated',
      build: () => SessionCubit(availableTargets: _studioOnly, ssoStartup: _storedSessionStep()),
      act: (cubit) => cubit.markAuthenticated(SessionTarget.studio),
      expect: () => [const SessionAuthenticated(target: SessionTarget.studio)],
    );

    blocTest<SessionCubit, SessionState>(
      'markLoggedOut emits SessionUnauthenticated with noToken reason by default',
      build: () => SessionCubit(availableTargets: _studioOnly, ssoStartup: _storedSessionStep()),
      seed: () => const SessionAuthenticated(target: SessionTarget.studio),
      act: (cubit) => cubit.markLoggedOut(),
      expect: () => [const SessionUnauthenticated(reason: SessionExpiredReason.noToken)],
    );

    blocTest<SessionCubit, SessionState>(
      'restore emits SessionUnauthenticated(noToken) when secure storage is empty',
      build: () => SessionCubit(
        availableTargets: _studioOnly,
        secureStorage: _MemorySecureStorage(),
        ssoStartup: _storedSessionStep(),
      ),
      act: (cubit) => cubit.restore(),
      expect: () => [const SessionUnauthenticated(reason: SessionExpiredReason.noToken)],
    );

    blocTest<SessionCubit, SessionState>(
      'restore emits SessionAuthenticated when secure storage has a token',
      build: () {
        final secure = _MemorySecureStorage();
        // Direct map write; the async `write` wrapper only exists to
        // satisfy ISecureStorage. Seeding synchronously avoids the
        // unawaited-write race the linter would otherwise flag.
        secure._store[SecureStorageKeys.jwtToken.key] = 'MOCK_TOKEN';
        return SessionCubit(availableTargets: _studioOnly, secureStorage: secure, ssoStartup: _storedSessionStep());
      },
      act: (cubit) => cubit.restore(),
      expect: () => [const SessionAuthenticated(target: SessionTarget.studio)],
    );

    blocTest<SessionCubit, SessionState>(
      'restore emits SessionUnauthenticated(storageError) when secure read throws',
      build: () => SessionCubit(
        availableTargets: _studioOnly,
        secureStorage: _ReadThrowsSecureStorage(),
        ssoStartup: _storedSessionStep(),
      ),
      act: (cubit) => cubit.restore(),
      expect: () => [const SessionUnauthenticated(reason: SessionExpiredReason.storageError)],
    );

    blocTest<SessionCubit, SessionState>(
      'refresh delegates to restore',
      build: () => SessionCubit(
        availableTargets: _studioOnly,
        secureStorage: _MemorySecureStorage(),
        ssoStartup: _storedSessionStep(),
      ),
      act: (cubit) => cubit.refresh(),
      expect: () => [const SessionUnauthenticated(reason: SessionExpiredReason.noToken)],
    );

    blocTest<SessionCubit, SessionState>(
      'markAuthenticated then markLoggedOut transitions correctly',
      build: () => SessionCubit(availableTargets: _studioOnly, ssoStartup: _storedSessionStep()),
      act: (cubit) {
        cubit.markAuthenticated(SessionTarget.studio);
        cubit.markLoggedOut();
      },
      expect: () => [
        const SessionAuthenticated(target: SessionTarget.studio),
        const SessionUnauthenticated(reason: SessionExpiredReason.noToken),
      ],
    );

    test('endSession logs an error and still ends the session when the stored session cannot be cleared', () async {
      final errors = <String>[];
      void recordError(OutputEvent event) {
        if (event.level == Level.error) errors.addAll(event.lines);
      }

      Logger.addOutputListener(recordError);
      addTearDown(() => Logger.removeOutputListener(recordError));
      final cubit = SessionCubit(
        availableTargets: _studioOnly,
        secureStorage: _DeleteThrowsSecureStorage(),
        ssoStartup: _storedSessionStep(),
      )..markAuthenticated(SessionTarget.studio);
      addTearDown(cubit.close);

      await cubit.endSession(reason: SessionExpiredReason.idleTimeout);

      expect(cubit.state, const SessionUnauthenticated(reason: SessionExpiredReason.idleTimeout));
      expect(errors, contains(allOf(contains('SessionCubit : endSession(idleTimeout)'), contains('boom on delete'))));
    });

    // A request still in flight when the user signs out can end in a 401 that no refresh can fix, so endSession runs
    // with no session to end.
    blocTest<SessionCubit, SessionState>(
      'endSession leaves storage and state alone when no session is stored',
      setUp: () => AppLocalStorage().save(StorageKeys.language.key, 'tr'),
      build: () => SessionCubit(
        availableTargets: _studioOnly,
        secureStorage: _MemorySecureStorage(),
        ssoStartup: _storedSessionStep(),
      ),
      seed: () => const SessionUnauthenticated(reason: SessionExpiredReason.noToken),
      act: (cubit) => cubit.endSession(reason: SessionExpiredReason.expired),
      expect: () => const <SessionState>[],
      verify: (_) async => expect(await AppLocalStorage().read(StorageKeys.language.key), 'tr'),
    );

    // A token refresh still in flight when the session ends can store a fresh session while the cubit is signed out;
    // a restart would restore it.
    test('endSession clears a stored session even when the cubit is already signed out', () async {
      final storage = _MemorySecureStorage();
      await storage.write(SecureStorageKeys.jwtToken.key, 'fresh-jwt');
      await storage.write(SecureStorageKeys.refreshToken.key, 'fresh-refresh');
      final cubit = SessionCubit(
        availableTargets: _studioOnly,
        secureStorage: storage,
        ssoStartup: _storedSessionStep(),
      )..markLoggedOut();
      addTearDown(cubit.close);

      await cubit.endSession(reason: SessionExpiredReason.expired);

      expect(await storage.read(SecureStorageKeys.jwtToken.key), isNull);
      expect(await storage.read(SecureStorageKeys.refreshToken.key), isNull);
      expect(cubit.state, const SessionUnauthenticated(reason: SessionExpiredReason.noToken));
    });
  });

  group('restore reads the session target', () {
    const timeLimit = Duration(seconds: 3);

    _MemorySecureStorage storedSession({String? target}) {
      final storage = _MemorySecureStorage()
        .._store[SecureStorageKeys.jwtToken.key] = 'opaque-access-token'
        .._store[SecureStorageKeys.refreshToken.key] = 'stored-refresh';
      if (target != null) storage._store[SecureStorageKeys.sessionTarget.key] = target;
      return storage;
    }

    // Sessions stored by app version 1.0.0 and earlier have no target, and all of them are Studio sessions.
    test('a token without a stored target restores as Studio and logs the upgrade rule', () async {
      final infos = _recordLogs(Level.info);
      final cubit = SessionCubit(
        availableTargets: _studioOnly,
        secureStorage: storedSession(),
        ssoStartup: _storedSessionStep(),
      );
      addTearDown(cubit.close);

      await cubit.restore();

      expect(cubit.state, const SessionAuthenticated(target: SessionTarget.studio));
      expect(infos, contains(allOf(contains('SessionCubit : restore'), contains('upgrade rule'))));
    });

    test('a stored studio target restores as Studio, without the upgrade rule', () async {
      final infos = _recordLogs(Level.info);
      final cubit = SessionCubit(
        availableTargets: _studioOnly,
        secureStorage: storedSession(target: 'studio'),
        ssoStartup: _storedSessionStep(),
      );
      addTearDown(cubit.close);

      await cubit.restore();

      expect(cubit.state, const SessionAuthenticated(target: SessionTarget.studio));
      expect(infos, contains(allOf(contains('SessionCubit : restore'), contains('authenticated'))));
      expect(infos, isNot(contains(contains('upgrade rule'))));
    });

    test('a stored platform target restores as Platform in a build that serves it', () async {
      final cubit = SessionCubit(
        availableTargets: _bothTargets,
        secureStorage: storedSession(target: 'platform'),
        ssoStartup: _storedSessionStep(),
      );
      addTearDown(cubit.close);

      await cubit.restore();

      expect(cubit.state, const SessionAuthenticated(target: SessionTarget.platform));
    });

    test('a stored platform target in a build without Platform clears the session and says why', () async {
      final storage = storedSession(target: 'platform');
      final cubit = SessionCubit(
        availableTargets: _studioOnly,
        secureStorage: storage,
        ssoStartup: _storedSessionStep(),
      );
      addTearDown(cubit.close);

      await cubit.restore();

      expect(
        cubit.state,
        const SessionUnauthenticated(
          reason: SessionExpiredReason.signInFailed,
          signInError: AppErrorCode.platformNotConfigured,
        ),
      );
      expect(storage._store, isEmpty, reason: 'every launch would repeat the same restore');
    });

    for (final value in ['platform-v2-unknown', '']) {
      test('an unknown stored target "$value" clears the session and ends it as corrupt, logging no value', () async {
        final warnings = _recordLogs(Level.warning);
        final storage = storedSession(target: value);
        final cubit = SessionCubit(
          availableTargets: _bothTargets,
          secureStorage: storage,
          ssoStartup: _storedSessionStep(),
        );
        addTearDown(cubit.close);

        await cubit.restore();

        expect(cubit.state, const SessionUnauthenticated(reason: SessionExpiredReason.corruptSession));
        expect(storage._store, isEmpty);
        final unreadable = warnings.where((line) => line.contains('unreadable')).toList();
        expect(unreadable, hasLength(1));
        expect(unreadable.single, contains('SessionCubit : restore'));
        expect(unreadable.single, contains('${value.length} characters'));
        if (value.isNotEmpty) expect(warnings.join('\n'), isNot(contains(value)));
      });
    }

    test('a read that throws on the target keeps the storageError path and clears nothing', () async {
      final storage = MockISecureStorage();
      when(() => storage.read(SecureStorageKeys.jwtToken.key)).thenAnswer((_) async => 'opaque-access-token');
      when(() => storage.read(SecureStorageKeys.sessionTarget.key)).thenThrow(StateError('boom'));
      final sessions = _HeldClearSessionRepository();
      final cubit = SessionCubit(
        availableTargets: _studioOnly,
        secureStorage: storage,
        sessionRepository: sessions,
        ssoStartup: _storedSessionStep(),
      );
      addTearDown(cubit.close);

      await cubit.restore();

      expect(cubit.state, const SessionUnauthenticated(reason: SessionExpiredReason.storageError));
      expect(sessions.clears, 0);
    });

    // A storage that hangs on delete must not keep the startup spinner forever.
    test('a clear that does not finish in time still ends the session at the time limit, and logs an error', () {
      final errors = _recordLogs(Level.error);
      fakeAsync((async) {
        final sessions = _HeldClearSessionRepository();
        final cubit = SessionCubit(
          availableTargets: _studioOnly,
          secureStorage: storedSession(target: 'platform-v2-unknown'),
          sessionRepository: sessions,
          restoreTimeLimit: timeLimit,
          ssoStartup: _storedSessionStep(),
        );

        unawaited(cubit.restore());
        async.flushMicrotasks();
        expect(sessions.clears, 1);
        async.elapse(timeLimit - const Duration(milliseconds: 1));
        expect(cubit.state, const SessionUnknown());

        async.elapse(const Duration(milliseconds: 1));
        expect(cubit.state, const SessionUnauthenticated(reason: SessionExpiredReason.corruptSession));
        expect(errors, contains(allOf(contains('SessionCubit : restore'), contains('clear'))));
        sessions.release.complete();
        async.flushMicrotasks();
        unawaited(cubit.close());
      });
    });

    group('an answer after the restore time limit', () {
      _SlowSecureStorage slowStorage() => _SlowSecureStorage()
        ..answers[SecureStorageKeys.jwtToken.key] = Completer<String?>()
        ..answers[SecureStorageKeys.sessionTarget.key] = Completer<String?>();

      void answer(_SlowSecureStorage storage, {required String token, required String target}) {
        storage.answers[SecureStorageKeys.jwtToken.key]!.complete(token);
        storage.answers[SecureStorageKeys.sessionTarget.key]!.complete(target);
      }

      test('with an unknown target clears the session and ends it while nobody signed in since', () {
        fakeAsync((async) {
          final storage = slowStorage();
          final sessions = _HeldClearSessionRepository()..release.complete();
          final cubit = SessionCubit(
            availableTargets: _studioOnly,
            secureStorage: storage,
            sessionRepository: sessions,
            restoreTimeLimit: timeLimit,
            ssoStartup: _storedSessionStep(),
          );
          final states = <SessionState>[];
          cubit.stream.listen(states.add);

          unawaited(cubit.restore());
          async.elapse(timeLimit);
          answer(storage, token: 'old-token', target: 'platform-v2-unknown');
          async.flushMicrotasks();

          expect(sessions.clears, 1);
          expect(states, [
            const SessionUnauthenticated(reason: SessionExpiredReason.storageTimeout),
            const SessionUnauthenticated(reason: SessionExpiredReason.corruptSession),
          ]);
          unawaited(cubit.close());
        });
      });

      test('with an unknown target leaves the session the user signed in to since in place, and emits nothing', () {
        final warnings = _recordLogs(Level.warning);
        fakeAsync((async) {
          final storage = slowStorage();
          final sessions = _HeldClearSessionRepository()..release.complete();
          final cubit = SessionCubit(
            availableTargets: _studioOnly,
            secureStorage: storage,
            sessionRepository: sessions,
            restoreTimeLimit: timeLimit,
            ssoStartup: _storedSessionStep(),
          );
          final states = <SessionState>[];
          cubit.stream.listen(states.add);

          unawaited(cubit.restore());
          async.elapse(timeLimit);
          // The user signs in on the login page the time limit showed.
          storage.store
            ..[SecureStorageKeys.sessionTarget.key] = 'studio'
            ..[SecureStorageKeys.jwtToken.key] = 'new-token';
          cubit.markAuthenticated(SessionTarget.studio);
          answer(storage, token: 'old-token', target: 'platform-v2-unknown');
          async.flushMicrotasks();

          expect(sessions.clears, 0);
          expect(storage.store, {
            SecureStorageKeys.sessionTarget.key: 'studio',
            SecureStorageKeys.jwtToken.key: 'new-token',
          });
          expect(states, [
            const SessionUnauthenticated(reason: SessionExpiredReason.storageTimeout),
            const SessionAuthenticated(target: SessionTarget.studio),
          ]);
          expect(warnings, contains(allOf(contains('SessionCubit : restore'), contains('ignored'))));
          unawaited(cubit.close());
        });
      });

      test('with an unknown target emits nothing when the user signs in while the clear runs', () {
        final warnings = _recordLogs(Level.warning);
        fakeAsync((async) {
          final storage = slowStorage();
          final sessions = _HeldClearSessionRepository();
          final cubit = SessionCubit(
            availableTargets: _studioOnly,
            secureStorage: storage,
            sessionRepository: sessions,
            restoreTimeLimit: timeLimit,
            ssoStartup: _storedSessionStep(),
          );
          final states = <SessionState>[];
          cubit.stream.listen(states.add);

          unawaited(cubit.restore());
          async.elapse(timeLimit);
          answer(storage, token: 'old-token', target: 'platform-v2-unknown');
          async.flushMicrotasks();
          expect(sessions.clears, 1);
          cubit.markAuthenticated(SessionTarget.studio);
          sessions.release.complete();
          async.flushMicrotasks();

          expect(states, [
            const SessionUnauthenticated(reason: SessionExpiredReason.storageTimeout),
            const SessionAuthenticated(target: SessionTarget.studio),
          ]);
          expect(warnings, contains(allOf(contains('SessionCubit : restore'), contains('ignored'))));
          unawaited(cubit.close());
        });
      });
    });

    test('endSession wipes a target stored without a token', () async {
      final storage = _MemorySecureStorage().._store[SecureStorageKeys.sessionTarget.key] = 'studio';
      final cubit = SessionCubit(
        availableTargets: _studioOnly,
        secureStorage: storage,
        ssoStartup: _storedSessionStep(),
      )..markAuthenticated(SessionTarget.studio);
      addTearDown(cubit.close);

      await cubit.endSession(reason: SessionExpiredReason.idleTimeout);

      expect(storage._store, isEmpty);
      expect(cubit.state, const SessionUnauthenticated(reason: SessionExpiredReason.idleTimeout));
    });
  });

  // App shows a spinner instead of the router until restore settles the session, so storage that never answers would
  // keep the user there.
  group('SessionCubit.restore time limit', () {
    const timeLimit = Duration(seconds: 3);

    /// Secure storage whose token read answers only when [answer] completes, and which holds nothing else.
    MockISecureStorage storageAnswering(Future<String?> answer) {
      final storage = MockISecureStorage();
      when(() => storage.read(any())).thenAnswer((_) async => null);
      when(() => storage.read(SecureStorageKeys.jwtToken.key)).thenAnswer((_) => answer);
      return storage;
    }

    test('signs the user out with storageTimeout and logs an error when secure storage does not answer in time', () {
      final errors = <String>[];
      void recordError(OutputEvent event) {
        if (event.level == Level.error) errors.addAll(event.lines);
      }

      Logger.addOutputListener(recordError);
      addTearDown(() => Logger.removeOutputListener(recordError));

      fakeAsync((async) {
        final cubit = SessionCubit(
          availableTargets: _studioOnly,
          secureStorage: storageAnswering(Completer<String?>().future),
          restoreTimeLimit: timeLimit,
          ssoStartup: _storedSessionStep(),
        );

        unawaited(cubit.restore());
        async.elapse(timeLimit - const Duration(milliseconds: 1));
        expect(cubit.state, const SessionUnknown());
        expect(errors, isEmpty);

        async.elapse(const Duration(milliseconds: 1));
        expect(cubit.state, const SessionUnauthenticated(reason: SessionExpiredReason.storageTimeout));
        expect(errors, contains(contains('SessionCubit : restore')));
        unawaited(cubit.close());
      });
    });

    test('opens a stored session that secure storage answers after the time limit, and logs it', () {
      final infos = _recordLogs(Level.info);
      fakeAsync((async) {
        final storedToken = Completer<String?>();
        final cubit = SessionCubit(
          availableTargets: _studioOnly,
          secureStorage: storageAnswering(storedToken.future),
          restoreTimeLimit: timeLimit,
          ssoStartup: _storedSessionStep(),
        );
        final states = <SessionState>[];
        cubit.stream.listen(states.add);

        unawaited(cubit.restore());
        async.elapse(timeLimit);
        storedToken.complete('MOCK_TOKEN');
        async.flushMicrotasks();

        expect(states, [
          const SessionUnauthenticated(reason: SessionExpiredReason.storageTimeout),
          const SessionAuthenticated(target: SessionTarget.studio),
        ]);
        expect(infos, contains(allOf(contains('SessionCubit : restore'), contains('after the time limit'))));
        unawaited(cubit.close());
      });
    });

    test('keeps the user signed out when secure storage answers after the time limit with no stored session', () {
      fakeAsync((async) {
        final storedToken = Completer<String?>();
        final cubit = SessionCubit(
          availableTargets: _studioOnly,
          secureStorage: storageAnswering(storedToken.future),
          restoreTimeLimit: timeLimit,
          ssoStartup: _storedSessionStep(),
        );
        final states = <SessionState>[];
        cubit.stream.listen(states.add);

        unawaited(cubit.restore());
        async.elapse(timeLimit);
        storedToken.complete(null);
        async.flushMicrotasks();

        expect(states, [
          const SessionUnauthenticated(reason: SessionExpiredReason.storageTimeout),
          const SessionUnauthenticated(reason: SessionExpiredReason.noToken),
        ]);
        unawaited(cubit.close());
      });
    });

    test('ignores a session answered after the time limit, and logs it, once the user has signed in since', () {
      final warnings = _recordLogs(Level.warning);
      fakeAsync((async) {
        final storedToken = Completer<String?>();
        final cubit = SessionCubit(
          availableTargets: _studioOnly,
          secureStorage: storageAnswering(storedToken.future),
          restoreTimeLimit: timeLimit,
          ssoStartup: _storedSessionStep(),
        );
        final states = <SessionState>[];
        cubit.stream.listen(states.add);

        unawaited(cubit.restore());
        async.elapse(timeLimit);
        cubit.markAuthenticated(SessionTarget.studio);
        storedToken.complete('MOCK_TOKEN');
        async.flushMicrotasks();

        expect(states, [
          const SessionUnauthenticated(reason: SessionExpiredReason.storageTimeout),
          const SessionAuthenticated(target: SessionTarget.studio),
        ]);
        expect(warnings, contains(allOf(contains('SessionCubit : restore'), contains('ignored'))));
        unawaited(cubit.close());
      });
    });

    test('does not sign back in a user who signed in and out after the time limit', () {
      fakeAsync((async) {
        final storedToken = Completer<String?>();
        final cubit = SessionCubit(
          availableTargets: _studioOnly,
          secureStorage: storageAnswering(storedToken.future),
          restoreTimeLimit: timeLimit,
          ssoStartup: _storedSessionStep(),
        );
        final states = <SessionState>[];
        cubit.stream.listen(states.add);

        unawaited(cubit.restore());
        async.elapse(timeLimit);
        cubit
          ..markAuthenticated(SessionTarget.studio)
          ..markLoggedOut();
        storedToken.complete('MOCK_TOKEN');
        async.flushMicrotasks();

        expect(states, [
          const SessionUnauthenticated(reason: SessionExpiredReason.storageTimeout),
          const SessionAuthenticated(target: SessionTarget.studio),
          const SessionUnauthenticated(reason: SessionExpiredReason.noToken),
        ]);
        unawaited(cubit.close());
      });
    });

    test('ignores a session answered after the time limit once the cubit is closed', () {
      fakeAsync((async) {
        final storedToken = Completer<String?>();
        final cubit = SessionCubit(
          availableTargets: _studioOnly,
          secureStorage: storageAnswering(storedToken.future),
          restoreTimeLimit: timeLimit,
          ssoStartup: _storedSessionStep(),
        );

        unawaited(cubit.restore());
        async.elapse(timeLimit);
        unawaited(cubit.close());
        async.flushMicrotasks();
        // Emitting into the closed cubit would throw here.
        storedToken.complete('MOCK_TOKEN');
        async.flushMicrotasks();

        expect(cubit.state, const SessionUnauthenticated(reason: SessionExpiredReason.storageTimeout));
      });
    });

    test('a restore settled within the time limit is not signed out when the limit passes', () {
      fakeAsync((async) {
        final storedToken = Completer<String?>();
        final cubit = SessionCubit(
          availableTargets: _studioOnly,
          secureStorage: storageAnswering(storedToken.future),
          restoreTimeLimit: timeLimit,
          ssoStartup: _storedSessionStep(),
        );
        final states = <SessionState>[];
        cubit.stream.listen(states.add);

        unawaited(cubit.restore());
        async.elapse(const Duration(seconds: 1));
        storedToken.complete('MOCK_TOKEN');
        async.elapse(timeLimit * 2);

        expect(states, [const SessionAuthenticated(target: SessionTarget.studio)]);
        unawaited(cubit.close());
      });
    });

    test('close stops the time limit of a restore in flight', () {
      fakeAsync((async) {
        final cubit = SessionCubit(
          availableTargets: _studioOnly,
          secureStorage: storageAnswering(Completer<String?>().future),
          restoreTimeLimit: timeLimit,
          ssoStartup: _storedSessionStep(),
        );

        unawaited(cubit.restore());
        // The startup step answers, so the stored read and its time limit start.
        async.flushMicrotasks();
        unawaited(cubit.close());

        // A timer left running would emit into the closed cubit and, in a widget test, fail it as still pending.
        expect(async.pendingTimers, isEmpty);
      });
    });
  });

  group('restore with the startup step', () {
    const timeLimit = Duration(seconds: 3);

    SessionCubit cubitWith(SsoStartupResult result, {ISecureStorage? storage}) => SessionCubit(
      availableTargets: _studioOnly,
      secureStorage: storage ?? _MemorySecureStorage(),
      ssoStartup: _FakeSsoStartup(Future.value(result)),
    );

    test('the startup step waits at most 15 seconds unless the constructor is given another limit', () {
      expect(SessionCubit.defaultSsoStartupTimeLimit, const Duration(seconds: 15));
    });

    test('SessionUnauthenticated equality includes the sign-in error', () {
      expect(
        const SessionUnauthenticated(
          reason: SessionExpiredReason.signInFailed,
          signInError: AppErrorCode.authOidcFailed,
        ),
        isNot(const SessionUnauthenticated(reason: SessionExpiredReason.signInFailed)),
      );
      expect(const SessionUnauthenticated().signInError, isNull);
    });

    blocTest<SessionCubit, SessionState>(
      'a failed startup sign-in gives SessionUnauthenticated(signInFailed) with its error',
      build: () => cubitWith(const SsoStartupSignInFailed(AppErrorCode.authOidcConfig)),
      act: (cubit) => cubit.restore(),
      expect: () => [
        const SessionUnauthenticated(
          reason: SessionExpiredReason.signInFailed,
          signInError: AppErrorCode.authOidcConfig,
        ),
      ],
    );

    blocTest<SessionCubit, SessionState>(
      'a session the startup step ended gives SessionUnauthenticated(expired)',
      build: () => cubitWith(const SsoStartupSessionEnded(SsoSessionEndReason.refreshRefused)),
      act: (cubit) => cubit.restore(),
      expect: () => [const SessionUnauthenticated(reason: SessionExpiredReason.expired)],
    );

    blocTest<SessionCubit, SessionState>(
      'the stored session with no token gives SessionUnauthenticated(noToken)',
      build: () => cubitWith(const SsoStartupUseStoredSession()),
      act: (cubit) => cubit.restore(),
      expect: () => [const SessionUnauthenticated(reason: SessionExpiredReason.noToken)],
    );

    // The startup step owns the expiry, and a provider's access token need not be a JWT.
    blocTest<SessionCubit, SessionState>(
      'the stored session is not checked for a JWT exp',
      build: () {
        final storage = _MemorySecureStorage().._store[SecureStorageKeys.jwtToken.key] = _expiredJwt;
        return cubitWith(const SsoStartupUseStoredSession(), storage: storage);
      },
      act: (cubit) => cubit.restore(),
      expect: () => [const SessionAuthenticated(target: SessionTarget.studio)],
    );

    test('production with an opaque stored bearer and a future stored expiry gives SessionAuthenticated', () async {
      final storage = _MemorySecureStorage()
        .._store[SecureStorageKeys.jwtToken.key] = 'opaque-access-token'
        .._store[SecureStorageKeys.refreshToken.key] = 'stored-refresh'
        .._store[SecureStorageKeys.accessTokenExpiresAt.key] = encodeAccessTokenExpiry(
          DateTime.now().add(const Duration(minutes: 5)),
        );
      final rotation = MockTokenRotation();
      final cubit = SessionCubit(
        availableTargets: _studioOnly,
        secureStorage: storage,
        ssoStartup: SsoSessionStartup(
          rotation: rotation,
          secureStorage: storage,
          sessionRepository: MockIAuthSessionRepository(),
          gate: SsoAutoRedirectGate(),
        ),
      );
      addTearDown(cubit.close);

      await cubit.restore();

      expect(cubit.state, const SessionAuthenticated(target: SessionTarget.studio));
      verifyNever(() => rotation.rotate(any()));
    });

    test('the startup step runs before the stored session is read', () {
      fakeAsync((async) {
        final storage = MockISecureStorage();
        when(() => storage.read(any())).thenAnswer((_) async => null);
        final startup = Completer<SsoStartupResult>();
        final cubit = SessionCubit(
          availableTargets: _studioOnly,
          secureStorage: storage,
          ssoStartup: _FakeSsoStartup(startup.future),
        );

        unawaited(cubit.restore());
        async.elapse(const Duration(seconds: 1));
        verifyNever(() => storage.read(any()));

        startup.complete(const SsoStartupUseStoredSession());
        async.flushMicrotasks();
        verify(() => storage.read(SecureStorageKeys.jwtToken.key)).called(1);
        expect(cubit.state, const SessionUnauthenticated(reason: SessionExpiredReason.noToken));
        unawaited(cubit.close());
      });
    });

    test('a startup step that does not answer in time reads the stored session as it is, and logs a warning', () {
      final warnings = _recordLogs(Level.warning);
      fakeAsync((async) {
        final storage = _MemorySecureStorage().._store[SecureStorageKeys.jwtToken.key] = 'opaque-access-token';
        final startup = _FakeSsoStartup(Completer<SsoStartupResult>().future);
        final cubit = SessionCubit(
          availableTargets: _studioOnly,
          secureStorage: storage,
          ssoStartup: startup,
          ssoStartupTimeLimit: timeLimit,
        );
        final states = <SessionState>[];
        cubit.stream.listen(states.add);

        unawaited(cubit.restore());
        async.elapse(timeLimit - const Duration(milliseconds: 1));
        expect(cubit.state, const SessionUnknown());
        expect(startup.giveUps, 0);

        async.elapse(const Duration(milliseconds: 1));
        expect(states, [const SessionAuthenticated(target: SessionTarget.studio)]);
        expect(startup.giveUps, 1);
        expect(warnings, contains(allOf(contains('SessionCubit : restore'), contains('identity provider'))));
        unawaited(cubit.close());
      });
    });

    test('a startup step that does not answer in time closes the automatic redirect gate', () {
      fakeAsync((async) {
        // An expired stored access token whose refresh never answers.
        final storage = _MemorySecureStorage()
          .._store[SecureStorageKeys.refreshToken.key] = 'stored-refresh'
          .._store[SecureStorageKeys.accessTokenExpiresAt.key] = encodeAccessTokenExpiry(
            DateTime.now().subtract(const Duration(minutes: 5)),
          );
        final rotation = MockTokenRotation();
        when(() => rotation.rotate(any())).thenAnswer((_) => Completer<Never>().future);
        final gate = SsoAutoRedirectGate();
        final cubit = SessionCubit(
          availableTargets: _studioOnly,
          secureStorage: storage,
          ssoStartup: SsoSessionStartup(
            rotation: rotation,
            secureStorage: storage,
            sessionRepository: MockIAuthSessionRepository(),
            gate: gate,
          ),
          ssoStartupTimeLimit: timeLimit,
        );

        unawaited(cubit.restore());
        async.elapse(timeLimit);

        expect(gate.isOpen, isFalse);
        expect(cubit.state, const SessionUnauthenticated(reason: SessionExpiredReason.noToken));
        unawaited(cubit.close());
      });
    });

    test('a startup step that answers after its time limit is ignored, and logged', () {
      final infos = _recordLogs(Level.info);
      fakeAsync((async) {
        final startup = Completer<SsoStartupResult>();
        final cubit = SessionCubit(
          availableTargets: _studioOnly,
          secureStorage: _MemorySecureStorage(),
          ssoStartup: _FakeSsoStartup(startup.future),
          ssoStartupTimeLimit: timeLimit,
        );
        final states = <SessionState>[];
        cubit.stream.listen(states.add);

        unawaited(cubit.restore());
        async.elapse(timeLimit);
        startup.complete(const SsoStartupUseStoredSession());
        async.flushMicrotasks();

        expect(states, [const SessionUnauthenticated(reason: SessionExpiredReason.noToken)]);
        expect(infos, contains(allOf(contains('SessionCubit : restore'), contains('after its time limit'))));
        unawaited(cubit.close());
      });
    });

    group('an answer after the time limit', () {
      // Built after the startup step has stored its session, so the cubit only sees it through the late answer.
      SessionCubit lateCubit(_MemorySecureStorage storage, Completer<SsoStartupResult> startup) => SessionCubit(
        availableTargets: _studioOnly,
        secureStorage: storage,
        ssoStartup: _FakeSsoStartup(startup.future),
        ssoStartupTimeLimit: timeLimit,
      );

      test('a late SessionEnded ends the session the stored read opened, with reason expired', () {
        fakeAsync((async) {
          final storage = _MemorySecureStorage().._store[SecureStorageKeys.jwtToken.key] = 'opaque-access-token';
          final startup = Completer<SsoStartupResult>();
          final cubit = lateCubit(storage, startup);
          final states = <SessionState>[];
          cubit.stream.listen(states.add);

          unawaited(cubit.restore());
          async.elapse(timeLimit);
          expect(states, [const SessionAuthenticated(target: SessionTarget.studio)]);

          // The refresh was refused after the limit: the step has cleared the stored session.
          storage._store.clear();
          startup.complete(const SsoStartupSessionEnded(SsoSessionEndReason.refreshRefused));
          async.flushMicrotasks();

          expect(states, [
            const SessionAuthenticated(target: SessionTarget.studio),
            const SessionUnauthenticated(reason: SessionExpiredReason.expired),
          ]);
          unawaited(cubit.close());
        });
      });

      for (final (name, late) in [
        ('SignInFailed', const SsoStartupSignInFailed(AppErrorCode.authOidcConfig) as SsoStartupResult),
        ('UseStoredSession', const SsoStartupUseStoredSession()),
      ]) {
        test('a late $name only logs', () {
          final infos = _recordLogs(Level.info);
          fakeAsync((async) {
            final storage = _MemorySecureStorage().._store[SecureStorageKeys.jwtToken.key] = 'opaque-access-token';
            final startup = Completer<SsoStartupResult>();
            final cubit = lateCubit(storage, startup);
            final states = <SessionState>[];
            cubit.stream.listen(states.add);

            unawaited(cubit.restore());
            async.elapse(timeLimit);
            startup.complete(late);
            async.flushMicrotasks();

            expect(states, [const SessionAuthenticated(target: SessionTarget.studio)]);
            expect(infos, contains(allOf(contains('SessionCubit : restore'), contains('after its time limit'))));
            unawaited(cubit.close());
          });
        });
      }

      for (final (name, late) in [
        ('SessionEnded', const SsoStartupSessionEnded(SsoSessionEndReason.refreshRefused) as SsoStartupResult),
        ('UseStoredSession', const SsoStartupUseStoredSession()),
      ]) {
        test('a late $name after the user has signed in or out only logs', () {
          final warnings = _recordLogs(Level.warning);
          fakeAsync((async) {
            final storage = _MemorySecureStorage().._store[SecureStorageKeys.jwtToken.key] = 'opaque-access-token';
            final startup = Completer<SsoStartupResult>();
            final cubit = lateCubit(storage, startup);
            final states = <SessionState>[];
            cubit.stream.listen(states.add);

            unawaited(cubit.restore());
            async.elapse(timeLimit);
            // The same state the timeout settled, emitted again by a sign-in: the late answer must still be ignored.
            cubit.markAuthenticated(SessionTarget.studio);
            startup.complete(late);
            async.flushMicrotasks();

            expect(states, [const SessionAuthenticated(target: SessionTarget.studio)]);
            expect(warnings, contains(allOf(contains('SessionCubit : restore'), contains('state changed'))));
            unawaited(cubit.close());
          });
        });
      }

      test('a late answer that comes while the stored read is in flight waits for that read', () {
        fakeAsync((async) {
          final token = Completer<String?>();
          final storage = MockISecureStorage();
          when(() => storage.read(any())).thenAnswer((_) async => null);
          when(() => storage.read(SecureStorageKeys.jwtToken.key)).thenAnswer((_) => token.future);
          final startup = Completer<SsoStartupResult>();
          final cubit = SessionCubit(
            availableTargets: _studioOnly,
            secureStorage: storage,
            ssoStartup: _FakeSsoStartup(startup.future),
            ssoStartupTimeLimit: timeLimit,
          );
          final states = <SessionState>[];
          cubit.stream.listen(states.add);

          unawaited(cubit.restore());
          async.elapse(timeLimit);
          startup.complete(const SsoStartupSessionEnded(SsoSessionEndReason.refreshRefused));
          async.flushMicrotasks();
          expect(states, isEmpty);

          token.complete('opaque-access-token');
          async.flushMicrotasks();

          expect(states, [
            const SessionAuthenticated(target: SessionTarget.studio),
            const SessionUnauthenticated(reason: SessionExpiredReason.expired),
          ]);
          unawaited(cubit.close());
        });
      });
    });

    test('the stored read after the startup step keeps its own time limit', () {
      fakeAsync((async) {
        final storage = MockISecureStorage();
        when(() => storage.read(any())).thenAnswer((_) => Completer<String?>().future);
        final cubit = SessionCubit(
          availableTargets: _studioOnly,
          secureStorage: storage,
          restoreTimeLimit: timeLimit,
          ssoStartup: _FakeSsoStartup(Future.value(const SsoStartupUseStoredSession())),
        );

        unawaited(cubit.restore());
        async.elapse(timeLimit);

        expect(cubit.state, const SessionUnauthenticated(reason: SessionExpiredReason.storageTimeout));
        unawaited(cubit.close());
      });
    });

    test('a startup step that throws gives signInFailed with authOidcFailed, and logs an error', () async {
      final errors = _recordLogs(Level.error);
      final startup = _FakeSsoStartup(Future.error(StateError('secret-detail')));
      final cubit = SessionCubit(
        availableTargets: _studioOnly,
        secureStorage: _MemorySecureStorage(),
        ssoStartup: startup,
      );
      addTearDown(cubit.close);

      await cubit.restore();

      expect(
        cubit.state,
        const SessionUnauthenticated(
          reason: SessionExpiredReason.signInFailed,
          signInError: AppErrorCode.authOidcFailed,
        ),
      );
      expect(errors, contains(allOf(contains('SessionCubit : restore'), contains('StateError'))));
      expect(errors.join('\n'), isNot(contains('secret-detail')));
      expect(startup.giveUps, 1);
    });

    test('close stops the time limit of a startup step in flight', () {
      fakeAsync((async) {
        final cubit = SessionCubit(
          availableTargets: _studioOnly,
          secureStorage: _MemorySecureStorage(),
          ssoStartup: _FakeSsoStartup(Completer<SsoStartupResult>().future),
        );

        unawaited(cubit.restore());
        unawaited(cubit.close());

        expect(async.pendingTimers, isEmpty);
      });
    });
  });
}

/// Collects the lines logged at [level] until the test ends.
List<String> _recordLogs(Level level) {
  final lines = <String>[];
  void record(OutputEvent event) {
    if (event.level == level) lines.addAll(event.lines);
  }

  Logger.addOutputListener(record);
  addTearDown(() => Logger.removeOutputListener(record));
  return lines;
}
