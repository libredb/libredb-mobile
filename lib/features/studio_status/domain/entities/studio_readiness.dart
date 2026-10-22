import 'package:equatable/equatable.dart';

/// Studio's answer to `GET /api/ready` (libredb-studio `src/app/api/ready/route.ts`, `src/lib/governance/contract.ts`).
///
/// Without governance Studio answers [StudioReadinessReady]. Under governance it answers how fresh its snapshot of
/// the grants is: 200 [StudioReadinessOk] or [StudioReadinessDegraded], or 503 [StudioReadinessLoading],
/// [StudioReadinessMisconfigured] or [StudioReadinessIncompatible]. A stale snapshot answers 200 degraded while every
/// connection route answers 503 `GOVERNANCE_UNAVAILABLE`, so degraded never means that connections can be served.
sealed class StudioReadiness extends Equatable {
  const StudioReadiness();

  @override
  List<Object?> get props => const [];
}

/// 200 `ready`: Studio runs without governance.
final class StudioReadinessReady extends StudioReadiness {
  const StudioReadinessReady();
}

/// 200 `ok`: Studio serves a fresh snapshot of the grants.
final class StudioReadinessOk extends StudioReadiness {
  const StudioReadinessOk();
}

/// 200 `degraded`: the snapshot is old or unavailable.
final class StudioReadinessDegraded extends StudioReadiness {
  const StudioReadinessDegraded();
}

/// 503 `loading`: Studio has not loaded a snapshot yet, as while it starts.
final class StudioReadinessLoading extends StudioReadiness {
  const StudioReadinessLoading();
}

/// 503 `misconfigured`: the governance source refuses Studio, and an operator must fix it. [detail] is Studio's own
/// words, naming the object or the privilege, for an administrator.
final class StudioReadinessMisconfigured extends StudioReadiness {
  const StudioReadinessMisconfigured({this.detail});

  final String? detail;

  @override
  List<Object?> get props => [detail];
}

/// 503 `incompatible`: Studio and the governance source share no contract version. [detail] names both version sets,
/// for an administrator.
final class StudioReadinessIncompatible extends StudioReadiness {
  const StudioReadinessIncompatible({this.detail});

  final String? detail;

  @override
  List<Object?> get props => [detail];
}
