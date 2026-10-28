import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/shared/design_system/theme/app_theme_palette.dart';
import 'package:libredb_mobile/shared/design_system/theme/environment_colors.dart';
import 'package:libredb_mobile/shared/design_system/theme/theme_colors.dart';

/// Guards that a container role this app paints with is a colour of its own.
///
/// `theme_colors.dart` defined one container role — `surfaceContainerHighest` — and left the rest to Material's
/// defaults, which resolve them to the page. Three places fill with one of those: `app_card.dart` with
/// `surfaceContainerLow`, and the editor's accessory bar and the result table's header row with
/// `surfaceContainerHigh`. All three were painting the page colour onto the page, so the fill did nothing and what
/// made a card visible was only its border (#386).
///
/// The floor is not a contrast rule. One surface is not required to contrast with another, and in the light scope
/// the design system genuinely puts a white card on a white page and separates them with a border — which is why
/// this asks only that a role **differ** from the page, not by how much. A fill that is exactly the page is not a
/// quiet fill; it is no fill, and the widget that asked for one is lying about what it draws.
void main() {
  for (final palette in AppThemePalette.values) {
    for (final brightness in Brightness.values) {
      test('${palette.name} in ${brightness.name}: every container it paints with is its own colour', () {
        final scheme = ThemeColors.getColorScheme(palette, brightness);
        final same = <String>[];

        for (final (name, colour) in [
          ('surfaceContainerLow', scheme.surfaceContainerLow),
          ('surfaceContainer', scheme.surfaceContainer),
          ('surfaceContainerHigh', scheme.surfaceContainerHigh),
          ('surfaceContainerHighest', scheme.surfaceContainerHighest),
        ]) {
          if (colour == scheme.surface) same.add('$name is the page colour, so a fill with it draws nothing');
        }

        expect(same, isEmpty, reason: 'in ${palette.name}/${brightness.name}:\n${same.join('\n')}');
      });

      test('${palette.name} in ${brightness.name}: the ladder climbs away from the page', () {
        // Each step is further from the page than the one below it. Material's own ladder is ordered, and a
        // container that is closer to the page than a lower one makes "high" and "low" mean nothing.
        final scheme = ThemeColors.getColorScheme(palette, brightness);
        final distances = [
          for (final colour in [
            scheme.surfaceContainerLow,
            scheme.surfaceContainer,
            scheme.surfaceContainerHigh,
            scheme.surfaceContainerHighest,
          ])
            contrastRatio(colour, scheme.surface),
        ];

        for (var step = 1; step < distances.length; step++) {
          expect(
            distances[step],
            greaterThanOrEqualTo(distances[step - 1]),
            reason: 'step $step sits closer to the page than step ${step - 1}: $distances',
          );
        }
      });
    }
  }
}
