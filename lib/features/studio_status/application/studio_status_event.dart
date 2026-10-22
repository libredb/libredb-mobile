import 'package:equatable/equatable.dart';

/// What started a liveness check.
enum StudioLivenessCheckTrigger {
  /// The app started.
  launch,

  /// The user asked for one, from the unreachable page.
  retry,

  /// The app came back after more than `StudioStatusBloc.defaultRecheckAfter` in the background.
  resume,

  /// The device came back online, so an unreachable page shown while it was offline can clear without a Retry.
  reconnect,
}

sealed class StudioStatusEvent extends Equatable {
  const StudioStatusEvent();

  @override
  List<Object?> get props => const [];
}

/// Check whether Studio answers.
final class StudioLivenessCheckRequested extends StudioStatusEvent {
  const StudioLivenessCheckRequested({this.trigger = StudioLivenessCheckTrigger.launch});

  final StudioLivenessCheckTrigger trigger;

  @override
  List<Object?> get props => [trigger];
}

/// The app went to the background.
final class StudioAppPaused extends StudioStatusEvent {
  const StudioAppPaused();
}

/// The app came back to the foreground.
final class StudioAppResumed extends StudioStatusEvent {
  const StudioAppResumed();
}

/// A connection route answered 503 `GOVERNANCE_UNAVAILABLE`; the bloc reads readiness to word the outage.
final class StudioGovernanceOutageReported extends StudioStatusEvent {
  const StudioGovernanceOutageReported();
}

/// A connection route answered again after a governance outage.
final class StudioGovernanceRecovered extends StudioStatusEvent {
  const StudioGovernanceRecovered();
}
