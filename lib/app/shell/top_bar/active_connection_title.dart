import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:libredb_mobile/features/connections/presentation/widgets/connection_switcher_sheet.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/shared/active_connection/active_connection_cubit.dart';
import 'package:libredb_mobile/shared/design_system/theme/environment_colors.dart';
import 'package:libredb_mobile/shared/design_system/tokens/app_spacing.dart';
import 'package:libredb_mobile/shared/widgets/connection_badges.dart';

/// The top bar title of a tab that works on the active connection: its environment strip, name, environment label and
/// a lock when it is read-only, or [fallback], the tab title, while none is open. A tap opens the connection switcher.
class ActiveConnectionTitle extends StatelessWidget {
  const ActiveConnectionTitle({super.key, required this.fallback});

  /// The title shown while no connection is open.
  final String fallback;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final connection = context.select<ActiveConnectionCubit, ActiveConnectionState>((cubit) => cubit.state).connection;
    final textStyle = theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500);
    final List<Widget> children;
    if (connection == null) {
      children = [
        Flexible(
          child: Text(fallback, style: textStyle, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ];
    } else {
      final environment = connection.environment;
      final strip = EnvironmentAccent.resolve(
        environment: environment,
        color: connection.color,
        scheme: theme.colorScheme,
      ).strip;
      children = [
        if (strip != null)
          Container(
            key: const ValueKey('active-connection-strip'),
            width: 4,
            height: 24,
            decoration: BoxDecoration(color: strip, borderRadius: BorderRadius.circular(2)),
          ),
        Flexible(
          child: Text(connection.name, style: textStyle, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        if (EnvironmentBadge.showsFor(environment))
          EnvironmentBadge(environment: environment!, color: connection.color),
        if (connection.readOnlyForUser)
          Icon(
            Icons.lock_outline,
            size: 16,
            color: theme.colorScheme.onSurfaceVariant,
            semanticLabel: S.of(context).connection_read_only,
          ),
      ];
    }
    return Tooltip(
      message: S.of(context).connection_switcher_title,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => ConnectionSwitcherSheet.show(context),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Row(
            spacing: AppSpacing.sm,
            children: [
              ...children,
              Icon(Icons.arrow_drop_down, color: theme.colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
