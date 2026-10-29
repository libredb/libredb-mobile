import 'package:flutter/material.dart';
import 'package:libredb_mobile/core/testing/app_key_constants.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/shared/design_system/tokens/tokens.dart';

/// The light/dark switch in the corner of the login page.
///
/// It is a badge rather than a button, and it keeps its own disabled form for a build that passes no
/// [onToggleTheme]: the page is shown by tests and by the misconfigured build, and neither has a theme to toggle.
class LoginThemeBadge extends StatelessWidget {
  const LoginThemeBadge({super.key, required this.isDark, this.onToggleTheme});

  /// The side of the switch that is drawn: 36 pt, smaller than the hit area around it.
  static const double _size = 36;

  final bool isDark;

  /// Null when the page cannot change the theme, which leaves the badge non-interactive.
  final VoidCallback? onToggleTheme;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(AppRadius.lg);
    final glyph = Icon(isDark ? Icons.dark_mode_outlined : Icons.light_mode_outlined, size: 18);

    final onToggle = onToggleTheme;
    if (onToggle == null) {
      return Container(
        width: _size,
        height: _size,
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: radius,
          border: Border.all(color: cs.outline),
        ),
        child: IconTheme.merge(
          data: IconThemeData(color: cs.onSurfaceVariant),
          child: glyph,
        ),
      );
    }

    // The switch is drawn at [_size] while its hit area is [AppSizes.minTapTarget], because a 36 pt control in a
    // corner is the hardest kind to hit (#357). Those two sizes have to be allowed to differ, which is why this is a
    // `ButtonStyleButton` and not an `InkWell`: `MaterialTapTargetSize.padded` grows the hit area *around* the button
    // and leaves the ink on the button's own shape. An `InkWell` inks whatever box it is handed, so when the hit area
    // grew the splash grew with it — a 48 pt pill drawn behind a 36 pt rounded square, bigger than the control and a
    // different shape from it (#414).
    // `IconButton.tooltip` rather than a `Tooltip` around it, because the button builds a semantics node of its own:
    // a wrapping `Tooltip` leaves its label on the ancestor and the node that carries the tap unnamed, which
    // `login_screen_a11y_test.dart` reads as an unnamed target.
    return IconButton(
      key: loginThemeToggleKey,
      onPressed: onToggle,
      icon: glyph,
      tooltip: isDark ? S.of(context).login_switch_to_light_mode : S.of(context).login_switch_to_dark_mode,
      style: IconButton.styleFrom(
        backgroundColor: cs.surfaceContainerHighest,
        foregroundColor: cs.onSurfaceVariant,
        elevation: 0,
        fixedSize: const Size.square(_size),
        minimumSize: const Size.square(_size),
        padding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: cs.outline),
        ),
        tapTargetSize: MaterialTapTargetSize.padded,
      ),
    );
  }
}
