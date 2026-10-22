import 'package:flutter/material.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/shared/design_system/components/app_empty_state.dart';

/// The body of a tab that works on one connection while no connection is open, with the way to the connection list.
class PickConnectionFirst extends StatelessWidget {
  const PickConnectionFirst({super.key, required this.icon, required this.onOpenConnections});

  final IconData icon;

  /// Opens the connection list.
  final VoidCallback onOpenConnections;

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context);
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: AppEmptyState(
            icon: icon,
            title: l10n.pick_connection_first,
            description: l10n.pick_connection_first_description,
            actionLabel: l10n.connections,
            onAction: onOpenConnections,
          ),
        ),
      ),
    );
  }
}
