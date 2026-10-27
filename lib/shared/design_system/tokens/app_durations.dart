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

  // The system's own curves, not Flutter's. Flutter's `Curves.easeOut` is (0, 0, .58, 1); the product's is
  // (.22, 1, .36, 1), which leaves its start far faster and settles later — the difference a person reads as the
  // interface being quick rather than smooth. `--ease-spring` is deliberately absent: it overshoots at 1.56, and an
  // unused curve is a value nobody is holding to anything. It arrives with its first caller (#283).

  /// `--ease-out`. An entrance.
  static const Curve easeOut = Cubic(0.22, 1, 0.36, 1);

  /// `--ease-in`. An exit.
  static const Curve easeIn = Cubic(0.55, 0, 1, 0.45);

  /// `--ease-in-out`. A move that both starts and ends on screen.
  static const Curve easeInOut = Cubic(0.65, 0, 0.35, 1);
}
