import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:libredb_mobile/app/connectivity/connectivity_cubit.dart';
import 'package:libredb_mobile/features/studio_status/application/studio_status_bloc.dart';
import 'package:libredb_mobile/features/studio_status/application/studio_status_event.dart';
import 'package:libredb_mobile/shared/widgets/offline_status.dart';

/// Tells every screen below it whether the device is offline, through [OfflineStatus], and checks Studio again when
/// the device comes back online, so the unreachable page shown while it was offline clears without a Retry.
///
/// `App` places it above `MaterialApp`, below `AppScope`, which provides [ConnectivityCubit] and [StudioStatusBloc].
class AppConnectivityScope extends StatelessWidget {
  const AppConnectivityScope({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ConnectivityCubit, ConnectivityState>(
      listenWhen: (previous, current) => previous.isOffline && current.isOnline,
      listener: (context, _) => context.read<StudioStatusBloc>().add(
        const StudioLivenessCheckRequested(trigger: StudioLivenessCheckTrigger.reconnect),
      ),
      buildWhen: (previous, current) => previous.isOffline != current.isOffline,
      builder: (context, state) => OfflineStatus(isOffline: state.isOffline, child: child),
    );
  }
}
