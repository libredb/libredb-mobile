part of 'session_target_switch_bloc.dart';

sealed class SessionTargetSwitchEvent extends Equatable {
  const SessionTargetSwitchEvent();

  @override
  List<Object?> get props => const [];
}

/// Switches the live session to [to], the target it is not on.
final class SessionTargetSwitchRequested extends SessionTargetSwitchEvent {
  const SessionTargetSwitchRequested(this.to);

  final SessionTarget to;

  @override
  List<Object?> get props => [to];
}
