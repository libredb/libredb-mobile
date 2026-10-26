import 'package:flutter/material.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/shared/utils/cell_values.dart';
import 'package:libredb_mobile/shared/widgets/cells/sensitive_selectable_text.dart';
import 'package:libredb_mobile/shared/design_system/tokens/app_typography.dart';

/// One result value in full, as Studio's row detail shows it: selectable, with JSON, binary and vector values in
/// monospace and their line breaks kept, and NULL as a muted italic `null` that a screen reader reads as a null value.
///
/// A copied selection goes to [onCopy], never to the plain clipboard ([SensitiveSelectableText]).
class DetailCell extends StatelessWidget {
  const DetailCell({super.key, required this.cell, required this.onCopy, this.style});

  final CellValue cell;

  /// Puts a selected part of the value on the clipboard.
  final ValueChanged<String> onCopy;

  /// The style of a value; NULL takes it in muted italic, and JSON, binary and vector values in monospace.
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = style ?? theme.textTheme.bodyMedium;
    return switch (cell) {
      NullCell() => Semantics(
        label: S.of(context).cell_null_semantics,
        excludeSemantics: true,
        child: SensitiveSelectableText(
          cell.detailText,
          onCopy: onCopy,
          style: base?.copyWith(fontStyle: FontStyle.italic, color: theme.colorScheme.onSurfaceVariant),
        ),
      ),
      ScalarCell() => SensitiveSelectableText(cell.detailText, onCopy: onCopy, style: base),
      JsonCell() || BinaryCell() || VectorCell() => SensitiveSelectableText(
        cell.detailText,
        onCopy: onCopy,
        style: base?.copyWith(fontFamily: AppTypography.mono),
      ),
    };
  }
}
