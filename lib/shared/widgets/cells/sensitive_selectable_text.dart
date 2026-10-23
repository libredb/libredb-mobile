import 'package:flutter/material.dart';

/// A selectable result value whose copied selection goes to [onCopy] instead of Flutter's plain clipboard, which
/// marks nothing as sensitive.
///
/// The toolbar keeps only Copy and Select all: Share would hand the value to another app, and Look Up and Search Web
/// to the system. Ctrl+C (Cmd+C) is routed to [onCopy] too, by overriding [CopySelectionTextIntent], which
/// [EditableText] declares overridable.
class SensitiveSelectableText extends StatefulWidget {
  const SensitiveSelectableText(this.text, {super.key, required this.onCopy, this.style});

  final String text;
  final TextStyle? style;

  /// Puts the selected text on the clipboard; the result view passes `SensitiveClipboard`'s copy.
  final ValueChanged<String> onCopy;

  @override
  State<SensitiveSelectableText> createState() => _SensitiveSelectableTextState();
}

class _SensitiveSelectableTextState extends State<SensitiveSelectableText> {
  TextSelection _selection = const TextSelection.collapsed(offset: -1);

  static const _kept = {ContextMenuButtonType.copy, ContextMenuButtonType.selectAll};

  void _copy(TextSelection selection) {
    if (!selection.isValid || selection.isCollapsed) return;
    widget.onCopy(selection.textInside(widget.text));
  }

  @override
  Widget build(BuildContext context) => Actions(
    actions: {
      CopySelectionTextIntent: CallbackAction<CopySelectionTextIntent>(
        onInvoke: (intent) {
          _copy(_selection);
          return null;
        },
      ),
    },
    child: SelectableText(
      widget.text,
      style: widget.style,
      onSelectionChanged: (selection, cause) => _selection = selection,
      contextMenuBuilder: (context, editable) => AdaptiveTextSelectionToolbar.buttonItems(
        anchors: editable.contextMenuAnchors,
        buttonItems: [
          for (final item in editable.contextMenuButtonItems)
            if (_kept.contains(item.type))
              item.type == ContextMenuButtonType.copy
                  ? item.copyWith(
                      onPressed: () {
                        _copy(editable.textEditingValue.selection);
                        editable.hideToolbar();
                      },
                    )
                  : item,
        ],
      ),
    ),
  );
}
