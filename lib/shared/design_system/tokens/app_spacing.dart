/// The spacing scale, 4/8-based, and **closed**: {4, 8, 12, 16, 24, 32, 40, 48, 64}.
///
/// Closed means a layout rounds to a step rather than adding one. The two login files between them use nine values
/// that are on no scale at all — 3, 6, 7, 10, 14, 20, 28, 36, 56 — which is what happens when a screen reaches for a
/// number instead of a token. Filling those gaps would make every one of them correct and the scale meaningless.
class AppSpacing {
  AppSpacing._();

  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 24.0;
  static const double xxl = 32.0;
  static const double xxxl = 40.0;
  static const double xxxxl = 48.0;
  static const double xxxxxl = 64.0;

  /// Form max-width constraints for responsive layouts.
  static const double formMaxWidthSm = 200.0;
  static const double formMaxWidthMd = 400.0;
  static const double formMaxWidthLg = 600.0;
  static const double formMaxWidthXl = 800.0;
}
