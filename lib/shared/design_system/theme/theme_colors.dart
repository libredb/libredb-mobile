import 'package:flutter/material.dart';

import 'app_theme_palette.dart';

/// The colour of the three palettes this app ships, taken from the product's design system.
///
/// The system is vendored at `tool/design-system/tokens/` (`theme.css` for the semantic tokens, `colors.css` for
/// the ramps they are drawn from) and `test/architecture/design_system_import_test.dart` reads those files and
/// fails when the values below stop agreeing with them. That guard, not this comment, is what keeps the two in
/// step; what the comment is for is the three things the guard can only assert, not explain (#283).
///
/// **The action colour belongs to the product, the room belongs to the palette.** The owner kept three palettes
/// and ruled the brand indigo into all of them, so `primary` and everything that hangs off it is the same in
/// `classic`, `nature` and `sunset`; what each palette still chooses is its page, its edges, its quiet text and
/// its own accent — sage and orange are what `nature` and `sunset` *are*. `classic` is the one the owner ruled
/// would be the site's exact counterpart, so every neutral in it is a web token too.
///
/// **`surface` is `--background`, not `--surface`.** Material 3 has no `background` role: `ColorScheme.surface`
/// *is* the page, and the web's `--surface` is a card, which lands on `surfaceContainer*`. Read the other way
/// round, the action colour sits at 2.80:1 on the page and fails 1.4.11; read this way it is 3.08:1.
///
/// **A deviation is the other consumer's where it has one.** `tertiary` is `--text-tertiary`, which the system
/// sets too light to read in either scope. The website hit exactly this and recorded its answer in the layer
/// beside its own copy of the system — vendored here at `tool/design-system/other-consumer/a11y.css` — so this
/// app takes that lift rather than computing a second one: two consumers of one design system showing two
/// different greys is the thing a shared design system exists to prevent. `outline` and `outlineVariant` get no
/// such help, because 1.4.3 is about text and the website never applied 1.4.11 to its borders; those two walk
/// the system's own `--neutral-*` ramp and are this app's own deviation, in #369's convention.
///
/// **One rule covers all four status colours**, `error` included: the colour is `--<kind>-text`, what sits on it
/// is the scope's `--text-inverse`, and the quiet pair is `--<kind>-bg` with `--<kind>-text` on it. It has to be
/// the `-text` member of each web triplet because this app paints *text* with these roles at least as often as it
/// fills with them — `ColorScheme.error` alone is a text colour at twenty call sites — and `-text` is the only
/// member that carries both uses. `--action-destructive` is deliberately unmapped: it is the web's destructive
/// *button*, and in the dark scope it is 4.01:1 against the page.
class ThemeColors {
  ThemeColors._();

  // ---------------------------------------------------------------------------------------------------------
  // The brand group. Identical in all three palettes, both brightnesses — an action belongs to the product.
  // ---------------------------------------------------------------------------------------------------------

  /// `--action-primary`. The same value in both scopes, as the system declares it.
  static const Color _actionPrimary = Color(0xFF4F46E5);

  /// White, in both scopes — which is what the design system itself paints, not a deviation from it.
  ///
  /// It reads like one, because the dark scope's `--text-inverse` is `#0B0D18` and that is 3.08:1 on the action
  /// colour. But the system never asks `--text-inverse` to be a button label: the website sets `color: #fff` as a
  /// literal at all ten of its filled brand buttons, and paints `--text-inverse` in one place only — as the ink
  /// of `--surface-inverse`, which is where this app puts it too. White is 6.29:1 on the action colour in both
  /// scopes, so the floor confirms the system's practice rather than overruling it.
  static const Color _onAction = Color(0xFFFFFFFF);

  static const Color _surfaceBrandLight = Color(0xFFEEF2FF); // --surface-brand
  static const Color _surfaceBrandDark = Color(0xFF252163);
  static const Color _textBrandLight = Color(0xFF4338CA); // --text-brand
  static const Color _textBrandDark = Color(0xFFC7D2FE);

  // ---------------------------------------------------------------------------------------------------------
  // The status group. Also shared: a failure reads the same whichever palette the room is painted in.
  // ---------------------------------------------------------------------------------------------------------

  static const Color _errorLight = Color(0xFFB91C1C); // --error-text
  static const Color _errorDark = Color(0xFFFCA5A5);
  static const Color _errorBgLight = Color(0xFFFEF2F2); // --error-bg
  static const Color _errorBgDark = Color(0xFF3A0F13);

  /// `--text-inverse`, the colour that sits on a filled status colour.
  static const Color _textInverseLight = Color(0xFFFFFFFF);
  static const Color _textInverseDark = Color(0xFF0B0D18);

  /// Get color scheme for a specific palette and brightness
  static ColorScheme getColorScheme(AppThemePalette palette, Brightness brightness) {
    switch (palette) {
      case AppThemePalette.classic:
        return _getClassicColorScheme(brightness);
      case AppThemePalette.nature:
        return _getNatureColorScheme(brightness);
      case AppThemePalette.sunset:
        return _getSunsetColorScheme(brightness);
    }
  }

  /// `classic` — the design system itself, token for token, with three lifted values.
  ///
  /// The three are `tertiary`, `outline` and `outlineVariant`, whose web values cannot be read on the page:
  /// `--border` is 1.24:1 in light and 1.40:1 in dark, `--border-strong` 1.51:1 and 1.98:1, against floors of
  /// 1.9:1 for a divider and 3:1 for the edge of a control. Each one walks the web's own `--neutral-*` ramp away
  /// from the page and stops at the first point that clears its floor, so the value stays inside the system and
  /// as close to the web's as the floor allows. The percentages are in the guard, which recomputes them.
  static ColorScheme _getClassicColorScheme(Brightness brightness) {
    if (brightness == Brightness.light) {
      return const ColorScheme.light(
        primary: _actionPrimary,
        onPrimary: _onAction,
        primaryContainer: _surfaceBrandLight,
        onPrimaryContainer: _textBrandLight,
        secondary: Color(0xFF4A5069), // --text-secondary
        onSecondary: _textInverseLight,
        secondaryContainer: Color(0xFFF1F3F9), // --action-tertiary, the quiet button's surface
        onSecondaryContainer: Color(0xFF0E1020), // --text-primary
        tertiary: Color(0xFF6C728A), // --text-tertiary at 3.86:1; the website's own lift, 4.76:1
        onTertiary: _textInverseLight,
        tertiaryContainer: Color(0xFFF1F3F9), // --action-tertiary
        onTertiaryContainer: Color(0xFF0E1020), // --text-primary
        error: _errorLight,
        onError: _textInverseLight,
        errorContainer: _errorBgLight,
        onErrorContainer: _errorLight,
        surface: Color(0xFFFFFFFF), // --background
        onSurface: Color(0xFF0E1020), // --text-primary
        // The ladder a card, an accessory bar and a table header fill with. Material resolves these to the
        // page when they are left out, so a fill with one drew nothing at all (#386): --background-subtle twice and
        // --surface-hover twice: the light scope has three surfaces and Material wants
        // five, so two steps repeat rather than invent a value the system does not have.
        surfaceContainerLow: Color(0xFFF8F9FC),
        surfaceContainer: Color(0xFFF8F9FC),
        surfaceContainerHigh: Color(0xFFF1F3F9),
        surfaceContainerHighest: Color(0xFFF1F3F9), // --surface-hover
        onSurfaceVariant: Color(0xFF4A5069), // --text-secondary
        outline: Color(0xFF8E94AC), // --border-strong at 1.51:1, 53% --neutral-400→500 for 3.01:1 (WCAG 1.4.11)
        outlineVariant: Color(0xFFB5BBCF), // --border at 1.24:1, 56% --neutral-300→400 for 1.91:1
        shadow: Color(0xFF000000),
        scrim: Color(0xFF000000),
        inverseSurface: Color(0xFF0B0D18), // --surface-inverse
        onInverseSurface: _textInverseLight,
        inversePrimary: _textBrandDark,
        surfaceTint: _actionPrimary,
      );
    } else {
      return const ColorScheme.dark(
        primary: _actionPrimary,
        onPrimary: _onAction,
        primaryContainer: _surfaceBrandDark,
        onPrimaryContainer: _textBrandDark,
        secondary: Color(0xFFA8B0CC), // --text-secondary
        onSecondary: _textInverseDark,
        secondaryContainer: Color(0xFF1B2038), // --action-tertiary
        onSecondaryContainer: Color(0xFFF2F4FB), // --text-primary
        tertiary: Color(0xFF7F87A7), // --text-tertiary at 4.84:1; the website's own lift, 5.46:1
        onTertiary: _textInverseDark,
        tertiaryContainer: Color(0xFF1B2038), // --action-tertiary
        onTertiaryContainer: Color(0xFFF2F4FB), // --text-primary
        error: _errorDark,
        onError: _textInverseDark,
        errorContainer: _errorBgDark,
        onErrorContainer: _errorDark,
        surface: Color(0xFF0B0D18), // --background
        onSurface: Color(0xFFF2F4FB), // --text-primary
        // The ladder a card, an accessory bar and a table header fill with. Material resolves these to the
        // page when they are left out, so a fill with one drew nothing at all (#386): --background-subtle, --surface
        // and --surface-elevated: the dark scope has the whole ladder.
        surfaceContainerLow: Color(0xFF101321),
        surfaceContainer: Color(0xFF141829),
        surfaceContainerHigh: Color(0xFF1B2038),
        surfaceContainerHighest: Color(0xFF232842), // --surface-hover
        onSurfaceVariant: Color(0xFFA8B0CC), // --text-secondary
        outline: Color(0xFF585E75), // --border-strong at 1.98:1, 86% --neutral-700→600 for 3.02:1
        outlineVariant: Color(0xFF3C4057), // --border at 1.40:1, 69% --neutral-800→700 for 1.90:1
        shadow: Color(0xFF000000),
        scrim: Color(0xFF000000),
        inverseSurface: Color(0xFFFFFFFF), // --surface-inverse
        onInverseSurface: _textInverseDark,
        inversePrimary: _textBrandLight,
        surfaceTint: _actionPrimary,
      );
    }
  }

  /// Nature "Sage" — a green-tinted neutral room, the product's action colour in it.
  static ColorScheme _getNatureColorScheme(Brightness brightness) {
    if (brightness == Brightness.light) {
      return const ColorScheme.light(
        primary: _actionPrimary,
        onPrimary: _onAction,
        primaryContainer: _surfaceBrandLight,
        onPrimaryContainer: _textBrandLight,
        secondary: Color(0xFF5F7A64), // Sage green accent — what this palette is
        onSecondary: Color(0xFFFFFFFF),
        secondaryContainer: Color(0xFFE8F0E8), // Sage 50
        onSecondaryContainer: Color(0xFF1A1D1A), // Sage 900
        tertiary: Color(0xFF68796B), // 4.54:1
        onTertiary: Color(0xFF1A1D1A), // Sage 900
        tertiaryContainer: Color(0xFFF0F4F0), // Sage 100
        onTertiaryContainer: Color(0xFF2A302B), // Sage 800
        error: _errorLight,
        onError: _textInverseLight,
        errorContainer: _errorBgLight,
        onErrorContainer: _errorLight,
        surface: Color(0xFFFCFDFC),
        onSurface: Color(0xFF0D0F0D), // Sage 950
        // The ladder a card, an accessory bar and a table header fill with. Material resolves these to the
        // page when they are left out, so a fill with one drew nothing at all (#386): evenly between this palette's own
        // page and its own top step — its family, not a new one.
        surfaceContainerLow: Color(0xFFF9FBF9),
        surfaceContainer: Color(0xFFF6F9F6),
        surfaceContainerHigh: Color(0xFFF3F6F3),
        surfaceContainerHighest: Color(0xFFF0F4F0), // Sage 100
        onSurfaceVariant: Color(0xFF5F7A64), // Sage 600 — 4.62:1, the only palette whose secondary text was under AA
        outline: Color(0xFF839887), // 3.03:1
        outlineVariant: Color(0xFFA6C1AB), // 1.90:1
        shadow: Color(0xFF000000),
        scrim: Color(0xFF000000),
        inverseSurface: Color(0xFF1A1D1A), // Sage 900
        onInverseSurface: Color(0xFFF5F8F5), // Sage 50
        inversePrimary: _textBrandDark,
        surfaceTint: _actionPrimary,
      );
    } else {
      return const ColorScheme.dark(
        primary: _actionPrimary,
        onPrimary: _onAction,
        primaryContainer: _surfaceBrandDark,
        onPrimaryContainer: _textBrandDark,
        secondary: Color(0xFF8BA68F), // Sage green accent
        onSecondary: Color(0xFF0D0F0D), // Sage 950
        secondaryContainer: Color(0xFF2A302B), // Sage 800
        onSecondaryContainer: Color(0xFFF0F4F0), // Sage 100
        tertiary: Color(0xFF6E7F71), // 4.52:1
        onTertiary: Color(0xFFF5F8F5), // Sage 50
        tertiaryContainer: Color(0xFF2A302B), // Sage 800
        onTertiaryContainer: Color(0xFFF0F4F0), // Sage 100
        error: _errorDark,
        onError: _textInverseDark,
        errorContainer: _errorBgDark,
        onErrorContainer: _errorDark,
        surface: Color(0xFF0D0F0D), // Sage 950
        onSurface: Color(0xFFF5F8F5), // Sage 50
        // The ladder a card, an accessory bar and a table header fill with. Material resolves these to the
        // page when they are left out, so a fill with one drew nothing at all (#386): evenly between this palette's own
        // page and its own top step.
        surfaceContainerLow: Color(0xFF141715),
        surfaceContainer: Color(0xFF1C201C),
        surfaceContainerHigh: Color(0xFF232824),
        surfaceContainerHighest: Color(0xFF2A302B), // Sage 800
        onSurfaceVariant: Color(0xFF8BA68F), // Sage 400
        outline: Color(0xFF556357), // 3.03:1
        outlineVariant: Color(0xFF3B443D), // 1.91:1
        shadow: Color(0xFF000000),
        scrim: Color(0xFF000000),
        inverseSurface: Color(0xFFF5F8F5), // Sage 50
        onInverseSurface: Color(0xFF0D0F0D), // Sage 950
        inversePrimary: _textBrandLight,
        surfaceTint: _actionPrimary,
      );
    }
  }

  /// Sunset "Stone" — a warm-tinted neutral room with an orange accent, the product's action colour in it.
  static ColorScheme _getSunsetColorScheme(Brightness brightness) {
    if (brightness == Brightness.light) {
      return const ColorScheme.light(
        primary: _actionPrimary,
        onPrimary: _onAction,
        primaryContainer: _surfaceBrandLight,
        onPrimaryContainer: _textBrandLight,
        secondary: Color(0xFFC2410C), // Orange 700 warm accent — what this palette is
        onSecondary: Color(0xFFFFFFFF),
        secondaryContainer: Color(0xFFFFF7ED), // Orange 50
        onSecondaryContainer: Color(0xFF7C2D12), // Orange 900
        tertiary: Color(0xFF79726D), // 4.53:1
        onTertiary: Color(0xFF1C1917), // Stone 900
        tertiaryContainer: Color(0xFFF5F5F4), // Stone 100
        onTertiaryContainer: Color(0xFF292524), // Stone 800
        error: _errorLight,
        onError: _textInverseLight,
        errorContainer: _errorBgLight,
        onErrorContainer: _errorLight,
        surface: Color(0xFFFAFAF9), // Stone 50
        onSurface: Color(0xFF0C0A09), // Stone 950
        // The ladder a card, an accessory bar and a table header fill with. Material resolves these to the
        // page when they are left out, so a fill with one drew nothing at all (#386): evenly between this palette's own
        // page and its own top step.
        surfaceContainerLow: Color(0xFFF9F9F8),
        surfaceContainer: Color(0xFFF8F8F7),
        surfaceContainerHigh: Color(0xFFF6F6F5),
        surfaceContainerHighest: Color(0xFFF5F5F4), // Stone 100
        onSurfaceVariant: Color(0xFF78716C), // Stone 500
        outline: Color(0xFF989089), // 3.01:1
        outlineVariant: Color(0xFFC1B6AE), // 1.90:1
        shadow: Color(0xFF000000),
        scrim: Color(0xFF000000),
        inverseSurface: Color(0xFF1C1917), // Stone 900
        onInverseSurface: Color(0xFFFAFAF9), // Stone 50
        inversePrimary: _textBrandDark,
        surfaceTint: _actionPrimary,
      );
    } else {
      return const ColorScheme.dark(
        primary: _actionPrimary,
        onPrimary: _onAction,
        primaryContainer: _surfaceBrandDark,
        onPrimaryContainer: _textBrandDark,
        secondary: Color(0xFFFB923C), // Orange 400 warm accent
        onSecondary: Color(0xFF0C0A09), // Stone 950
        secondaryContainer: Color(0xFF292524), // Stone 800
        onSecondaryContainer: Color(0xFFFED7AA), // Orange 200
        tertiary: Color(0xFF7F7772), // 4.50:1
        onTertiary: Color(0xFFFAFAF9), // Stone 50
        tertiaryContainer: Color(0xFF292524), // Stone 800
        onTertiaryContainer: Color(0xFFF5F5F4), // Stone 100
        error: _errorDark,
        onError: _textInverseDark,
        errorContainer: _errorBgDark,
        onErrorContainer: _errorDark,
        surface: Color(0xFF0C0A09), // Stone 950
        onSurface: Color(0xFFFAFAF9), // Stone 50
        // The ladder a card, an accessory bar and a table header fill with. Material resolves these to the
        // page when they are left out, so a fill with one drew nothing at all (#386): evenly between this palette's own
        // page and its own top step.
        surfaceContainerLow: Color(0xFF131110),
        surfaceContainer: Color(0xFF1B1816),
        surfaceContainerHigh: Color(0xFF221E1D),
        surfaceContainerHighest: Color(0xFF292524), // Stone 800
        onSurfaceVariant: Color(0xFFA8A29E), // Stone 400
        outline: Color(0xFF625C58), // 3.00:1
        outlineVariant: Color(0xFF44403D), // 1.93:1
        shadow: Color(0xFF000000),
        scrim: Color(0xFF000000),
        inverseSurface: Color(0xFFFAFAF9), // Stone 50
        onInverseSurface: Color(0xFF0C0A09), // Stone 950
        inversePrimary: _textBrandLight,
        surfaceTint: _actionPrimary,
      );
    }
  }
}
