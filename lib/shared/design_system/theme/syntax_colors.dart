import 'package:flutter/material.dart';

/// The ink a SQL statement is shown in on the introduction's editor: the keyword and the string, in each scope.
///
/// The approved prototype's `--kw` (`#6D28D9` / `#C4B5FD`) and `--str` (`#0F766E` / `#5EEAD4`). They are not
/// [ColorScheme] roles — a scheme has no "keyword" — so they are written here, with the theme, rather than as
/// literals on a screen.
abstract final class SyntaxColors {
  /// `.k`: a keyword, drawn semibold.
  static Color keyword(Brightness brightness) =>
      brightness == Brightness.dark ? const Color(0xFFC4B5FD) : const Color(0xFF6D28D9);

  /// `.s`: a string, and the number the prototype sets in the same ink.
  static Color string(Brightness brightness) =>
      brightness == Brightness.dark ? const Color(0xFF5EEAD4) : const Color(0xFF0F766E);
}
