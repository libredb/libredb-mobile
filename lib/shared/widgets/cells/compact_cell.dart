import 'package:flutter/material.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/shared/utils/cell_values.dart';

/// One result value in a grid cell or a card row: one line, cut with an ellipsis, as Studio's grid cell shows it.
///
/// NULL is a muted italic `NULL` that a screen reader reads as a null value rather than as four letters, so it is never
/// confused with the string `'NULL'`, which shows as plain text.
class CompactCell extends StatelessWidget {
  const CompactCell({super.key, required this.cell, this.style});

  /// More characters than one line of any phone shows; a longer text is cut before layout, which the ellipsis hides.
  static const maxShownCharacters = 500;

  static final _whitespace = RegExp(r'\s+');

  final CellValue cell;

  /// The style of a value; NULL takes it in muted italic.
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final base = style ?? Theme.of(context).textTheme.bodyMedium;
    return switch (cell) {
      NullCell() => Semantics(
        label: S.of(context).cell_null_semantics,
        excludeSemantics: true,
        child: _line(
          cell.compactText,
          base?.copyWith(fontStyle: FontStyle.italic, color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ),
      ScalarCell() || JsonCell() || BinaryCell() || VectorCell() => _line(shownText(cell.compactText), base),
    };
  }

  Widget _line(String text, TextStyle? style) =>
      Text(text, style: style, maxLines: 1, softWrap: false, overflow: TextOverflow.ellipsis);

  /// The start of [text] on one line, its runs of whitespace as single spaces, as a CSS cell that does not wrap shows
  /// them.
  static String shownText(String text) {
    final head = text.length > maxShownCharacters ? text.characters.take(maxShownCharacters).toString() : text;
    return head.replaceAll(_whitespace, ' ');
  }
}
