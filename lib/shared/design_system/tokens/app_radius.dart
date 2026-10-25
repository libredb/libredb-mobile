/// Corner radius tokens for surfaces and components.
class AppRadius {
  AppRadius._();

  static const double sm = 4.0;
  static const double md = 6.0;
  static const double lg = 8.0;
  static const double xl = 12.0;

  /// A radius no component is tall enough to use in full, so every one clamps it to half its height and comes out a
  /// pill. Written as one token because the app had reached the same shape through two magic numbers — `circular(999)`
  /// in the login screen and `circular(100)` in the badges — which read as different intents and are not.
  static const double pill = 999.0;
}
