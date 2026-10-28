import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/shared/design_system/theme/app_theme_palette.dart';
import 'package:libredb_mobile/shared/design_system/theme/environment_colors.dart';
import 'package:libredb_mobile/shared/design_system/theme/semantic_colors.dart';
import 'package:libredb_mobile/shared/design_system/theme/theme_colors.dart';

/// Guards that the success, warning and info colours can be read, the way `palette_contrast_test.dart` guards the
/// palettes.
///
/// It exists because that guard could not see these: it reads a `ColorScheme`, and these three live in a
/// `ThemeExtension`, so for as long as both files have existed nothing measured them. Two were under the floor.
/// `success` was Green 600, which put its white label at 3.30:1, and `warning` was Yellow 500 — as text on the
/// page that is **1.92:1**, a yellow all but invisible on white. The design system's own values are 5.48:1 and
/// 5.02:1 (#283).
///
/// The floors are the same claims `palette_contrast_test.dart` makes, for the same reasons: 4.5:1 is WCAG 2.1 AA
/// for body text (1.4.3), and each pair below is text on something. These colours are painted as text as often as
/// they are filled with — `semanticColors.success` is the colour of a "done" line as well as of a badge — so the
/// page is a background these have to clear too, which is the pair the old code failed on.
void main() {
  for (final palette in AppThemePalette.values) {
    for (final brightness in Brightness.values) {
      test('${palette.name} in ${brightness.name}: the status colours can be read', () {
        final scheme = ThemeColors.getColorScheme(palette, brightness);
        final colors = brightness == Brightness.light ? SemanticColors.light : SemanticColors.dark;
        final under = <String>[];

        void check(Color foreground, Color background, String what) {
          final ratio = contrastRatio(foreground, background);
          if (ratio < 4.5) under.add('$what: ${ratio.toStringAsFixed(2)}:1, floor 4.5:1');
        }

        String on_(String kind) => 'on${kind[0].toUpperCase()}${kind.substring(1)}';

        for (final (kind, colour, on, container, onContainer) in [
          ('success', colors.success, colors.onSuccess, colors.successContainer, colors.onSuccessContainer),
          ('warning', colors.warning, colors.onWarning, colors.warningContainer, colors.onWarningContainer),
          ('info', colors.info, colors.onInfo, colors.infoContainer, colors.onInfoContainer),
        ]) {
          check(on, colour, '${on_(kind)} on $kind — a filled badge');
          check(onContainer, container, '${on_(kind)}Container on its container — a notice');
          check(colour, scheme.surface, '$kind as text on the page');
        }

        expect(under, isEmpty, reason: 'in ${palette.name}/${brightness.name}:\n${under.join('\n')}');
      });
    }
  }
}
