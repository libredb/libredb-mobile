import 'package:flutter/material.dart';
import 'package:libredb_mobile/shared/models/studio_environment.dart';

/// Studio's environment colors (`ENVIRONMENT_COLORS` in libredb-studio `src/lib/types.ts`).
abstract final class EnvironmentColors {
  static const production = Color(0xFFEF4444);
  static const staging = Color(0xFFEAB308);
  static const development = Color(0xFF22C55E);
  static const local = Color(0xFF3B82F6);

  /// Studio's color for `other`, and the app's for an environment Studio does not name.
  static const other = Color(0xFF6B7280);

  static Color of(String environment) => switch (environment) {
    StudioEnvironment.production => production,
    StudioEnvironment.staging => staging,
    StudioEnvironment.development => development,
    StudioEnvironment.local => local,
    _ => other,
  };
}

/// The operator's `#rrggbb` connection color, or null for none or a value of another shape.
Color? parseOperatorColor(String? value) {
  if (value == null || !RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(value)) return null;
  return Color(0xFF000000 | int.parse(value.substring(1), radix: 16));
}

/// The WCAG 2 contrast ratio of [a] and [b], from 1 to 21.
double contrastRatio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (la > lb ? la + 0.05 : lb + 0.05) / (la > lb ? lb + 0.05 : la + 0.05);
}

/// How a connection row shows its environment and its operator color in one theme.
///
/// The badge takes the operator color, or Studio's environment color, as its background when that color stands out
/// from the theme surface by [minSurfaceContrast] (WCAG 1.4.11), with black or white text, whichever reads better
/// (always at least 4.5:1); otherwise the badge keeps a theme color, the error color for production, and the operator
/// color, if any, only colors the [strip].
/// Color is never the only signal: the badge always carries its text label.
@immutable
class EnvironmentAccent {
  const EnvironmentAccent({required this.badgeBackground, required this.badgeForeground, this.strip});

  /// The contrast a badge background needs against the surface to count as visible.
  static const minSurfaceContrast = 3.0;

  final Color badgeBackground;
  final Color badgeForeground;

  /// The accent along the row's leading edge: the operator color when set, else Studio's production red on a
  /// production row, else none.
  final Color? strip;

  factory EnvironmentAccent.resolve({
    required String? environment,
    required String? color,
    required ColorScheme scheme,
  }) {
    final operator = parseOperatorColor(color);
    final isProduction = environment == StudioEnvironment.production;
    final tint = operator ?? (environment == null ? EnvironmentColors.other : EnvironmentColors.of(environment));
    final strip = operator ?? (isProduction ? EnvironmentColors.production : null);
    if (contrastRatio(tint, scheme.surface) >= minSurfaceContrast) {
      final onTint = contrastRatio(Colors.black, tint) >= contrastRatio(Colors.white, tint)
          ? Colors.black
          : Colors.white;
      return EnvironmentAccent(badgeBackground: tint, badgeForeground: onTint, strip: strip);
    }
    return isProduction
        ? EnvironmentAccent(badgeBackground: scheme.error, badgeForeground: scheme.onError, strip: strip)
        : EnvironmentAccent(
            badgeBackground: scheme.secondaryContainer,
            badgeForeground: scheme.onSecondaryContainer,
            strip: strip,
          );
  }

  @override
  bool operator ==(Object other) =>
      other is EnvironmentAccent &&
      other.badgeBackground == badgeBackground &&
      other.badgeForeground == badgeForeground &&
      other.strip == strip;

  @override
  int get hashCode => Object.hash(badgeBackground, badgeForeground, strip);
}
