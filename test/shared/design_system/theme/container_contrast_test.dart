import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/shared/design_system/theme/app_theme_palette.dart';
import 'package:libredb_mobile/shared/design_system/theme/environment_colors.dart';
import 'package:libredb_mobile/shared/design_system/theme/theme_colors.dart';

/// Guards the quiet roles against the container they are really painted on.
///
/// `palette_contrast_test.dart` measures every role against the page, and `surface_ladder_test.dart` asks that a
/// container be a colour of its own. Neither measures a role **on** a container, so a value that reads on the page
/// and disappears on a card passed both (#386).
///
/// The pairs below are the ones the code paints, found by reading the call sites rather than by crossing every
/// quiet role with every container. That distinction is the whole design of this guard: #386's own table measured
/// the cross product and so asked for values nobody can see. `tertiary` and `outlineVariant` are not here because
/// nothing paints either on a container — `tertiary`'s nine sites are all on the page, and `outlineVariant` is a
/// divider over the page in every one of its uses, including `dividerTheme` and `cardTheme`.
///
/// - `onSurfaceVariant` on `surfaceContainerHighest` is text: the stale-data line of `offline_status.dart`, the
///   environment and time-travel tabs, and the connection details sheet.
/// - `onSurfaceVariant` on `surfaceContainerHigh` is the column name in the result table's header row.
/// - `outline` on `surfaceContainerHighest` is a boundary, not text: the border of the theme badge's filled box in
///   `login_theme_badge.dart`, which is the one place a container-filled box draws its own edge.
///
/// The floors are WCAG 2.1 AA: 1.4.3's 4.5:1 for text, and 1.4.11's 3:1 for a boundary that carries meaning. They
/// are the same floors `palette_contrast_test.dart` applies to the same roles on the page, which is the point —
/// a role does not stop being text because the thing behind it is a card.
void main() {
  for (final palette in AppThemePalette.values) {
    for (final brightness in Brightness.values) {
      test('${palette.name} in ${brightness.name}: the quiet roles read on the containers they are painted on', () {
        final scheme = ThemeColors.getColorScheme(palette, brightness);
        final under = <String>[];

        void check(Color foreground, Color background, double floor, String what) {
          final ratio = contrastRatio(foreground, background);
          if (ratio < floor) under.add('$what: ${ratio.toStringAsFixed(2)}:1, floor $floor:1');
        }

        check(scheme.onSurfaceVariant, scheme.surfaceContainerHighest, 4.5, 'quiet text on the highest container');
        check(scheme.onSurfaceVariant, scheme.surfaceContainerHigh, 4.5, 'quiet text on the high container');
        check(scheme.outline, scheme.surfaceContainerHighest, 3, 'the edge of a box filled with the highest container');

        expect(under, isEmpty, reason: 'in ${palette.name}/${brightness.name}:\n${under.join('\n')}');
      });
    }
  }
}
