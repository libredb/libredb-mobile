import 'package:flutter/animation.dart';

/// Animation duration and curve tokens.
class AppDurations {
  AppDurations._();

  // The durations of the product's design system, in its own words: motion directs attention, it never decorates,
  // and an exit is shorter than its entrance. The values come from `tool/design-system/tokens/motion.css`, and
  // `design_system_import_test.dart` holds them to it (#283).

  /// A state colour change. Short enough to read as the control answering rather than as an animation.
  static const Duration instant = Duration(milliseconds: 80);

  /// Hover, focus, tap.
  static const Duration fast = Duration(milliseconds: 150);

  /// A dropdown, an accordion, a card lift.
  static const Duration normal = Duration(milliseconds: 240);

  /// A modal, a drawer, a page transition.
  static const Duration slow = Duration(milliseconds: 360);

  /// An image zoom — the one duration that belongs to a picture rather than to a control.
  static const Duration media = Duration(milliseconds: 400);

  /// Common curves.
  static const Curve easeIn = Curves.easeIn;
  static const Curve easeOut = Curves.easeOut;
  static const Curve easeInOut = Curves.easeInOut;
  static const Curve decelerate = Curves.decelerate;
}
