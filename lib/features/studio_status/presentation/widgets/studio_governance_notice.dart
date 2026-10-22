import 'package:flutter/material.dart';
import 'package:libredb_mobile/features/studio_status/domain/entities/governance_outage.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/shared/design_system/tokens/app_spacing.dart';
import 'package:libredb_mobile/shared/models/studio_identity.dart';

/// The wording of a governance outage, for the banner a connection screen shows when a connection route answered 503
/// `GOVERNANCE_UNAVAILABLE`.
///
/// Studio's [GovernanceOutage.detail] names objects, privileges or contract versions of the governance source, so only
/// an admin sees it.
class StudioGovernanceNotice extends StatelessWidget {
  const StudioGovernanceNotice({super.key, required this.outage, required this.role});

  final GovernanceOutage outage;

  /// The signed-in user's role, as Studio's `GET /api/auth/me` answered it.
  final StudioRole role;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final l10n = S.of(context);
    final showsDetail = switch (role) {
      StudioAdminRole() => true,
      // An unknown role gets the least the app grants.
      StudioUserRole() || StudioUnknownRole() => false,
    };
    final detail = showsDetail ? outage.detail : null;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.cloud_off, color: colorScheme.error),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(switch (outage.kind) {
                GovernanceOutageKind.temporarilyUnavailable => l10n.studio_governance_temporarily_unavailable,
                GovernanceOutageKind.cannotServeConnections => l10n.studio_governance_cannot_serve,
              }, style: textTheme.bodyMedium),
              if (detail != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  l10n.studio_governance_detail(detail),
                  style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
