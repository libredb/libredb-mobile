import 'package:flutter/material.dart';

/// Typography tokens that can be mapped to ThemeData.textTheme.
class AppTypography {
  AppTypography._();

  /// The face the product is set in, as libredb.org is. Declared in `pubspec.yaml`; a name that does not match a
  /// declared family silently falls back to the platform's, so the two are kept in step by a test.
  static const String sans = 'Plus Jakarta Sans';

  /// The face every code surface is set in — a statement, a value, a key, a stack frame. It asked the platform
  /// for one instead, so the same column of values rendered in a different face on Android and on iOS.
  static const String mono = 'JetBrains Mono';

  /// Returns a text theme in [sans], tuned for readability with tight letter-spacing.
  static TextTheme textTheme(TextTheme base) {
    base = base.apply(fontFamily: sans);
    return base.copyWith(
      displayLarge: base.displayLarge?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -1.5),
      displayMedium: base.displayMedium?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -1.0),
      displaySmall: base.displaySmall?.copyWith(fontWeight: FontWeight.w600),
      headlineLarge: base.headlineLarge?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -1.0),
      headlineMedium: base.headlineMedium?.copyWith(fontWeight: FontWeight.w600, letterSpacing: -0.5),
      headlineSmall: base.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
      titleLarge: base.titleLarge?.copyWith(fontWeight: FontWeight.w600, letterSpacing: -0.25),
      titleMedium: base.titleMedium?.copyWith(fontWeight: FontWeight.w500, letterSpacing: -0.15),
      titleSmall: base.titleSmall?.copyWith(fontWeight: FontWeight.w500),
      bodyLarge: base.bodyLarge?.copyWith(height: 1.5),
      bodyMedium: base.bodyMedium?.copyWith(height: 1.5),
      bodySmall: base.bodySmall?.copyWith(height: 1.5),
      labelLarge: base.labelLarge?.copyWith(fontWeight: FontWeight.w500),
    );
  }
}
