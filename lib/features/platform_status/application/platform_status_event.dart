import 'package:equatable/equatable.dart';

/// What started a liveness check.
enum PlatformLivenessCheckTrigger {
  /// The login page or a Platform session needed Platform for the first time since the app started.
  launch,

  /// The user asked for one, from the unreachable page or the login page's Platform entry.
  retry,

  /// The app came back after more than `PlatformStatusBloc.defaultRecheckAfter` in the background.
  resume,

  /// The device came back online, so an unreachable state shown while it was offline can clear without a Retry.
  reconnect,
}

sealed class PlatformStatusEvent extends Equatable {
  const PlatformStatusEvent();

  @override
  List<Object?> get props => const [];
}

/// Check whether Platform answers.
final class PlatformLivenessCheckRequested extends PlatformStatusEvent {
  const PlatformLivenessCheckRequested({this.trigger = PlatformLivenessCheckTrigger.launch});

  final PlatformLivenessCheckTrigger trigger;

  @override
  List<Object?> get props => [trigger];
}

/// The app went to the background.
final class PlatformAppPaused extends PlatformStatusEvent {
  const PlatformAppPaused();
}

/// The app came back to the foreground.
final class PlatformAppResumed extends PlatformStatusEvent {
  const PlatformAppResumed();
}
