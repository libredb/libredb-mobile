import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/features/studio_status/domain/entities/governance_outage.dart';
import 'package:libredb_mobile/features/studio_status/domain/entities/studio_readiness.dart';

void main() {
  group('GovernanceOutage.fromReadiness', () {
    // A stale snapshot answers 200 degraded while every connection route answers 503 GOVERNANCE_UNAVAILABLE.
    test('200 degraded is temporarily unavailable, never healthy', () {
      expect(
        GovernanceOutage.fromReadiness(const StudioReadinessDegraded()),
        const GovernanceOutage(kind: GovernanceOutageKind.temporarilyUnavailable),
      );
    });

    test('503 loading is temporarily unavailable', () {
      expect(
        GovernanceOutage.fromReadiness(const StudioReadinessLoading()),
        const GovernanceOutage(kind: GovernanceOutageKind.temporarilyUnavailable),
      );
    });

    test('misconfigured and incompatible cannot serve connections, with the detail Studio sent', () {
      expect(
        GovernanceOutage.fromReadiness(const StudioReadinessMisconfigured(detail: 'libredb_grants: 42501')),
        const GovernanceOutage(kind: GovernanceOutageKind.cannotServeConnections, detail: 'libredb_grants: 42501'),
      );
      expect(
        GovernanceOutage.fromReadiness(const StudioReadinessIncompatible(detail: 'supported 1, source 2')),
        const GovernanceOutage(kind: GovernanceOutageKind.cannotServeConnections, detail: 'supported 1, source 2'),
      );
      expect(
        GovernanceOutage.fromReadiness(const StudioReadinessIncompatible()),
        const GovernanceOutage(kind: GovernanceOutageKind.cannotServeConnections),
      );
    });

    // A connection route answered GOVERNANCE_UNAVAILABLE, so the outage is real even when readiness has recovered
    // since: the route's answer and the readiness answer were read at different moments.
    test('ready and ok are temporarily unavailable', () {
      for (final readiness in const [StudioReadinessReady(), StudioReadinessOk()]) {
        expect(
          GovernanceOutage.fromReadiness(readiness),
          const GovernanceOutage(kind: GovernanceOutageKind.temporarilyUnavailable),
          reason: '$readiness',
        );
      }
    });
  });
}
