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

  /// The product's type scale, as `tool/design-system/tokens/typography.css` defines it, on the phone column.
  ///
  /// The app used to name no size at all: it adjusted weight, tracking and line height on whatever Flutter resolved
  /// for the platform, so its text was Material's, not the product's. The system has ten heading levels — four
  /// displays and `h1` to `h6` — against Material's nine, and `display-xxl` is the one left out: 72 px of marketing
  /// headline that no screen in a phone app has a use for. The rest map in order (#283).
  ///
  /// Measured before it was written, which is why it is a smaller change than it reads as: of the 252 places this
  /// app reaches for a text style, **186 do not move at all** — the system's body and label sizes already agree with
  /// Material's to the pixel. Only the headings shift, and the two most-used of them by 1 pt and 2 pt.
  ///
  /// Tracking is converted, not copied. The system writes it in `em`, a fraction of the size; Flutter wants logical
  /// pixels, so each value is multiplied by the size it belongs to. `app_typography_test.dart` reads the CSS and
  /// checks all three — size, line height and tracking — against it.
  static TextTheme textTheme(TextTheme base) {
    base = base.apply(fontFamily: sans);
    return base.copyWith(
      // display-xl
      displayLarge: _level(base.displayLarge, size: 36, line: 1.05, trackingEm: -0.028, weight: FontWeight.w700),
      // display-l
      displayMedium: _level(base.displayMedium, size: 32, line: 1.06, trackingEm: -0.026, weight: FontWeight.w700),
      // display-m
      displaySmall: _level(base.displaySmall, size: 30, line: 1.08, trackingEm: -0.024, weight: FontWeight.w700),
      // h1
      headlineLarge: _level(base.headlineLarge, size: 28, line: 1.1, trackingEm: -0.022, weight: FontWeight.w600),
      // h2
      headlineMedium: _level(base.headlineMedium, size: 24, line: 1.15, trackingEm: -0.02, weight: FontWeight.w600),
      // h3
      headlineSmall: _level(base.headlineSmall, size: 21, line: 1.2, trackingEm: -0.016, weight: FontWeight.w600),
      // h4
      titleLarge: _level(base.titleLarge, size: 19, line: 1.25, trackingEm: -0.012, weight: FontWeight.w600),
      // h5
      titleMedium: _level(base.titleMedium, size: 17, line: 1.3, trackingEm: -0.008, weight: FontWeight.w600),
      // h6 — the only heading the system leaves untracked.
      titleSmall: _level(base.titleSmall, size: 16, line: 1.4, trackingEm: 0, weight: FontWeight.w600),
      // body-m
      bodyLarge: _level(base.bodyLarge, size: 16, line: 1.6, weight: FontWeight.w400),
      // body-s
      bodyMedium: _level(base.bodyMedium, size: 14, line: 1.55, weight: FontWeight.w400),
      // body-xs
      bodySmall: _level(base.bodySmall, size: 12, line: 1.5, weight: FontWeight.w400),
      // label — the weight the system gives UI text.
      labelLarge: _level(base.labelLarge, size: 14, line: 1.3, weight: FontWeight.w500),
      // caption
      labelMedium: _level(base.labelMedium, size: 12, line: 1.4, weight: FontWeight.w500),
      // overline — its size only. The system tracks it open at 0.1em, but its own rules tie that tracking to the
      // ALL-CAPS eyebrow treatment ("ALL-CAPS only for the mono eyebrow/overline styles, and only with wide
      // tracking"), and this app's 33 `labelSmall` call sites are ordinary small labels, not eyebrows. Taking it
      // anyway would widen every one of them by 0.6 px a character for a treatment none of them use.
      labelSmall: _level(base.labelSmall, size: 11, weight: FontWeight.w500),
    );
  }

  /// One level of the scale. [trackingEm] is the system's own unit — a fraction of [size] — and is converted here so
  /// no caller has to remember which unit it is in; null means the level is untracked and keeps the face's own.
  static TextStyle? _level(
    TextStyle? base, {
    required double size,
    double? line,
    double? trackingEm,
    FontWeight? weight,
  }) => base?.copyWith(
    fontSize: size,
    height: line,
    letterSpacing: trackingEm == null ? null : trackingEm * size,
    fontWeight: weight,
  );
}
