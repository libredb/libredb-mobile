import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/core/logging/app_logger.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/core/security/security_utils.dart';
import 'package:libredb_mobile/features/auth/data/repositories/auth_session_repository_impl.dart';
import 'package:libredb_mobile/features/auth/domain/repositories/auth_session_repository.dart';
import 'package:libredb_mobile/features/auth/domain/services/sso_session_startup.dart';
import 'package:libredb_mobile/infrastructure/storage/secure_storage.dart';
import 'package:libredb_mobile/infrastructure/storage/startup_storage_time_limit.dart';
import 'package:libredb_mobile/shared/models/session_target.dart';

/// Session state observed by router redirect and UI guards.
///
/// Sealed so consumers must exhaustively switch on the three real
/// outcomes — `unknown` (restore in flight), `authenticated`, and
/// `unauthenticated`. Collapsing them to a single `bool isAuthenticated`
/// (the previous shape) made it impossible to distinguish "still
/// restoring" from "we checked and there is no session" and forced
/// load-bearing comments where a type could carry the invariant.
sealed class SessionState extends Equatable {
  const SessionState();

  @override
  List<Object?> get props => const [];
}

/// Initial state, before [SessionCubit.restore] has completed.
///
/// The router treats this the same as [SessionUnauthenticated] for
/// redirect decisions (we cannot route into protected routes without
/// proof of session), but consumers that need to discriminate — e.g.
/// a splash screen — can pattern-match on the type rather than relying
/// on convention.
final class SessionUnknown extends SessionState {
  const SessionUnknown();
}

/// User holds a valid session token in secure storage.
///
/// It carries the session's [target], Studio or Platform, which the sign-in
/// stored with the tokens. It still carries no role: the role comes only from
/// Studio's `GET /api/auth/me` and is never stored.
final class SessionAuthenticated extends SessionState {
  const SessionAuthenticated({required this.target});

  final SessionTarget target;

  @override
  List<Object?> get props => [target];
}

/// User holds no valid session token. The [reason] is for logs and
/// tests — it MUST NOT be surfaced to the user as a localized error
/// because the categories are deliberately coarse.
///
/// [signInError] says why single sign-on cannot run, with
/// [SessionExpiredReason.signInFailed]; the login page shows it.
final class SessionUnauthenticated extends SessionState {
  const SessionUnauthenticated({this.reason = SessionExpiredReason.unknown, this.signInError});

  final SessionExpiredReason reason;
  final AppErrorCode? signInError;

  @override
  List<Object?> get props => [reason, signInError];

  /// Leaves out a null [signInError], so a state without one prints as
  /// `SessionUnauthenticated(reason)`.
  @override
  String toString() {
    if (signInError != null || !(stringify ?? EquatableConfig.stringify)) return super.toString();
    return '$runtimeType($reason)';
  }
}

/// Why the cubit emitted [SessionUnauthenticated]. Drives log fidelity
/// and lets tests assert specific failure pathways without coupling
/// them to log strings.
enum SessionExpiredReason {
  /// No token in secure storage (clean logged-out state), or an explicit
  /// logout: [SessionCubit.markLoggedOut] reports this reason also after a
  /// logout that could not clear all of the stored session, which can leave
  /// a token behind.
  noToken,

  /// The startup step ended the stored session, or a 401 that a token
  /// refresh could not fix ended it.
  expired,

  /// Secure storage read threw (platform / decryption failure).
  /// We fall back to unauthenticated as the safe default so the user
  /// re-authenticates cleanly instead of leaving the cubit in
  /// [SessionUnknown] forever.
  storageError,

  /// The stored session was not read within the restore time limit, so
  /// it could not be checked; see [SessionCubit.restore]. The login page
  /// shows, and a valid session that the read finds later still opens
  /// the app unless the user has signed in or out by then.
  storageTimeout,

  /// User was inactive past the configured idle threshold and the
  /// session was forcibly ended. Surfaced to the UI as a localized
  /// notice so the user understands why they were signed out.
  idleTimeout,

  /// Single sign-on cannot run in this `oidc` build, such as when its
  /// settings break a rule; [SessionUnauthenticated.signInError] says why.
  /// A stored session for a target this build cannot serve ends with it too,
  /// with [AppErrorCode.platformNotConfigured].
  signInFailed,

  /// The stored session holds a value this build cannot read, so it was
  /// cleared.
  corruptSession,

  /// Initial or otherwise uncategorized — e.g. an explicit logout
  /// flow that does not need to distinguish further.
  unknown,
}

/// Owns the single source of truth for "is this user authenticated?".
///
/// Runs the single sign-on startup step, which owns the expiry of the
/// stored session, and then reads the token from [ISecureStorage] (the one
/// place tokens live) for the presence check of [SecurityUtils.hasToken].
/// Consumers (router redirect, UI guards) pattern-match on [state];
/// callers that want to re-evaluate trigger [refresh].
///
/// [availableTargets] are the session targets this build can serve. Every
/// build serves Studio; a build with a Platform target serves Platform too.
class SessionCubit extends Cubit<SessionState> {
  SessionCubit({
    ISecureStorage? secureStorage,
    IAuthSessionRepository? sessionRepository,
    required Set<SessionTarget> availableTargets,
    required this._ssoStartup,
    this._restoreTimeLimit = defaultRestoreTimeLimit,
    this._ssoStartupTimeLimit = defaultSsoStartupTimeLimit,
  }) : assert(availableTargets.isNotEmpty, 'a build serves at least one session target'),
       assert(availableTargets.contains(SessionTarget.studio), 'every build serves Studio'),
       _availableTargets = Set.unmodifiable(availableTargets),
       _secureStorage = secureStorage ?? FlutterSecureStorageAdapter(),
       super(const SessionUnknown()) {
    _sessionRepository = sessionRepository ?? AuthSessionRepository(secureStorage: _secureStorage);
  }

  /// How long [restore] waits for the stored session unless the
  /// constructor is given another `restoreTimeLimit`: ten seconds, see
  /// [StartupStorageTimeLimit.defaultDuration].
  ///
  /// An answer that comes after the limit still settles the session while
  /// the user is signed out by it.
  static const defaultRestoreTimeLimit = StartupStorageTimeLimit.defaultDuration;

  /// How long [restore] waits for the startup step
  /// unless the constructor is given another `ssoStartupTimeLimit`. The
  /// step makes network calls, so it has its own limit, outside the
  /// storage one.
  static const defaultSsoStartupTimeLimit = Duration(seconds: 15);

  static final _log = AppLogger.getLogger('SessionCubit');

  final ISecureStorage _secureStorage;
  late final IAuthSessionRepository _sessionRepository;
  final Set<SessionTarget> _availableTargets;
  final Duration _restoreTimeLimit;

  /// The startup step that refreshes an expired stored session.
  final ISsoSessionStartup _ssoStartup;
  final Duration _ssoStartupTimeLimit;

  /// The time limits of the restores in flight, and of the clears they run, cancelled by [close].
  final _restoreTimeLimits = <StartupStorageTimeLimit<Object?>>{};

  /// The time limits of the startup steps in flight, cancelled by [close].
  final _ssoStartupTimers = <Timer>{};

  /// How many states this cubit has emitted, counting a state equal to the
  /// current one, so a late startup answer can tell that nothing has been
  /// emitted since the state it would change.
  int _emitCount = 0;

  @override
  void emit(SessionState state) {
    _emitCount++;
    super.emit(state);
  }

  /// Reads the stored session and settles [state] from it.
  ///
  /// The read is bounded by the restore time limit
  /// ([defaultRestoreTimeLimit] unless the constructor is given another).
  /// Until restore settles the session, App shows a spinner instead of the
  /// router, so a secure storage that never answers would keep the user
  /// there forever. When the limit passes first, restore logs an error
  /// and emits [SessionUnauthenticated] with
  /// [SessionExpiredReason.storageTimeout], so the login page shows. This
  /// is an explicit error path, not a silent fallback: the error log says
  /// why the user is signed out. The stored session itself is left as it
  /// is.
  ///
  /// A read that answers after the limit settles the session as an
  /// in-time read would, as long as that storageTimeout sign-out is still
  /// the state: a valid stored session opens the app, and no session or
  /// an expired one keeps the login page. Once the user has signed in or
  /// out, the late answer is logged and ignored, so it can neither sign
  /// them back in nor replace the session they signed in to.
  ///
  /// The startup step runs first, under its own time limit
  /// ([defaultSsoStartupTimeLimit] unless the constructor is given
  /// another): it refreshes an expired access token. Only when it keeps the
  /// stored session is that session read, and then only for a token,
  /// because the step owns the expiry. A step that does not answer in time is taken
  /// as a provider that cannot be reached: the stored session is read as
  /// it is.
  ///
  /// The step goes on after its limit, and what it answers then is acted
  /// on only while the state is still the one that the read after the
  /// limit settled, see [_settleLateSsoStartup].
  Future<void> restore() async {
    // Completes with the emit count once the stored read after a timed-out step has settled the state.
    final settledAfterLimit = Completer<int>();
    final SessionState? settled;
    final bool timedOut;
    try {
      final SsoStartupResult result;
      (:result, :timedOut) = await _runSsoStartup(
        _ssoStartup,
        onLateAnswer: (late) => unawaited(_settleLateSsoStartup(late, settledAfterLimit.future)),
      );
      settled = switch (result) {
        SsoStartupSignInFailed(:final errorCode) => SessionUnauthenticated(
          reason: SessionExpiredReason.signInFailed,
          signInError: errorCode,
        ),
        SsoStartupSessionEnded() => const SessionUnauthenticated(reason: SessionExpiredReason.expired),
        SsoStartupUseStoredSession() => null,
      };
    } catch (e) {
      // Only the type: the step handles every failure it expects, so this one is a defect.
      _log.error('restore: the startup step failed → unauthenticated: {}', [e.runtimeType]);
      _ssoStartup.giveUp();
      if (!isClosed) {
        emit(
          const SessionUnauthenticated(
            reason: SessionExpiredReason.signInFailed,
            signInError: AppErrorCode.authOidcFailed,
          ),
        );
      }
      return;
    }
    if (isClosed) return;
    if (settled != null) {
      emit(settled);
      return;
    }
    await _restoreStoredSession();
    if (timedOut) settledAfterLimit.complete(_emitCount);
  }

  /// Runs [startup] for at most [_ssoStartupTimeLimit], after which it
  /// answers [SsoStartupUseStoredSession] with `timedOut` set, and hands
  /// what the step answers later to [onLateAnswer].
  Future<({SsoStartupResult result, bool timedOut})> _runSsoStartup(
    ISsoSessionStartup startup, {
    required void Function(SsoStartupResult late) onLateAnswer,
  }) {
    final result = Completer<({SsoStartupResult result, bool timedOut})>();
    late final Timer timer;
    timer = Timer(_ssoStartupTimeLimit, () {
      _ssoStartupTimers.remove(timer);
      _log.warn('restore: the identity provider did not answer within {} ms at startup → the stored session is read', [
        _ssoStartupTimeLimit.inMilliseconds,
      ]);
      startup.giveUp();
      result.complete((result: const SsoStartupUseStoredSession(), timedOut: true));
    });
    _ssoStartupTimers.add(timer);
    unawaited(
      startup.run().then(
        (value) {
          if (result.isCompleted) {
            onLateAnswer(value);
            return;
          }
          timer.cancel();
          _ssoStartupTimers.remove(timer);
          result.complete((result: value, timedOut: false));
        },
        onError: (Object error, StackTrace stackTrace) {
          if (result.isCompleted) {
            _log.error('restore: the startup step failed after its time limit: {}', [error.runtimeType]);
            return;
          }
          timer.cancel();
          _ssoStartupTimers.remove(timer);
          result.completeError(error, stackTrace);
        },
      ),
    );
    return result.future;
  }

  /// Acts on [late], what the startup step answered after its time limit,
  /// once [settledAfterLimit] gives the emit count at which the stored read
  /// after the limit settled the state, and only while nothing has been
  /// emitted since. A late [SsoStartupSessionEnded] has already cleared the
  /// stored session, so the session ends. Any other late answer, or one that
  /// comes after the state has changed, is only logged: the automatic
  /// redirect gate closed at the limit.
  Future<void> _settleLateSsoStartup(SsoStartupResult late, Future<int> settledAfterLimit) async {
    final settledAt = await settledAfterLimit;
    if (isClosed || _emitCount != settledAt) {
      _log.warn('restore: the startup step answered after its time limit, the state changed since, ignored: {}', [
        late.runtimeType,
      ]);
      return;
    }
    _log.info('restore: the startup step answered after its time limit: {}', [late.runtimeType]);
    switch (late) {
      case SsoStartupSessionEnded():
        await endSession(reason: SessionExpiredReason.expired);
      case SsoStartupSignInFailed() || SsoStartupUseStoredSession():
        break;
    }
  }

  /// Settles [state] from the stored session, see [restore].
  ///
  /// A stored session that this build cannot serve is cleared before its
  /// ending state is emitted, and that clear has its own restore time limit,
  /// so a storage that hangs on delete cannot keep the startup spinner: when
  /// the limit passes first, the clear is logged at error level and the
  /// session ends anyway.
  Future<void> _restoreStoredSession() async {
    final storedSession = _readStoredSession();
    final timeLimit = StartupStorageTimeLimit(storedSession, duration: _restoreTimeLimit);
    _restoreTimeLimits.add(timeLimit);
    final _StoredSession session;
    try {
      session = await timeLimit.result;
    } on TimeoutException {
      _log.error(
        'restore: secure storage did not answer within {} ms → unauthenticated until it answers or the user signs in',
        [_restoreTimeLimit.inMilliseconds],
      );
      // Not const: only this instance is the sign-out of this restore, so a
      // late answer can tell that nobody has signed in or out since.
      final timedOut = SessionUnauthenticated(reason: SessionExpiredReason.storageTimeout);
      emit(timedOut);
      unawaited(storedSession.then((stored) => _settleLate(stored, timedOut)));
      return;
    } finally {
      _restoreTimeLimits.remove(timeLimit);
    }
    switch (session) {
      case _EndAndClear(:final ending):
        await _endUnusableSession(ending);
      case _Settled(:final state):
        emit(state);
    }
  }

  /// Settles [state] from [stored], which [restore] read only after its
  /// time limit had signed the user out with [timedOut].
  ///
  /// A stored session to end is cleared only while [timedOut] is still the
  /// state when the clear starts, and its ending state is emitted only if it
  /// still is once the clear completes, so a late answer never wipes or
  /// signs out a session the user signed in to meanwhile.
  Future<void> _settleLate(_StoredSession stored, SessionUnauthenticated timedOut) async {
    if (isClosed || !identical(state, timedOut)) {
      _log.warn('restore: secure storage answered after the time limit, ignored: {}', [stored.state]);
      return;
    }
    _log.info('restore: secure storage answered after the time limit, nobody signed in or out since → {}', [
      stored.state,
    ]);
    switch (stored) {
      case _EndAndClear(:final ending):
        await _endUnusableSession(ending, signedOutBy: timedOut);
      case _Settled(:final state):
        emit(state);
    }
  }

  /// Clears the stored session that [_readStoredSession] could not serve and
  /// emits [ending], with its sign-in error, as the end of the restore.
  /// [endSession] cannot do this, because it emits no sign-in error.
  ///
  /// Without [signedOutBy], the restore answered in time: the clear is
  /// bounded by the restore time limit and [ending] is emitted either way.
  /// With [signedOutBy], the late answer of a restore whose time limit
  /// emitted that state: [ending] is emitted only while [signedOutBy] is
  /// still the state once the clear completes.
  Future<void> _endUnusableSession(SessionUnauthenticated ending, {SessionUnauthenticated? signedOutBy}) async {
    final clear = _clearUnusableSession(ending.reason);
    if (signedOutBy == null) {
      final timeLimit = StartupStorageTimeLimit(clear, duration: _restoreTimeLimit);
      _restoreTimeLimits.add(timeLimit);
      try {
        await timeLimit.result;
      } on TimeoutException {
        _log.error('restore: clearing the stored session did not finish within {} ms → signed out ({}) anyway', [
          _restoreTimeLimit.inMilliseconds,
          ending.reason.name,
        ]);
      } finally {
        _restoreTimeLimits.remove(timeLimit);
      }
    } else {
      await clear;
    }
    if (isClosed) return;
    if (signedOutBy != null && !identical(state, signedOutBy)) {
      _log.warn('restore: the user signed in or out while the stored session was cleared, ignored: {}', [ending]);
      return;
    }
    emit(ending);
  }

  /// Clears the stored session through [IAuthSessionRepository.clear], and
  /// logs a failed clear at error level as [endSession] does.
  Future<void> _clearUnusableSession(SessionExpiredReason reason) async {
    switch (await _sessionRepository.clear()) {
      case Success():
        _log.info('restore({}): stored session cleared', [reason.name]);
      case Failure(:final error):
        // A secure storage failure on the device, so its message holds no server text.
        _log.error('restore({}): stored session not fully cleared: {} {}', [reason.name, error, error.message]);
    }
  }

  /// The session that the stored token and target prove, for [restore]: the
  /// startup step has checked its expiry, so a stored token is a session for
  /// its stored target.
  ///
  /// It never clears storage itself: this future goes on after the restore
  /// time limit, and could wipe a session the user signed in to meanwhile.
  /// A stored session to end comes back as [_EndAndClear], and the clear
  /// runs only where its state is about to be emitted.
  Future<_StoredSession> _readStoredSession() async {
    // ISecureStorage.read can throw on platform / decryption failure.
    // restore() is invoked fire-and-forget from BlocProvider, so any
    // escaping exception becomes an unhandled async error. Wrap the
    // read + decision in try/catch and treat any failure as
    // unauthenticated — the safe default that forces a fresh login
    // rather than leaving the cubit in `unknown` forever.
    try {
      final token = await _secureStorage.read(SecureStorageKeys.jwtToken.key);
      final hasToken = SecurityUtils.hasToken(token);
      if (!hasToken) {
        _log.info('restore: no token in secure storage → unauthenticated');
        return const _Settled(SessionUnauthenticated(reason: SessionExpiredReason.noToken));
      }
      final storedTarget = await _secureStorage.read(SecureStorageKeys.sessionTarget.key);
      if (storedTarget == null) {
        // Upgrade rule, deliberate and not a silent fallback: app version 1.0.0 and earlier stored no target, and
        // every session they stored is a Studio session. Remove this rule once no supported upgrade source predates
        // the sessionTarget key.
        _log.info(
          'restore: token found without a stored target, stored before targets existed → Studio (upgrade rule)',
        );
        return const _Settled(SessionAuthenticated(target: SessionTarget.studio));
      }
      final target = SessionTarget.fromStoredValue(storedTarget);
      if (target == null) {
        // The length only: the value is unknown, so it is never printed.
        _log.warn('restore: the stored session target is unreadable ({} characters) → the stored session is cleared', [
          storedTarget.length,
        ]);
        return const _EndAndClear(SessionUnauthenticated(reason: SessionExpiredReason.corruptSession));
      }
      if (!_availableTargets.contains(target)) {
        // Every build serves Studio (see the constructor), so the target this build cannot serve is Platform.
        _log.warn(
          'restore: the stored session is for {}, which this build cannot serve → the stored session is cleared',
          [target.name],
        );
        return const _EndAndClear(
          SessionUnauthenticated(
            reason: SessionExpiredReason.signInFailed,
            signInError: AppErrorCode.platformNotConfigured,
          ),
        );
      }
      _log.info('restore: token found for {}, its expiry checked by the startup step → authenticated', [target.name]);
      return _Settled(SessionAuthenticated(target: target));
    } catch (e, st) {
      _log.error('restore: secure storage read failed → unauthenticated (safe default): {}\n{}', [e, st]);
      return const _Settled(SessionUnauthenticated(reason: SessionExpiredReason.storageError));
    }
  }

  /// Flips the cubit into [SessionAuthenticated] for [target]. Caller-trusted:
  /// used after a sign-in has persisted the session via
  /// [AuthSessionRepository.persist] and its backend has accepted the account.
  /// Does not re-read storage.
  void markAuthenticated(SessionTarget target) {
    emit(SessionAuthenticated(target: target));
  }

  /// Flips the cubit into [SessionUnauthenticated] with
  /// [SessionExpiredReason.noToken]. Caller-trusted: used after the explicit
  /// logout flow (`LoginRepository.logout`) has cleared the stored session
  /// through [IAuthSessionRepository.clear], or failed to clear all of it:
  /// like [endSession], the logout ends the session either way. Any other
  /// path that ends a session calls [endSession] instead.
  void markLoggedOut() {
    emit(const SessionUnauthenticated(reason: SessionExpiredReason.noToken));
  }

  /// Ends the session: wipes the stored session through
  /// [IAuthSessionRepository.clear], the same cleanup the explicit logout
  /// runs, then emits [SessionUnauthenticated] with [reason] unless the
  /// cubit is already signed out. Used by the idle timeout and by a 401
  /// that a token refresh cannot fix, so a restart cannot restore a
  /// session they ended.
  ///
  /// The wipe depends on what is stored, not on [state]. It is skipped
  /// when no session value is stored, so a 401 from a request still in flight when
  /// the user signed out leaves storage alone. A stored token is
  /// wiped even when the cubit is signed out, so no session the app has
  /// ended stays stored for a restart to restore. The wipe ends the
  /// session generation, so a token refresh still on its way does not
  /// leave its rotated tokens stored: it drops them, or takes back what
  /// it stored when the wipe ran meanwhile.
  ///
  /// A failed wipe is logged at error level with the storage error, which
  /// names each step that failed, and the in-memory session still ends:
  /// staying signed in would defeat the idle timeout, and after an
  /// unrefreshable 401 the server has already rejected the session. A
  /// token left behind lets the next launch restore the session; a
  /// session key or cached responses left behind do not.
  Future<void> endSession({required SessionExpiredReason reason}) async {
    if (await _hasStoredSession()) {
      switch (await _sessionRepository.clear()) {
        case Success():
          _log.info('endSession({}): stored session cleared', [reason.name]);
        case Failure(:final error):
          // A secure storage failure on the device, so its message holds no server text (AppError.toString leaves it
          // out).
          _log.error('endSession({}): stored session not fully cleared: {} {}', [reason.name, error, error.message]);
      }
    } else {
      _log.debug('endSession({}): no stored session to clear', [reason.name]);
    }
    if (state is! SessionUnauthenticated) emit(SessionUnauthenticated(reason: reason));
  }

  /// Whether secure storage holds a JWT, a refresh token or a session
  /// target, so a target left alone in storage is wiped too. A failed read
  /// counts as stored, so [endSession] wipes rather than leaves a session
  /// it could not inspect.
  Future<bool> _hasStoredSession() async {
    try {
      for (final key in [SecureStorageKeys.jwtToken, SecureStorageKeys.refreshToken, SecureStorageKeys.sessionTarget]) {
        if (await _secureStorage.read(key.key) != null) return true;
      }
      return false;
    } catch (e) {
      _log.error('endSession: reading the stored session failed, clearing it anyway: {}', [e]);
      return true;
    }
  }

  /// Re-run [restore] from current secure-storage state. Fire-and-
  /// forget safe: see [restore] for the failure semantics. In an `oidc`
  /// build this runs the startup step again first, through [restore]: it
  /// refreshes the access token when it has expired.
  Future<void> refresh() => restore();

  @override
  Future<void> close() {
    for (final timeLimit in _restoreTimeLimits) {
      timeLimit.cancel();
    }
    _restoreTimeLimits.clear();
    for (final timer in _ssoStartupTimers) {
      timer.cancel();
    }
    _ssoStartupTimers.clear();
    return super.close();
  }
}

/// What [SessionCubit._readStoredSession] found in the stored session.
sealed class _StoredSession {
  const _StoredSession();

  /// The state the restore emits for it.
  SessionState get state;
}

/// A stored session to settle [state] from as it is.
final class _Settled extends _StoredSession {
  const _Settled(this.state);

  @override
  final SessionState state;
}

/// A stored session that this build cannot serve: it is cleared, and the session ends with [ending].
final class _EndAndClear extends _StoredSession {
  const _EndAndClear(this.ending);

  final SessionUnauthenticated ending;

  @override
  SessionState get state => ending;
}
