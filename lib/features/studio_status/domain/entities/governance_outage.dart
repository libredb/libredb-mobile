import 'package:equatable/equatable.dart';
import 'package:libredb_mobile/features/studio_status/domain/entities/studio_readiness.dart';

/// How the app words a governance outage.
enum GovernanceOutageKind {
  /// Studio will serve connections again by itself: its snapshot is old, unavailable or still loading.
  temporarilyUnavailable,

  /// Studio cannot serve connections until an operator fixes the governance source or upgrades one side.
  cannotServeConnections,
}

/// A governance outage: a connection route answered 503 `GOVERNANCE_UNAVAILABLE`, and readiness chose the wording.
///
/// [detail] is Studio's own words about a misconfigured or incompatible source, which only an administrator sees.
final class GovernanceOutage extends Equatable {
  const GovernanceOutage({required this.kind, this.detail});

  /// The outage when readiness says nothing more, or could not be read.
  const GovernanceOutage.temporary() : kind = GovernanceOutageKind.temporarilyUnavailable, detail = null;

  /// The wording that [readiness], read after a connection route answered `GOVERNANCE_UNAVAILABLE`, calls for.
  ///
  /// The route's answer is the outage, so a readiness of ready or ok, read a moment later, does not end it.
  factory GovernanceOutage.fromReadiness(StudioReadiness readiness) => switch (readiness) {
    StudioReadinessDegraded() ||
    StudioReadinessLoading() ||
    StudioReadinessReady() ||
    StudioReadinessOk() => const GovernanceOutage.temporary(),
    StudioReadinessMisconfigured(:final detail) || StudioReadinessIncompatible(:final detail) => GovernanceOutage(
      kind: GovernanceOutageKind.cannotServeConnections,
      detail: detail,
    ),
  };

  final GovernanceOutageKind kind;
  final String? detail;

  @override
  List<Object?> get props => [kind, detail];
}
