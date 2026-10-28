import 'package:flutter/material.dart';

/// Semantic color extension for success/warning/info states beyond Material's error.
@immutable
class SemanticColors extends ThemeExtension<SemanticColors> {
  final Color success;
  final Color onSuccess;
  final Color successContainer;
  final Color onSuccessContainer;

  final Color warning;
  final Color onWarning;
  final Color warningContainer;
  final Color onWarningContainer;

  final Color info;
  final Color onInfo;
  final Color infoContainer;
  final Color onInfoContainer;

  const SemanticColors({
    required this.success,
    required this.onSuccess,
    required this.successContainer,
    required this.onSuccessContainer,
    required this.warning,
    required this.onWarning,
    required this.warningContainer,
    required this.onWarningContainer,
    required this.info,
    required this.onInfo,
    required this.infoContainer,
    required this.onInfoContainer,
  });

  /// The design system's status colours, light scope (shared across all palettes).
  ///
  /// One rule, the same one `ThemeColors` follows for `error`: the colour is `--<kind>-text`, what sits on it is
  /// the scope's `--text-inverse`, and the quiet pair is `--<kind>-bg` with `--<kind>-text` on it. It has to be
  /// the `-text` member because this app paints text with these roles as well as filling with them, and the
  /// guard in `test/architecture/design_system_import_test.dart` reads the vendored `theme.css` and holds all
  /// twelve values to it.
  ///
  /// Taking them repaired two failures that had been shipping unmeasured, which is why this is not a repaint:
  /// `success` was Green 600, so its white label sat at **3.30:1**, and `warning` was Yellow 500, which as text
  /// on the page was **1.92:1** — a yellow all but invisible on white. The web's values are 5.48:1 and 5.02:1.
  /// `palette_contrast_test.dart` never caught either, because it reads `ColorScheme` and these are a
  /// `ThemeExtension`; `semantic_contrast_test.dart` now covers them (#283).
  static const light = SemanticColors(
    success: Color(0xFF047857), // --success-text
    onSuccess: Color(0xFFFFFFFF), // --text-inverse
    successContainer: Color(0xFFECFDF5), // --success-bg
    onSuccessContainer: Color(0xFF047857), // --success-text
    warning: Color(0xFFB45309), // --warning-text
    onWarning: Color(0xFFFFFFFF),
    warningContainer: Color(0xFFFFFBEB), // --warning-bg
    onWarningContainer: Color(0xFFB45309),
    info: Color(0xFF1D4ED8), // --info-text
    onInfo: Color(0xFFFFFFFF),
    infoContainer: Color(0xFFEFF6FF), // --info-bg
    onInfoContainer: Color(0xFF1D4ED8),
  );

  /// The design system's status colours, dark scope (shared across all palettes).
  static const dark = SemanticColors(
    success: Color(0xFF6EE7B7), // --success-text
    onSuccess: Color(0xFF0B0D18), // --text-inverse
    successContainer: Color(0xFF052E21), // --success-bg
    onSuccessContainer: Color(0xFF6EE7B7), // --success-text
    warning: Color(0xFFFCD34D), // --warning-text
    onWarning: Color(0xFF0B0D18),
    warningContainer: Color(0xFF33220A), // --warning-bg
    onWarningContainer: Color(0xFFFCD34D),
    info: Color(0xFF93C5FD), // --info-text
    onInfo: Color(0xFF0B0D18),
    infoContainer: Color(0xFF0D1F3D), // --info-bg
    onInfoContainer: Color(0xFF93C5FD),
  );

  @override
  SemanticColors copyWith({
    Color? success,
    Color? onSuccess,
    Color? successContainer,
    Color? onSuccessContainer,
    Color? warning,
    Color? onWarning,
    Color? warningContainer,
    Color? onWarningContainer,
    Color? info,
    Color? onInfo,
    Color? infoContainer,
    Color? onInfoContainer,
  }) {
    return SemanticColors(
      success: success ?? this.success,
      onSuccess: onSuccess ?? this.onSuccess,
      successContainer: successContainer ?? this.successContainer,
      onSuccessContainer: onSuccessContainer ?? this.onSuccessContainer,
      warning: warning ?? this.warning,
      onWarning: onWarning ?? this.onWarning,
      warningContainer: warningContainer ?? this.warningContainer,
      onWarningContainer: onWarningContainer ?? this.onWarningContainer,
      info: info ?? this.info,
      onInfo: onInfo ?? this.onInfo,
      infoContainer: infoContainer ?? this.infoContainer,
      onInfoContainer: onInfoContainer ?? this.onInfoContainer,
    );
  }

  @override
  SemanticColors lerp(covariant ThemeExtension<SemanticColors>? other, double t) {
    if (other is! SemanticColors) return this;
    return SemanticColors(
      success: Color.lerp(success, other.success, t)!,
      onSuccess: Color.lerp(onSuccess, other.onSuccess, t)!,
      successContainer: Color.lerp(successContainer, other.successContainer, t)!,
      onSuccessContainer: Color.lerp(onSuccessContainer, other.onSuccessContainer, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      onWarning: Color.lerp(onWarning, other.onWarning, t)!,
      warningContainer: Color.lerp(warningContainer, other.warningContainer, t)!,
      onWarningContainer: Color.lerp(onWarningContainer, other.onWarningContainer, t)!,
      info: Color.lerp(info, other.info, t)!,
      onInfo: Color.lerp(onInfo, other.onInfo, t)!,
      infoContainer: Color.lerp(infoContainer, other.infoContainer, t)!,
      onInfoContainer: Color.lerp(onInfoContainer, other.onInfoContainer, t)!,
    );
  }
}

/// Extension on [BuildContext] for convenient semantic color access.
extension SemanticColorsExtension on BuildContext {
  SemanticColors get semanticColors => Theme.of(this).extension<SemanticColors>()!;
}
