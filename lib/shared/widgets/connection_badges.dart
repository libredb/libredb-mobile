import 'package:flutter/material.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/shared/design_system/theme/environment_colors.dart';
import 'package:libredb_mobile/shared/design_system/tokens/app_spacing.dart';
import 'package:libredb_mobile/shared/models/studio_environment.dart';

/// A connection's environment as Studio labels it (`PROD`, `STAGING`, ...), colored by [EnvironmentAccent].
///
/// Shows nothing for `other`, which Studio shows no badge for. The label is always text, so color is never the only
/// signal, and the badge reads as 'Environment: PROD' to a screen reader.
class EnvironmentBadge extends StatelessWidget {
  const EnvironmentBadge({super.key, required this.environment, this.color});

  final String environment;

  /// The operator's `#rrggbb` color of the connection, when it has one.
  final String? color;

  /// Whether a badge shows for [environment] at all.
  static bool showsFor(String? environment) => environment != null && StudioEnvironment.label(environment) != null;

  @override
  Widget build(BuildContext context) {
    final label = StudioEnvironment.label(environment);
    if (label == null) return const SizedBox.shrink();
    final accent = EnvironmentAccent.resolve(
      environment: environment,
      color: color,
      scheme: Theme.of(context).colorScheme,
    );
    return Semantics(
      label: S.of(context).connection_environment_badge(label),
      excludeSemantics: true,
      child: _Pill(
        background: accent.badgeBackground,
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall
              ?.copyWith(color: accent.badgeForeground, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

/// Marks a connection Studio refuses every write on, with a lock and the words 'Read only'.
class ReadOnlyChip extends StatelessWidget {
  const ReadOnlyChip({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final label = S.of(context).connection_read_only;
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: _Pill(
        background: scheme.surfaceContainerHighest,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: AppSpacing.xs,
          children: [
            Icon(Icons.lock_outline, size: 12 * MediaQuery.textScalerOf(context).scale(1), color: scheme.onSurface),
            Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: scheme.onSurface)),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.background, required this.child});

  final Color background;
  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(4)),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
      child: child,
    ),
  );
}
