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

  final bool isDark;

  /// Null when the page cannot change the theme, which leaves the badge non-interactive.
  final VoidCallback? onToggleTheme;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(8);
    final badge = Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: radius,
        border: Border.all(color: cs.outline),
      ),
      child: Icon(isDark ? Icons.dark_mode_outlined : Icons.light_mode_outlined, size: 18, color: cs.onSurfaceVariant),
    );

    final onToggle = onToggleTheme;
    if (onToggle == null) return badge;

    // The 36 pt box stays what is drawn; the tap area around it is the minimum. An InkWell does not pad its hit area
    // the way a ButtonStyleButton's MaterialTapTargetSize.padded does, so before this the drawn box was the whole
    // target — a 36 pt corner control, which is the hardest kind to hit.
    return Tooltip(
      message: isDark ? S.of(context).login_switch_to_light_mode : S.of(context).login_switch_to_dark_mode,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: loginThemeToggleKey,
          onTap: onToggle,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: SizedBox.square(
            dimension: AppSizes.minTapTarget,
            child: Center(child: badge),
          ),
        ),
      ),
    );
  }

  /// Navigates on a sign-in, and says nothing on the other states.
  ///
  /// It used to raise a snack bar for each. Two of them said what the page already said: the loading one named a
  /// wait the button was already showing, and the error one repeated the line at [_errorText] **word for word**, so
  /// a screen reader read every refusal twice and the suite waited five seconds for the snack bar to go before it
  /// could assert the message appeared once (`waitForSnackBarToGo`, now gone with its four callers).
  ///
  /// The success one stays. It is the only one that says something this page does not, and it is read on the page
  /// the user has just been sent to.
}
