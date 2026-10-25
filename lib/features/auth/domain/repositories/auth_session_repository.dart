import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/auth/domain/entities/auth_session.dart';
import 'package:libredb_mobile/shared/models/session_target.dart';

/// Persists / clears the authenticated session as one logical unit.
///
/// The application layer hands this a fully-formed [AuthSession]; the
/// data layer decides how to write it (SharedPreferences keys, secure
/// storage, etc.) and is responsible for rolling back partial writes if
/// any step fails so the caller never sees a half-persisted session.
abstract class IAuthSessionRepository {
  /// Persist the session atomically. Implementations must roll back
  /// previously-written keys if a later write fails, so a partial
  /// session never lingers in storage on error.
  Future<Result<void>> persist(AuthSession session);

  /// Rewrites only the stored target of the live session, for a mode switch, and never reads or writes a token.
  ///
  /// [generation] is the session generation the switch started under (`SessionGeneration.current`): when that session
  /// has ended nothing is written, and when a wipe runs while the target is written, the target is taken back, so a
  /// sign-out or an idle timeout during a switch never leaves a target stored. A failed write restores the prior
  /// target. Any of these answers a [Failure], and the session keeps its earlier target.
  Future<Result<void>> persistTarget(SessionTarget target, {required int generation});

  /// Removes what the signed-in session stored: the tokens, the user's
  /// keys and the cached responses. Device preferences, such as the
  /// language and theme, stay. A step that fails does not stop the
  /// others, and the failures come back as one [Failure].
  Future<Result<void>> clear();
}
