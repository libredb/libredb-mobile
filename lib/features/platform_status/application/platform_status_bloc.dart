import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:libredb_mobile/core/logging/app_logger.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/platform_status/application/platform_status_event.dart';
import 'package:libredb_mobile/features/platform_status/application/platform_status_state.dart';
import 'package:libredb_mobile/features/platform_status/application/usecases/check_platform_liveness_usecase.dart';
import 'package:libredb_mobile/shared/utils/event_transformers.dart';

/// Tells "Platform cannot be reached" apart from a sign-in or session failure, the mirror of `StudioStatusBloc`.
///
/// It asks nothing on its own at first: the app layer sends the first check, only in a build with a Platform target,
/// when the login page or a Platform session needs Platform. After that it checks when the user retries, when the
/// device comes back online, and when the app comes back after more than [defaultRecheckAfter] in the background. A
/// check that arrives while another runs is dropped. A failed check is [PlatformUnreachable] and never touches the
/// session, so a retry that succeeds opens the app where it was, signed in as before.
class PlatformStatusBloc extends Bloc<PlatformStatusEvent, PlatformStatusState> {
  PlatformStatusBloc({required this._checkLivenessUseCase, this._recheckAfter = defaultRecheckAfter})
    : super(const PlatformStatusUnknown()) {
    on<PlatformLivenessCheckRequested>(_onCheck, transformer: EventTransformers.dropConcurrent());
    on<PlatformAppPaused>(_onPaused);
    on<PlatformAppResumed>(_onResumed);
  }

  static final _log = AppLogger.getLogger('PlatformStatusBloc');

  /// How long the app must have been in the background before it checks Platform again when it comes back.
  static const defaultRecheckAfter = Duration(minutes: 5);

  final CheckPlatformLivenessUseCase _checkLivenessUseCase;
  final Duration _recheckAfter;

  /// Whether a check was requested since the bloc was created; a resume rechecks only after one.
  bool _asked = false;

  /// When the app went to the background, by the wall clock; null while it is in the foreground.
  DateTime? _pausedAt;

  FutureOr<void> _onCheck(PlatformLivenessCheckRequested event, Emitter<PlatformStatusState> emit) async {
    _asked = true;
    _log.debug('Checking Platform liveness ({})', [event.trigger.name]);
    switch (state) {
      case PlatformUnreachable(:final error):
        emit(PlatformUnreachable(error: error, retrying: true));
      case PlatformStatusUnknown() || PlatformReachable():
        break;
    }

    switch (await _checkLivenessUseCase()) {
      case Success():
        emit(const PlatformReachable());
      case Failure(:final error):
        _log.warn('Platform is unreachable ({}): {}', [event.trigger.name, error.code ?? error.runtimeType]);
        emit(PlatformUnreachable(error: error));
    }
  }

  void _onPaused(PlatformAppPaused event, Emitter<PlatformStatusState> emit) {
    _pausedAt ??= clock.now();
  }

  void _onResumed(PlatformAppResumed event, Emitter<PlatformStatusState> emit) {
    final pausedAt = _pausedAt;
    _pausedAt = null;
    if (pausedAt == null || !_asked) return;
    final away = clock.now().difference(pausedAt);
    if (away <= _recheckAfter) {
      _log.debug('Not checking Platform on resume: the app was in the background for {}', [away]);
      return;
    }
    add(const PlatformLivenessCheckRequested(trigger: PlatformLivenessCheckTrigger.resume));
  }
}
