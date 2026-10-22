import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:libredb_mobile/core/logging/app_logger.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/studio_status/application/studio_status_event.dart';
import 'package:libredb_mobile/features/studio_status/application/studio_status_state.dart';
import 'package:libredb_mobile/features/studio_status/application/usecases/check_studio_liveness_usecase.dart';
import 'package:libredb_mobile/features/studio_status/application/usecases/read_studio_readiness_usecase.dart';
import 'package:libredb_mobile/features/studio_status/domain/entities/governance_outage.dart';
import 'package:libredb_mobile/shared/utils/event_transformers.dart';

/// Tells "Studio cannot be reached" apart from a sign-in or session failure, and words a governance outage.
///
/// It checks Studio's liveness when the app starts, without waiting for the session restore, when the user retries
/// from the unreachable page, and when the app comes back after more than [defaultRecheckAfter] in the background. A
/// check that arrives while another runs is dropped. A failed check is [StudioUnreachable] and never touches the
/// session, so a retry that succeeds opens the app where it was, signed in as before.
///
/// The trigger for a governance outage is a connection route's own 503 `GOVERNANCE_UNAVAILABLE`, reported with
/// [StudioGovernanceOutageReported]; readiness only chooses the wording. A readiness that cannot be read still shows
/// the outage, worded as temporary, and logs why.
class StudioStatusBloc extends Bloc<StudioStatusEvent, StudioStatusState> {
  StudioStatusBloc({
    required this._checkLivenessUseCase,
    required this._readReadinessUseCase,
    this._recheckAfter = defaultRecheckAfter,
  }) : super(const StudioStatusUnknown()) {
    on<StudioLivenessCheckRequested>(_onCheck, transformer: EventTransformers.dropConcurrent());
    on<StudioAppPaused>(_onPaused);
    on<StudioAppResumed>(_onResumed);
    on<StudioGovernanceOutageReported>(_onOutageReported, transformer: EventTransformers.dropConcurrent());
    on<StudioGovernanceRecovered>(_onRecovered);
  }

  static final _log = AppLogger.getLogger('StudioStatusBloc');

  /// How long the app must have been in the background before it checks Studio again when it comes back.
  static const defaultRecheckAfter = Duration(minutes: 5);

  final CheckStudioLivenessUseCase _checkLivenessUseCase;
  final ReadStudioReadinessUseCase _readReadinessUseCase;
  final Duration _recheckAfter;

  /// When the app went to the background, by the wall clock; null while it is in the foreground.
  DateTime? _pausedAt;

  FutureOr<void> _onCheck(StudioLivenessCheckRequested event, Emitter<StudioStatusState> emit) async {
    _log.debug('Checking Studio liveness ({})', [event.trigger.name]);
    switch (state) {
      case StudioUnreachable(:final error):
        emit(StudioUnreachable(error: error, retrying: true));
      case StudioStatusUnknown() || StudioReachable() || StudioGovernanceUnavailable():
        break;
    }

    final result = await _checkLivenessUseCase();

    switch (result) {
      case Success():
        switch (state) {
          // Liveness says nothing about governance, so an outage stays until a connection route answers again.
          case StudioGovernanceUnavailable():
            break;
          case StudioStatusUnknown() || StudioReachable() || StudioUnreachable():
            emit(const StudioReachable());
        }
      case Failure(:final error):
        _log.warn('Studio is unreachable ({}): {}', [event.trigger.name, error.code ?? error.runtimeType]);
        emit(StudioUnreachable(error: error));
    }
  }

  void _onPaused(StudioAppPaused event, Emitter<StudioStatusState> emit) {
    _pausedAt ??= clock.now();
  }

  void _onResumed(StudioAppResumed event, Emitter<StudioStatusState> emit) {
    final pausedAt = _pausedAt;
    _pausedAt = null;
    if (pausedAt == null) return;
    final away = clock.now().difference(pausedAt);
    if (away <= _recheckAfter) {
      _log.debug('Not checking Studio on resume: the app was in the background for {}', [away]);
      return;
    }
    add(const StudioLivenessCheckRequested(trigger: StudioLivenessCheckTrigger.resume));
  }

  FutureOr<void> _onOutageReported(StudioGovernanceOutageReported event, Emitter<StudioStatusState> emit) async {
    final result = await _readReadinessUseCase();
    final outage = switch (result) {
      Success(:final data) => GovernanceOutage.fromReadiness(data),
      Failure(:final error) => _temporaryOutage(error.code ?? error.runtimeType),
    };
    emit(StudioGovernanceUnavailable(outage: outage));
  }

  static GovernanceOutage _temporaryOutage(Object reason) {
    _log.warn('Could not read Studio readiness, so the governance outage is worded as temporary: {}', [reason]);
    return const GovernanceOutage.temporary();
  }

  void _onRecovered(StudioGovernanceRecovered event, Emitter<StudioStatusState> emit) {
    switch (state) {
      case StudioGovernanceUnavailable():
        emit(const StudioReachable());
      case StudioStatusUnknown() || StudioReachable() || StudioUnreachable():
        break;
    }
  }
}
