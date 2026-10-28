import 'package:flutter/material.dart';
import 'package:libredb_mobile/features/sql_editor/domain/editor_language.dart';
import 'package:libredb_mobile/shared/utils/source_highlighter.dart';

/// The editor's text controller: it colours the text it holds by [highlighting], with the source viewer's
/// [SourceHighlighter] and colours, and shows plain text until a language is set.
///
/// A text longer than [maxHighlightedLength] is shown plain, since the whole text is coloured and laid out again on
/// every edit: on the API 33 emulator a coloured text of 10,000 characters took 12.5 ms per edit and one of 20,000
/// took 26.9 ms, two frames at 60 Hz.
class HighlightingTextController extends TextEditingController {
  HighlightingTextController({super.text});

  /// The longest text that is coloured, counted as `String.length`.
  static const maxHighlightedLength = 10000;

  EditorHighlighting _highlighting = EditorHighlighting.plain;

  EditorHighlighting get highlighting => _highlighting;

  set highlighting(EditorHighlighting value) {
    if (value == _highlighting) return;
    _highlighting = value;
    notifyListeners();
  }

  @override
  TextSpan buildTextSpan({required BuildContext context, TextStyle? style, required bool withComposing}) {
    if (_highlighting == EditorHighlighting.plain || text.length > maxHighlightedLength) {
      return super.buildTextSpan(context: context, style: style, withComposing: withComposing);
    }
    final base = style ?? const TextStyle();
    return highlight(
      text: text,
      highlighting: _highlighting,
      style: base,
      styles: stylesOf(Theme.of(context).colorScheme, base),
      composing: withComposing && value.isComposingRangeValid ? value.composing : TextRange.empty,
    );
  }

  /// The colours of each kind of token over [base], the ones the source viewer uses.
  static Map<SourceTokenKind, TextStyle> stylesOf(ColorScheme scheme, TextStyle base) => {
    SourceTokenKind.plain: base,
    // `onPrimaryContainer`, not `primary`: Material has no role for brand-coloured *text*, and this app's
    // `onPrimaryContainer` carries the design system's `--text-brand`, which is that token. A keyword is read,
    // so it takes the 4.5:1 floor, and `--action-primary` is 3.08:1 on a dark page (#283).
    SourceTokenKind.keyword: base.copyWith(color: scheme.onPrimaryContainer, fontWeight: FontWeight.w600),
    SourceTokenKind.string: base.copyWith(color: scheme.tertiary),
    SourceTokenKind.number: base.copyWith(color: scheme.secondary),
    SourceTokenKind.comment: base.copyWith(color: scheme.onSurfaceVariant, fontStyle: FontStyle.italic),
  };

  /// [text] as one span in [style], its tokens in [styles] by [highlighting], and the [composing] range underlined as
  /// [TextEditingController] underlines it; plain, or longer than [maxHighlightedLength], it is one piece of [style].
  static TextSpan highlight({
    required String text,
    required EditorHighlighting highlighting,
    required TextStyle style,
    required Map<SourceTokenKind, TextStyle> styles,
    TextRange composing = TextRange.empty,
  }) {
    final language = switch (highlighting) {
      EditorHighlighting.sql => 'sql',
      EditorHighlighting.json => 'json',
      EditorHighlighting.plain => null,
    };
    final pieces = <(int, int, TextStyle)>[];
    // Neighbours of one style become one piece: the layout of each edit costs by the number of spans.
    void add(int start, int end, TextStyle pieceStyle) {
      if (pieces.isNotEmpty && pieces.last.$2 == start && pieces.last.$3 == pieceStyle) {
        pieces.last = (pieces.last.$1, end, pieceStyle);
      } else {
        pieces.add((start, end, pieceStyle));
      }
    }

    if (language == null || text.length > maxHighlightedLength) {
      pieces.add((0, text.length, style));
    } else {
      final highlighter = SourceHighlighter.forLanguage(language);
      final plain = styles[SourceTokenKind.plain] ?? style;
      var offset = 0;
      for (final line in text.split('\n')) {
        if (offset > 0) add(offset - 1, offset, plain);
        for (final token in highlighter.tokens(line)) {
          add(offset, offset + token.text.length, styles[token.kind] ?? style);
          offset += token.text.length;
        }
        offset = offset + 1;
      }
    }
    final underline =
        composing.isValid && !composing.isCollapsed && composing.start >= 0 && composing.end <= text.length;
    if (!underline && pieces.length == 1) return TextSpan(style: style, text: text);
    final children = <TextSpan>[];
    for (final (start, end, pieceStyle) in pieces) {
      if (start == end) continue;
      if (!underline) {
        children.add(TextSpan(text: text.substring(start, end), style: pieceStyle));
        continue;
      }
      final cuts = {start, end, composing.start.clamp(start, end), composing.end.clamp(start, end)}.toList()..sort();
      for (var index = 0; index < cuts.length - 1; index++) {
        final (from, to) = (cuts[index], cuts[index + 1]);
        final composed = from >= composing.start && to <= composing.end;
        children.add(
          TextSpan(
            text: text.substring(from, to),
            style: composed ? pieceStyle.merge(const TextStyle(decoration: TextDecoration.underline)) : pieceStyle,
          ),
        );
      }
    }
    return TextSpan(style: style, children: children);
  }
}
