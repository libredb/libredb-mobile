import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:libredb_mobile/app/connectivity/connectivity_cubit.dart';
import 'package:libredb_mobile/features/studio_status/application/studio_status_bloc.dart';
import 'package:libredb_mobile/features/studio_status/application/studio_status_event.dart';
import 'package:libredb_mobile/features/studio_status/application/studio_status_state.dart';
import 'package:libredb_mobile/shared/widgets/offline_status.dart';

/// Tells every screen below it whether the device is offline, through [OfflineStatus], and checks Studio again when
/// the device comes back online while Studio is unreachable, so the unreachable page shown while it was offline clears
/// without a Retry.
///
/// `App` places it above `MaterialApp`, below `AppScope`, which provides [ConnectivityCubit] and [StudioStatusBloc].
class AppConnectivityScope extends StatelessWidget {
  const AppConnectivityScope({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ConnectivityCubit, ConnectivityState>(
      // Only the unreachable page needs the check: while Studio answered, one probe that fails right after a reconnect
      // would cover a screen that works.
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
    );
  }
}
