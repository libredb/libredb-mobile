import 'package:flutter/material.dart';

/// The two gradients the design system defines, and the field the brand panel is painted on.
///
/// `colors.css` ends with them and says what they are for: *"Brand gradients — mark, one accent surface, graphic
/// device. Never a page bg."* They are the one part of the system the app had no counterpart for at all, which is
/// why the login panel reached for six hues of its own instead (#284).
///
/// The literals live here rather than in the panel because this is where literals belong: `design_token_test.dart`
/// skips `lib/shared/design_system/` by construction, and `design_system_import_test.dart` reads the vendored
/// `colors.css` and fails when these stop being the stops the system declares.
class AppGradients {
  AppGradients._();

  /// `--gradient-brand`, the mark's own: indigo into purple.
  static const Color brandStart = Color(0xFF4F46E5);
  static const Color brandEnd = Color(0xFF9333EA);

  /// `--gradient-data`, the chevrons': emerald into blue.
  static const Color dataStart = Color(0xFF10B981);
  static const Color dataEnd = Color(0xFF3B82F6);

  /// The system writes both at `135deg`, which in Flutter's terms is top-left to bottom-right.
  static const LinearGradient brand = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [brandStart, brandEnd],
  );

  static const LinearGradient data = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [dataStart, dataEnd],
  );

  /// The ground the brand panel is painted on: the dark scope's page, lifted to its card colour in the middle and
  /// back again.
  ///
  /// It is a *dark* field in both brightnesses, which is the panel's whole idea — the product's own ground beside
  /// the sign-in form rather than a second copy of the page. The three stops are `--background`, `--surface` and
  /// `--background` of the dark scope, so it is the same ground the app's own dark theme stands on.
  static const LinearGradient brandField = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0B0D18), Color(0xFF141829), Color(0xFF0B0D18)],
  );

  /// The same field, one step lifted, for the light scope — where the panel sits beside a white form and a page-dark
  /// ground reads as a hole rather than as a panel. `--surface` into `--surface-elevated` and back.
  static const LinearGradient brandFieldOnLight = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF141829), Color(0xFF1B2038), Color(0xFF141829)],
  );
}
