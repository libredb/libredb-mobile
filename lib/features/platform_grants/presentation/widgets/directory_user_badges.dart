import 'package:flutter/material.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/shared/design_system/components/app_badge.dart';

/// The text of a Studio role as Platform's directory reports it: "Studio admin", "Studio user", the no-role text for
/// null, or an unknown value as Platform sent it.
String studioRoleLabel(S s, String? role) => switch (role) {
  'admin' => s.platform_grants_picker_role_admin,
  'user' => s.platform_grants_picker_role_user,
  null => s.platform_grants_picker_role_none,
  final other => other,
};

/// The badge of a user's Studio role.
class StudioRoleBadge extends StatelessWidget {
  const StudioRoleBadge({super.key, required this.role});

  final String? role;

  @override
  Widget build(BuildContext context) => AppBadge(
    label: studioRoleLabel(S.of(context), role),
    variant: role == null ? AppBadgeVariant.outline : AppBadgeVariant.secondary,
    icon: role == null ? Icons.block : Icons.badge_outlined,
  );
}

/// The note that a grant takes one of the license's user seats: now on an [active] connection, or once an inactive
/// one is active again.
class SeatNote extends StatelessWidget {
  const SeatNote({super.key, required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return AppBadge(
      label: active ? s.platform_grants_picker_takes_seat : s.platform_grants_picker_takes_seat_inactive,
      variant: AppBadgeVariant.warning,
      icon: Icons.event_seat_outlined,
    );
  }
}
