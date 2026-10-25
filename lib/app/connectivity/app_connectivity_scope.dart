import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:libredb_mobile/app/connectivity/connectivity_cubit.dart';
import 'package:libredb_mobile/features/platform_status/application/platform_status_bloc.dart';
import 'package:libredb_mobile/features/platform_status/application/platform_status_event.dart';
import 'package:libredb_mobile/features/platform_status/application/platform_status_state.dart';
import 'package:libredb_mobile/features/studio_status/application/studio_status_bloc.dart';
import 'package:libredb_mobile/features/studio_status/application/studio_status_event.dart';
import 'package:libredb_mobile/features/studio_status/application/studio_status_state.dart';
import 'package:libredb_mobile/shared/widgets/offline_status.dart';

/// Tells every screen below it whether the device is offline, through [OfflineStatus], and checks Studio again when
/// the device comes back online while Studio is unreachable, so the unreachable page shown while it was offline clears
/// without a Retry. With [checksPlatform] it does the same for Platform.
///
/// `App` places it above `MaterialApp`, below `AppScope`, which provides [ConnectivityCubit], [StudioStatusBloc] and
/// [PlatformStatusBloc].
class AppConnectivityScope extends StatelessWidget {
  const AppConnectivityScope({super.key, this.checksPlatform = false, required this.child});

  /// Whether the build has a Platform target, so a reconnect also checks Platform; `App` passes it from the build's
  /// configuration, and a build without one never asks Platform.
  final bool checksPlatform;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BlocListener<ConnectivityCubit, ConnectivityState>(
      // Only an unreachable state needs the check: while Platform answered, one probe that fails right after a
      // reconnect would cover a screen that works. A build without a Platform target never asks Platform.
      listenWhen: (previous, current) =>
          checksPlatform &&
          previous.isOffline &&
          current.isOnline &&
          switch (context.read<PlatformStatusBloc>().state) {
            PlatformUnreachable() => true,
            PlatformStatusUnknown() || PlatformReachable() => false,
          },
      listener: (context, _) => context.read<PlatformStatusBloc>().add(
        const PlatformLivenessCheckRequested(trigger: PlatformLivenessCheckTrigger.reconnect),
      ),
      child: BlocConsumer<ConnectivityCubit, ConnectivityState>(
        // Only the unreachable page needs the check: while Studio answered, one probe that fails right after a
        // reconnect would cover a screen that works.
        listenWhen: (previous, current) =>
            previous.isOffline &&
            current.isOnline &&
            switch (context.read<StudioStatusBloc>().state) {
              StudioUnreachable() => true,
              StudioStatusUnknown() || StudioReachable() || StudioGovernanceUnavailable() => false,
            },
        listener: (context, _) => context.read<StudioStatusBloc>().add(
          const StudioLivenessCheckRequested(trigger: StudioLivenessCheckTrigger.reconnect),
        ),
        buildWhen: (previous, current) => previous.isOffline != current.isOffline,
        builder: (context, state) => OfflineStatus(isOffline: state.isOffline, child: child),
      ),
    );
  }
}
