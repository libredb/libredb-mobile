import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/shared/design_system/theme/app_theme_palette.dart';
import 'package:libredb_mobile/shared/design_system/theme/environment_colors.dart';
import 'package:libredb_mobile/shared/design_system/theme/theme_colors.dart';

/// Guards that every palette this app ships can be read.
///
/// The repository already has an accessibility floor, but it measures one screen — `login_screen_a11y_test.dart` —
/// and a screen can only ever show one palette in one brightness. Six schemes ship, and the pairs below were under
/// their floor in almost every one of them: a card border at 1.04:1 is not a faint border, it is no border.
///
/// Each floor says which rule it comes from, because they are not the same kind of claim:
///
/// * **4.5:1** is WCAG 2.1 AA for body text (1.4.3), and applies to a colour this app paints text with.
/// * **3:1** is WCAG 2.1 AA for the boundary of a user interface component (1.4.11 Non-text Contrast). `outline` is
///   the Material 3 token for that boundary — a card's edge, a text field's edge — so it carries this floor.
/// * **1.9:1** is this repository's own, not WCAG's. `outlineVariant` is Material 3's *decorative* divider, which
///   1.4.11 exempts; but a divider at 1.04:1 draws nothing at all, and a separator that separates nothing is a bug
///   whatever the standard says. The number is the lowest ratio at which the measured dividers are visible on a
///   calibrated display, and it is a floor rather than a target.
///
/// `surfaceContainer*` is deliberately absent. Those are surfaces, and no rule asks one surface to contrast with
/// another; a table header that is hard to pick out is a design call, not a conformance one, and it is #367's
/// follow-up rather than this guard's business.
void main() {
  /// The pairs, as (foreground, background, floor, what it is).
  final pairs = <(Color Function(ColorScheme), Color Function(ColorScheme), double, String)>[
    ((cs) => cs.outline, (cs) => cs.surface, 3.0, 'outline on surface — the edge of a card or a field'),
    ((cs) => cs.outlineVariant, (cs) => cs.surface, 1.9, 'outlineVariant on surface — a divider'),
    ((cs) => cs.tertiary, (cs) => cs.surface, 4.5, 'tertiary on surface — a column type, a code string'),
    ((cs) => cs.onSurfaceVariant, (cs) => cs.surface, 4.5, 'onSurfaceVariant on surface — secondary text'),
    ((cs) => cs.onSurface, (cs) => cs.surface, 4.5, 'onSurface on surface — body text'),
    ((cs) => cs.onPrimary, (cs) => cs.primary, 4.5, 'onPrimary on primary — a filled button'),
    ((cs) => cs.onSecondary, (cs) => cs.secondary, 4.5, 'onSecondary on secondary'),
    ((cs) => cs.onError, (cs) => cs.error, 4.5, 'onError on error'),
    ((cs) => cs.onPrimaryContainer, (cs) => cs.primaryContainer, 4.5, 'onPrimaryContainer on its container'),
    ((cs) => cs.onSecondaryContainer, (cs) => cs.secondaryContainer, 4.5, 'onSecondaryContainer on its container'),
    ((cs) => cs.onTertiaryContainer, (cs) => cs.tertiaryContainer, 4.5, 'onTertiaryContainer on its container'),
    ((cs) => cs.onErrorContainer, (cs) => cs.errorContainer, 4.5, 'onErrorContainer on its container — a warning'),
  ];

  for (final palette in AppThemePalette.values) {
    for (final brightness in Brightness.values) {
      test('${palette.name} in ${brightness.name} can be read', () {
        final scheme = ThemeColors.getColorScheme(palette, brightness);
        final under = <String>[];
        for (final (foreground, background, floor, what) in pairs) {
          final ratio = contrastRatio(foreground(scheme), background(scheme));
          if (ratio < floor) under.add('$what: ${ratio.toStringAsFixed(2)}:1, floor $floor:1');
        }
        expect(under, isEmpty, reason: 'in ${palette.name}/${brightness.name}:\n${under.join('\n')}');
      });
    }
  }
}
