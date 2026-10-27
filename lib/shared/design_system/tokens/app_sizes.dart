/// Standard component size tokens — aligned with shadcn/ui sizing scale.
class AppSizes {
  AppSizes._();

  /// Button heights (shadcn: sm=h-8, md=h-9, lg=h-10).
  static const double buttonSm = 32.0;
  static const double buttonMd = 36.0;
  static const double buttonLg = 40.0;

  /// Icon sizes.
  static const double iconSm = 16.0;
  static const double iconMd = 18.0;
  static const double iconLg = 20.0;

  /// Avatar sizes.
  static const double avatarSm = 32.0;
  static const double avatarMd = 40.0;
  static const double avatarLg = 56.0;

  /// Input field heights (shadcn: h-9 default).
  static const double inputSm = 32.0;
  static const double inputMd = 36.0;
  static const double inputLg = 40.0;

  /// The smallest a tappable may be, in either direction.
  ///
  /// It is a touch floor, not a visual height: iOS asks for 44 and Android for 48, so one number satisfies both.
  /// Every button token above is smaller on purpose — a button is allowed to look smaller than it is tappable, and
  /// the theme's `minimumSize` of `Size(0, 36)` leaves the rest to padding. A bare tappable has no padding to lean
  /// on, so it sets this explicitly.
  static const double minTapTarget = 48.0;

  /// The floor for a target in a dense list, where [minTapTarget] would cost more than it buys.
  ///
  /// WCAG 2.2 asks 24x24 at AA (2.5.8 Target Size (Minimum)); the 44 pt of 2.5.5 is AAA, and this repository's own
  /// [minTapTarget] is a house rule set for buttons and chips. A result row is a dense row: #177 guarantees that a
  /// phone held sideways shows at least three of them at open, and 48 pt leaves room for two (#373).
  static const double minDenseTarget = 24.0;
}
