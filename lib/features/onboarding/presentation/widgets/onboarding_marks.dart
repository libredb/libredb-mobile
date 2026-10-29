import 'package:flutter/material.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/shared/design_system/theme/environment_colors.dart';
import 'package:libredb_mobile/shared/design_system/tokens/app_typography.dart';
import 'package:libredb_mobile/shared/design_system/tokens/tokens.dart';
import 'package:libredb_mobile/shared/models/studio_environment.dart';

/// The marks of a connection row as the approved introduction draws them.
///
/// These are the prototype's, not the connection list's: `EnvironmentBadge` and `ReadOnlyChip` are shared with the real
/// list, where the badge is a pill (#375) and the chip a filled one, and the prototype's are a 4-radius badge and an
/// outlined pill. The introduction is the one place that follows the prototype, so it draws its own and leaves the
/// shared widgets, and the decision recorded on them, alone.
///
/// Both set their one line at 14, the height the prototype's 11px mono takes in headless Chrome, so the box round it
/// is the same under Ahem and the product font.
const double _markSize = 11;
const double _markLine = 14 / _markSize;
const double _markInsetX = 6;
const double _markInsetY = 3;

/// The prototype's `.bdg`: `font-family:var(--mono);font-size:11px;font-weight:700;letter-spacing:.1em;
/// padding:3px 6px;border-radius:4px`.
///
/// Production is the filled red with black ink, as the real list draws it; every other environment is the quiet ink
/// on the theme's fill, which is what `.bdg` falls back to (`background:var(--fill);color:var(--quiet)`).
class OnboardingBadge extends StatelessWidget {
  const OnboardingBadge({required this.environment, super.key, this.color});

  final String environment;

  /// The operator's `#rrggbb` colour of the connection, when it has one.
  final String? color;

  @override
  Widget build(BuildContext context) {
    final label = StudioEnvironment.label(environment);
    if (label == null) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final accent = EnvironmentAccent.resolve(environment: environment, color: color, scheme: scheme);
    final production = environment == StudioEnvironment.production;
    return Semantics(
      label: S.of(context).connection_environment_badge(label),
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: production ? accent.badgeBackground : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: _markInsetX, vertical: _markInsetY),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontFamily: AppTypography.mono,
              fontSize: _markSize,
              height: _markLine,
              fontWeight: FontWeight.w700,
              letterSpacing: _markSize * 0.1,
              color: production ? accent.badgeForeground : scheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

/// The prototype's `.ro`: `font-family:var(--mono);font-size:11px;letter-spacing:.07em;padding:3px 6px;
/// border-radius:999px;border:1px solid var(--edge);color:var(--quiet)` — the words in an outlined pill, no fill.
class OnboardingReadOnlyPill extends StatelessWidget {
  const OnboardingReadOnlyPill({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final label = S.of(context).connection_read_only;
    return Semantics(
      label: label,
      excludeSemantics: true,
      // A `Container`, not a `DecoratedBox` round a `Padding`: CSS puts the 1px border outside the padding, and
      // only the `Container` adds a decoration's border to its padding.
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: scheme.outline),
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        padding: const EdgeInsets.symmetric(horizontal: _markInsetX, vertical: _markInsetY),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            fontFamily: AppTypography.mono,
            fontSize: _markSize,
            height: _markLine,
            fontWeight: FontWeight.w400,
            letterSpacing: _markSize * 0.07,
            color: scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
