import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/features/auth/application/usecases/switch_session_target_usecase.dart';
import 'package:libredb_mobile/features/auth/domain/entities/session_target_switch_result.dart';
import 'package:libredb_mobile/shared/models/session_target.dart';
import 'package:libredb_mobile/shared/utils/event_transformers.dart';

part 'session_target_switch_event.dart';
part 'session_target_switch_state.dart';

/// The in-place switch of the live session between Studio and Platform, started from the profile sheet.
///
/// App-scoped, because the shell that starts a switch is disposed by it. A request while a switch runs is dropped.
/// It only asks the gate and stores the target; `AppSessionListeners` acts on [SessionTargetSwitchSucceeded], clearing
/// the mode left and opening the new one, tells the user of a [SessionTargetSwitchRefusedState], and ignores a
/// [SessionTargetSwitchAbandonedState], whose session ended while the switch ran.
class SessionTargetSwitchBloc extends Bloc<SessionTargetSwitchEvent, SessionTargetSwitchState> {
  SessionTargetSwitchBloc({required this._switchTarget}) : super(const SessionTargetSwitchIdle()) {
    on<SessionTargetSwitchRequested>(_onRequested, transformer: EventTransformers.dropConcurrent());
  }

  final SwitchSessionTargetUseCase _switchTarget;

  Future<void> _onRequested(SessionTargetSwitchRequested event, Emitter<SessionTargetSwitchState> emit) async {
    emit(SessionTargetSwitchInProgress(event.to));
    final result = await _switchTarget(event.to);
    emit(switch (result) {
      SwitchedToStudio() || SwitchedToPlatform() => SessionTargetSwitchSucceeded(result),
      SessionTargetSwitchRefused(:final errorCode) => SessionTargetSwitchRefusedState(errorCode),
      SessionTargetSwitchAbandoned() => const SessionTargetSwitchAbandonedState(),
    });
  }
}
