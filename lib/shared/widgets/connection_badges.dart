import 'package:flutter/material.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/shared/design_system/theme/environment_colors.dart';
import 'package:libredb_mobile/shared/design_system/tokens/app_radius.dart';
import 'package:libredb_mobile/shared/design_system/tokens/app_spacing.dart';
import 'package:libredb_mobile/shared/design_system/tokens/app_typography.dart';
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
        padding: _environmentPadding,
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            fontFamily: AppTypography.mono,
            color: accent.badgeForeground,
            fontWeight: FontWeight.w700,
            letterSpacing: _environmentFontSize * _environmentTracking,
          ),
        ),
      ),
    );
  }
}

/// The environment badge's own metrics, which are the approved prototype's `.bdg` rule
/// (`scratchpad/ob/ob.html`, screen 1):
///
/// ```css
/// .bdg{font-family:var(--mono);font-size:11px;font-weight:700;letter-spacing:.1em;padding:3px 6px;border-radius:4px}
/// ```
///
/// Measured in headless Chrome at 390x844 it draws **42.81 x 20** for PROD in both languages and both themes: 6 + 6
/// across and 3 + 3 down around a 30.81 x 14 text box, no border. This badge drew 50.2 on the device, because it set
/// PROD in the sans face with no tracking inside 8 + 8 of padding. The closed spacing scale has no 6 or 3, so they
/// are the badge's own, like the form widths are the forms'. The corner stays `AppRadius.pill` (#375), which the
/// prototype's 4 differs from.
const _environmentFontSize = 11.0;
const _environmentTracking = 0.1;
const _environmentInsetX = 6.0;
const _environmentInsetY = 3.0;
const _environmentPadding = EdgeInsets.symmetric(horizontal: _environmentInsetX, vertical: _environmentInsetY);

/// Marks a connection Studio refuses every write on, with the words 'Read only'.
///
/// The words and the pill around them, and nothing beside them, because that is all the approved introduction
/// prototype draws (`scratchpad/ob/ob.html`, screen 1's locked row):
///
/// ```css
/// .ro{font-family:var(--mono);font-size:11px;letter-spacing:.07em;padding:3px 6px;border-radius:999px;
///  border:1px solid var(--edge);color:var(--quiet)}
/// ```
///
/// Measured in headless Chrome at that file's own 390x844 frame, the pill comes out **80.34 x 22** in English and
/// **95.08 x 22** in Turkish around a text box of 66.34 x 14 and 81.08 x 14 — identical in light and dark. Its own
/// contribution is therefore 14 pt across (`6 + 6` of padding, `1 + 1` of border) and 8 pt down, the same number in
/// both languages, and there is no icon anywhere in the rule.
///
/// This chip used to put a lock beside the words, sized `12 * MediaQuery.textScalerOf(context).scale(1)`. That made
/// its inset 32 pt at the ordinary text size and 56 pt at x3 — measured, against the design's 14 — because the lock
/// was the one part of the chip that followed the text scaler, so the chip grew faster than the words it marked.
/// Without it the inset is `AppSpacing.sm` a side at every text size: 16 pt, the nearest the closed spacing scale
/// comes to the design's 14, and 2 pt of that is the border this filled pill does not draw.
///
/// Dropping the lock costs no meaning: [Semantics] reads the whole label to a screen reader and the words say it in
/// both languages. `connection_badges_test.dart` measures the inset against the chip's own `Text`, so the test
/// font cancels out of the subtraction and the number means something.
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
        child: Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: scheme.onSurface)),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.background,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
  });

  final Color background;
  final EdgeInsets padding;
  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    // The design system's badges are pills (`AppRadius.pill`), and this draws the same idea beside a connection; at
    // `circular(4)` the Studio side showed a rounded rectangle where the Platform side showed a pill (#375).
    decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(AppRadius.pill)),
    child: Padding(padding: padding, child: child),
  );
}
