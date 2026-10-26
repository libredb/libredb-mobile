import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:libredb_mobile/core/logging/app_logger.dart';
import 'package:libredb_mobile/features/onboarding/application/onboarding_state.dart';
import 'package:libredb_mobile/features/onboarding/domain/repositories/onboarding_seen_store.dart';

/// Owns whether this launch has to show the introduction. The router reads [state] to decide, and `App` waits on
/// [OnboardingRestoring] so the decision is settled before the first frame.
///
/// A Cubit, not a Bloc: [restore] and [markSeen] are single calls with nothing to debounce, no event would carry a
/// payload, and a second [markSeen] is not a different event but the same one again. The same reasoning
/// [LocaleCubit] states for the same shape.
///
/// It is also why a cubit rather than a cached static read: the redirect needs the settled answer *and* the router's
/// refresh listenable needs a stream to re-run that redirect on. A static gives the first and leaves the second
/// unsolved.
class OnboardingCubit extends Cubit<OnboardingState> {
  OnboardingCubit({required this._store}) : super(const OnboardingRestoring());

  static final _log = AppLogger.getLogger('OnboardingCubit');

  final IOnboardingSeenStore _store;

  /// Reads whether this device has shown the introduction, so the app knows before it opens a page.
  ///
  /// **A read it cannot answer means seen.** A storage hiccup must never trap a returning user in the introduction on
  /// every launch, which is the mirror of the session's rule that unauthenticated is the safe default.
  ///
  /// The failure is a log line and not an error report: falling back is the correct behaviour rather than a
  /// degradation, and a device whose preferences cannot be read has already lost its language, its theme and its
  /// lock, each of which says so itself.
  Future<void> restore() async {
    final bool seen;
    try {
      seen = await _store.read();
    } catch (e) {
      _log.warn('restore: could not read the introduction flag, leaving the introduction behind: {}', [e.runtimeType]);
      if (!isClosed) emit(const OnboardingSeen());
      return;
    }
    if (isClosed) return;
    _log.debug('restore: the introduction {} been shown on this device', [seen ? 'has' : 'has not']);
    emit(seen ? const OnboardingSeen() : const OnboardingRequired());
  }

  /// Leaves the introduction behind and records it, so the next launch opens where the app always does.
  ///
  /// The state changes **before** the write, and a device that refuses the write does not change it back: the user has
  /// finished reading the introduction, and holding them on the last panel while a slow device stores a boolean — or
  /// sending them back through it because the store refused — is worse than losing the flag once.
  /// [CollapsedSectionsCubit] settles the same question the same way.
  Future<void> markSeen() async {
    if (!isClosed) emit(const OnboardingSeen());
    try {
      await _store.write();
    } catch (e) {
      _log.warn('markSeen: not stored, the introduction will be shown again on the next launch: {}', [e.runtimeType]);
    }
  }
}
