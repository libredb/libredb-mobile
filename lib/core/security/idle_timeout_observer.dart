import 'dart:async';

import 'package:clock/clock.dart' as wall;
import 'package:flutter/widgets.dart';

import 'package:libredb_mobile/core/logging/app_logger.dart';

/// Callback fired when the user has been inactive past the configured
/// idle threshold. Wiring layer translates this to
/// `SessionCubit.endSession(reason: SessionExpiredReason.idleTimeout)`.
typedef OnIdleTimeout = void Function();

/// Inactivity-based auto-logout helper.
///
/// **Wiring contract.** The observer is a passive object: it owns a
/// [Timer] that fires after [idleThreshold] of no activity and a
/// [WidgetsBindingObserver] registration that handles background /
/// foreground transitions. It does **not** know about session state or
/// the widget tree. The integration layer (see `AppSessionListeners`)
/// starts it when authenticated, stops it on logout, and pumps
/// [recordActivity] from its pointer and keyboard listeners.
///
/// **Background timing.** Dart [Timer]s pause on iOS while the app is
/// backgrounded. Relying on the timer alone would let a 12-hour
/// background pass and the user would still be logged in on resume.
/// The lifecycle callback cancels the timer on pause and, on resume,
/// compares the wall clock against [_windowStartedAt] — if the elapsed
/// time exceeds [idleThreshold], it fires immediately; otherwise it
/// resumes the timer with the remaining duration.
///
/// **The window is anchored on the last input, not on the pause.** The
/// promise is "signed out after [idleThreshold] without input", so the
/// time already spent idle in the foreground counts. Measuring only the
/// background stretch would hand back a fresh window on every lifecycle
/// blip: a phone lying untouched gets an `inactive`/`resumed` pair
/// whenever a notification banner, a system sheet or the control centre
/// appears, and the sign-out would never arrive.
///
/// **Disabled mode.** Passing `idleThreshold: null` makes every method
/// a no-op, so a build whose config sets no idle timeout (every environment
/// but prod) needs no per-call-site conditionals.
class IdleTimeoutObserver with WidgetsBindingObserver {
  IdleTimeoutObserver({required this.idleThreshold, required this.onTimeout, DateTime Function()? clock})
    : _clock = clock ?? _now;

  /// The wall clock of package:clock, which is [DateTime.now] outside a test that fakes the time, so the app lock and
  /// this observer measure the same time away.
  static DateTime _now() => wall.clock.now();

  /// Inactivity window before [onTimeout] fires. `null` disables the
  /// observer entirely.
  final Duration? idleThreshold;

  /// Callback fired on timeout. Wired by integration layer to logout.
  final OnIdleTimeout onTimeout;

  /// Wall-clock source. Injected so tests can drive elapsed time
  /// without sleeping.
  final DateTime Function() _clock;

  static final _log = AppLogger.getLogger('IdleTimeoutObserver');

  /// Minimum spacing between two activity records. High-frequency signals
  /// (e.g. `onPointerMove` during a drag/scroll) would otherwise cancel and
  /// recreate the timer on every event; throttling collapses that churn while
  /// staying well below any realistic [idleThreshold].
  static const Duration _activityThrottle = Duration(seconds: 1);

  Timer? _timer;

  /// The instant the current idle window began: [start], or the last [recordActivity] that got past the throttle.
  /// Every remaining-time answer is measured from here, so foreground and background time count the same.
  DateTime? _windowStartedAt;
  DateTime? _lastActivity;
  bool _started = false;

  /// Registers the lifecycle observer and starts the idle timer.
  /// Idempotent: a second call while already started is a no-op.
  void start() {
    if (idleThreshold == null || _started) return;
    WidgetsBinding.instance.addObserver(this);
    _resetTimer();
    _started = true;
    _log.debug('start — threshold={}s', [idleThreshold!.inSeconds]);
  }

  /// Cancels the timer and removes the lifecycle observer.
  /// Idempotent: a second call after stop is a no-op.
  void stop() {
    if (!_started) return;
    _cancelTimer();
    _windowStartedAt = null;
    _lastActivity = null;
    WidgetsBinding.instance.removeObserver(this);
    _started = false;
    _log.debug('stop');
  }

  /// Pings the observer from the activity listener. Resets the timer
  /// so the user has another [idleThreshold] window of inactivity
  /// before logout.
  void recordActivity() {
    if (!_started || idleThreshold == null) return;
    final now = _clock();
    final last = _lastActivity;
    if (last != null && now.difference(last) < _activityThrottle) return;
    _lastActivity = now;
    _resetTimer();
  }

  void _resetTimer() {
    final threshold = idleThreshold;
    if (threshold == null) return;
    _windowStartedAt = _clock();
    _scheduleTimeout(threshold);
  }

  void _scheduleTimeout(Duration after) {
    _cancelTimer();
    _timer = Timer(after, _fire);
  }

  void _cancelTimer() {
    _timer?.cancel();
    _timer = null;
  }

  void _fire() {
    _log.info('idle threshold reached — firing onTimeout');
    onTimeout();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (idleThreshold == null) return;
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.inactive:
        // A Dart Timer does not run while the app is away, so it would fire late by the time spent there. Cancel it
        // and let the resume branch do the arithmetic against the wall clock. The window anchor is left alone: time
        // away is idle time like any other.
        _cancelTimer();
      case AppLifecycleState.resumed:
        final windowStartedAt = _windowStartedAt;
        if (windowStartedAt == null) return;
        final elapsed = _clock().difference(windowStartedAt);
        if (elapsed >= idleThreshold!) {
          _log.info('resumed {}s after the last input, past the {}s threshold', [
            elapsed.inSeconds,
            idleThreshold!.inSeconds,
          ]);
          _fire();
          return;
        }
        final remaining = idleThreshold! - elapsed;
        _log.debug('resumed; remaining {}ms before timeout', [remaining.inMilliseconds]);
        _scheduleTimeout(remaining);
      case AppLifecycleState.detached:
        // Process is detaching; stop() will be called by the host or
        // the app is closing. No work here.
        break;
    }
  }
}
