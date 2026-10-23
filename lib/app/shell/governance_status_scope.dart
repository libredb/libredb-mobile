import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:libredb_mobile/features/auth/application/studio_identity_cubit.dart';
import 'package:libredb_mobile/features/studio_status/application/studio_status_bloc.dart';
import 'package:libredb_mobile/features/studio_status/application/studio_status_event.dart';
import 'package:libredb_mobile/features/studio_status/application/studio_status_state.dart';
import 'package:libredb_mobile/features/studio_status/domain/entities/governance_outage.dart';
import 'package:libredb_mobile/features/studio_status/presentation/widgets/studio_governance_notice.dart';
import 'package:libredb_mobile/shared/models/studio_identity.dart';
import 'package:libredb_mobile/shared/widgets/governance_status.dart';

/// Gives the signed-in screens below it a [GovernanceStatus] backed by the app's [StudioStatusBloc], which reads
/// Studio's readiness to word an outage, and the role from [StudioIdentityCubit], which decides whether Studio's detail
/// shows.
class GovernanceStatusScope extends StatelessWidget {
  const GovernanceStatusScope({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final status = context.read<StudioStatusBloc>();
    return GovernanceStatus(
      reportOutage: () => status.add(const StudioGovernanceOutageReported()),
      reportRecovered: () => status.add(const StudioGovernanceRecovered()),
      noticeBuilder: (_) => const _GovernanceNotice(),
      child: child,
    );
  }
}

/// The outage's wording, rebuilt when readiness or the role changes.
class _GovernanceNotice extends StatelessWidget {
  const _GovernanceNotice();

  @override
  Widget build(BuildContext context) {
    final outage = context.select<StudioStatusBloc, GovernanceOutage>(
      (bloc) => switch (bloc.state) {
        StudioGovernanceUnavailable(:final outage) || StudioUnreachable(:final outage?) => outage,
        // Readiness has not chosen the wording yet: the outage reads as temporary until it does.
        StudioStatusUnknown() || StudioReachable() || StudioUnreachable() => const GovernanceOutage.temporary(),
      },
    );
    final role = context.select<StudioIdentityCubit, StudioRole>(
      (cubit) => switch (cubit.state) {
        StudioIdentityLoaded(:final identity) => identity.role,
        // Until Studio names the role, the user gets the least the app grants.
        StudioIdentityInitial() || StudioIdentityLoading() || StudioIdentityFailure() => const StudioUserRole(),
      },
    );
    return StudioGovernanceNotice(outage: outage, role: role);
  }
}
