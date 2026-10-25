import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:libredb_mobile/features/platform_status/application/platform_status_bloc.dart';
import 'package:libredb_mobile/features/platform_status/application/platform_status_event.dart';
import 'package:libredb_mobile/features/platform_status/application/platform_status_state.dart';
import 'package:libredb_mobile/features/studio_status/application/studio_status_bloc.dart';
import 'package:libredb_mobile/features/studio_status/application/studio_status_event.dart';
import 'package:libredb_mobile/features/studio_status/application/studio_status_state.dart';
import 'package:libredb_mobile/shared/models/session_target.dart';
import 'package:libredb_mobile/shared/models/target_reachability.dart';
import 'package:libredb_mobile/shared/widgets/target_reachability_scope.dart';

/// Provides [TargetReachabilityScope] to [child] from [StudioStatusBloc] and [PlatformStatusBloc], so the login page
/// shows on each entry whether its own server answers, and its Retry asks only that server again.
///
/// Only an unreachable state blocks an entry: Studio's governance outage says nothing about the sign-in.
class AppTargetReachability extends StatefulWidget {
  const AppTargetReachability({super.key, required this.child});

  final Widget child;

  @override
  State<AppTargetReachability> createState() => _AppTargetReachabilityState();
}

class _AppTargetReachabilityState extends State<AppTargetReachability> {
  /// A method tear-off of this state, so it stays equal across rebuilds and a rebuild notifies no reader for nothing.
  void _retry(SessionTarget target) => switch (target) {
    SessionTarget.studio => context.read<StudioStatusBloc>().add(
      const StudioLivenessCheckRequested(trigger: StudioLivenessCheckTrigger.retry),
    ),
    SessionTarget.platform => context.read<PlatformStatusBloc>().add(
      const PlatformLivenessCheckRequested(trigger: PlatformLivenessCheckTrigger.retry),
    ),
  };

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<StudioStatusBloc, StudioStatusState>(
      builder: (context, studio) => BlocBuilder<PlatformStatusBloc, PlatformStatusState>(
        builder: (context, platform) => TargetReachabilityScope(
          studio: switch (studio) {
            StudioStatusUnknown() => TargetReachability.unknown,
            StudioReachable() || StudioGovernanceUnavailable() => TargetReachability.reachable,
            StudioUnreachable(retrying: true) => TargetReachability.checking,
            StudioUnreachable() => TargetReachability.unreachable,
          },
          platform: switch (platform) {
            PlatformStatusUnknown() => TargetReachability.unknown,
            PlatformReachable() => TargetReachability.reachable,
            PlatformUnreachable(retrying: true) => TargetReachability.checking,
            PlatformUnreachable() => TargetReachability.unreachable,
          },
          onRetry: _retry,
          child: widget.child,
        ),
      ),
    );
  }
}
