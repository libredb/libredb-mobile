part of 'session_target_switch_bloc.dart';

sealed class SessionTargetSwitchState extends Equatable {
  const SessionTargetSwitchState();

  @override
  List<Object?> get props => const [];
}

/// No switch has run yet.
final class SessionTargetSwitchIdle extends SessionTargetSwitchState {
  const SessionTargetSwitchIdle();
}

/// The gate of [to] is being asked; a second request is dropped meanwhile.
final class SessionTargetSwitchInProgress extends SessionTargetSwitchState {
  const SessionTargetSwitchInProgress(this.to);

  final SessionTarget to;

  @override
  List<Object?> get props => [to];
}

/// The gate accepted the account and the new target is stored: [result] is [SwitchedToStudio] or
/// [SwitchedToPlatform], with the identity the gate answered.
final class SessionTargetSwitchSucceeded extends SessionTargetSwitchState {
  const SessionTargetSwitchSucceeded(this.result);

  final SessionTargetSwitchResult result;

  @override
  List<Object?> get props => [result];
}

/// The switch was refused and the session keeps its target; [errorCode] says why.
final class SessionTargetSwitchRefusedState extends SessionTargetSwitchState {
  const SessionTargetSwitchRefusedState(this.errorCode);

  final AppErrorCode errorCode;

  @override
  List<Object?> get props => [errorCode];
}

/// The session the switch started under ended before the switch finished, so nothing was stored and nothing is shown.
final class SessionTargetSwitchAbandonedState extends SessionTargetSwitchState {
  const SessionTargetSwitchAbandonedState();
}
