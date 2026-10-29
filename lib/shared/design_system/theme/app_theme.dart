import 'package:flutter/material.dart';

import '../tokens/app_radius.dart';
import '../tokens/app_typography.dart';
import 'app_theme_palette.dart';
import 'semantic_colors.dart';
import 'theme_colors.dart';

/// Application theme builder — shadcn/ui aligned Material 3 configuration.
class AppTheme {
  AppTheme._();

  static ThemeData light([AppThemePalette palette = AppThemePalette.classic]) {
    final colorScheme = ThemeColors.getColorScheme(palette, Brightness.light);
    return _themeData(colorScheme, SemanticColors.light);
  }

  static ThemeData dark([AppThemePalette palette = AppThemePalette.classic]) {
    final colorScheme = ThemeColors.getColorScheme(palette, Brightness.dark);
    return _themeData(colorScheme, SemanticColors.dark);
  }

  static ThemeData _themeData(ColorScheme colorScheme, SemanticColors semanticColors) {
    final base = ThemeData(colorScheme: colorScheme, useMaterial3: true, brightness: colorScheme.brightness);
    final textTheme = AppTypography.textTheme(base.textTheme);

    return base.copyWith(
      textTheme: textTheme,
      extensions: [semanticColors],
      // No splash anywhere: Flutter's M3 default grows a circle out of the touch point and over whatever sits behind
      // the control, which is the shadow on tap the owner asked to be rid of (#417, the app-wide half of #416).
      // The flat press highlight stays — it is clipped to the control's own shape, and it is what tells a finger the
      // press landed. Taking that away too would re-create #367, where a control answered a finger with nothing;
      // `test/support/pressed_frame.dart` measures the floor and `test/architecture/tap_splash_test.dart` pins both
      // halves. Every M3 control reads this off the theme, `ButtonStyleButton` included.
      splashFactory: NoSplash.splashFactory,
      iconTheme: IconThemeData(color: colorScheme.onSurface, size: 18),
      iconButtonTheme: IconButtonThemeData(style: IconButton.styleFrom(foregroundColor: colorScheme.onSurface)),
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        iconTheme: IconThemeData(color: colorScheme.onSurface),
        actionsIconTheme: IconThemeData(color: colorScheme.onSurface),
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(color: colorScheme.onSurface),
      ),
      // shadcn input: h-9, rounded-md, border, bg-transparent, px-3 py-1
      inputDecorationTheme: InputDecorationTheme(
        isDense: false,
        filled: false,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: colorScheme.outline.withAlpha(77)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: colorScheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: colorScheme.error, width: 2),
        ),
        labelStyle: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 14),
        helperStyle: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12),
        hintStyle: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 14),
        errorStyle: TextStyle(color: colorScheme.error, fontSize: 12),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: colorScheme.inverseSurface,
        contentTextStyle: TextStyle(color: colorScheme.onInverseSurface),
      ),
      // shadcn dialog: rounded-xl
      dialogTheme: DialogThemeData(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyMedium,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: colorScheme.onSurface,
        textColor: colorScheme.onSurface,
        // `--text-brand`, because this colours the selected tile's label and icon — text, not a fill.
        selectedColor: colorScheme.onPrimaryContainer,
        titleTextStyle: textTheme.bodyLarge,
        subtitleTextStyle: textTheme.bodyMedium,
      ),
      // shadcn button default: h-9, rounded-md, text-sm, font-medium
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          elevation: 0,
          minimumSize: const Size(0, 36),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
          textStyle: textTheme.labelLarge?.copyWith(fontSize: 14),
        ),
      ),
      tabBarTheme: TabBarThemeData(
        // `--text-brand`, for the same reason as the quiet buttons: a tab's label is text. The indicator
        // under it keeps `primary`, because a rail is a boundary and its floor is 3:1, which it clears.
        labelColor: colorScheme.onPrimaryContainer,
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          // `--text-brand`: a quiet button's label is text, and `primary` — which is what Flutter's M3
          // default supplies when this is left out — is the action *fill* colour, 3.08:1 on a dark page.
          foregroundColor: colorScheme.onPrimaryContainer,
          minimumSize: const Size(0, 36),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
          textStyle: textTheme.labelLarge?.copyWith(fontSize: 14),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          // `--text-brand`: a quiet button's label is text, and `primary` — which is what Flutter's M3
          // default supplies when this is left out — is the action *fill* colour, 3.08:1 on a dark page.
          foregroundColor: colorScheme.onPrimaryContainer,
          minimumSize: const Size(0, 36),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
          textStyle: textTheme.labelLarge?.copyWith(fontSize: 14),
        ),
      ),
      // shadcn card: rounded-xl, border, shadow-sm
      cardTheme: CardThemeData(
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      dividerTheme: DividerThemeData(color: colorScheme.outlineVariant, thickness: 1, space: 0),
      popupMenuTheme: PopupMenuThemeData(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
        surfaceTintColor: Colors.transparent,
      ),
    );
  }
}
