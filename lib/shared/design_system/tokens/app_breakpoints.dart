/// Responsive breakpoints and layout constants.
class AppBreakpoints {
  AppBreakpoints._();

  /// Screen width breakpoints.
  static const double mobile = 768.0;
  static const double tablet = 1024.0;

  /// `--bp-xl`. It was 1200, a number on neither side's scale; the design system's desktop edge is 1280 (#283).
  static const double desktop = 1280.0;

  /// Below this screen height, Material's compact height class, such as a phone held sideways, the shell puts its tabs
  /// in a rail at the side and a page header shares its rows. It reads the screen, which the keyboard does not change,
  /// so typing never switches the layout.
  static const double compactHeight = 480.0;

  /// Content area max width.
  static const double contentMaxWidth = 1200.0;

  /// Convenience helpers.
  static bool isMobile(double width) => width < mobile;
  static bool isTablet(double width) => width >= mobile && width < tablet;
  static bool isDesktop(double width) => width >= tablet;
  static bool isCompactHeight(double height) => height < compactHeight;
}
