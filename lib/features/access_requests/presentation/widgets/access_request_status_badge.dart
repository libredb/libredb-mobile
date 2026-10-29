import 'package:flutter/widgets.dart';
import 'package:libredb_mobile/features/access_requests/domain/entities/my_access_request.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/shared/design_system/components/app_badge.dart';

/// The status of [request] as a badge: the four known statuses in the app language, and any other value, `expired`
/// included, as the raw value Platform sent, outlined.
class AccessRequestStatusBadge extends StatelessWidget {
  const AccessRequestStatusBadge({super.key, required this.request});

  final MyAccessRequest request;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final (label, variant) = switch (request.status) {
      AccessRequestStatus.pending => (s.access_requests_status_pending, AppBadgeVariant.warning),
      AccessRequestStatus.approved => (s.access_requests_status_approved, AppBadgeVariant.success),
      AccessRequestStatus.refused => (s.access_requests_status_refused, AppBadgeVariant.destructive),
      AccessRequestStatus.withdrawn => (s.access_requests_status_withdrawn, AppBadgeVariant.secondary),
      AccessRequestStatus.expired || AccessRequestStatus.unknown => (request.rawStatus, AppBadgeVariant.outline),
    };
    return AppBadge(label: label, variant: variant);
  }
}
