import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/features/sql_editor/domain/editor_language.dart';
import 'package:libredb_mobile/features/sql_editor/presentation/widgets/highlighting_text_controller.dart';
import 'package:libredb_mobile/shared/utils/source_highlighter.dart';
import 'package:libredb_mobile/shared/design_system/theme/app_theme_palette.dart';
import 'package:libredb_mobile/shared/design_system/theme/environment_colors.dart';
import 'package:libredb_mobile/shared/design_system/theme/theme_colors.dart';

const _base = TextStyle(fontSize: 14);
const _styles = {
  SourceTokenKind.plain: _base,
  SourceTokenKind.keyword: TextStyle(fontSize: 14, color: Color(0xFF0000FF)),
  SourceTokenKind.string: TextStyle(fontSize: 14, color: Color(0xFF00FF00)),
  SourceTokenKind.number: TextStyle(fontSize: 14, color: Color(0xFFFF0000)),
  SourceTokenKind.comment: TextStyle(fontSize: 14, color: Color(0xFF888888)),
};

/// The pieces of [span] with the token kind each one's style stands for.
List<(String, SourceTokenKind?)> _pieces(TextSpan span) => [
  if (span.text != null) (span.text!, _kindOf(span.style)),
  for (final child in span.children ?? const <InlineSpan>[]) ..._pieces(child as TextSpan),
];

SourceTokenKind? _kindOf(TextStyle? style) {
  for (final entry in _styles.entries) {
    if (style?.color == entry.value.color && entry.key != SourceTokenKind.plain) return entry.key;
  }
  return style == null || style.color == null ? SourceTokenKind.plain : null;
}

String _text(TextSpan span) => _pieces(span).map((piece) => piece.$1).join();

void main() {
  TextSpan span(String text, EditorHighlighting highlighting, {TextRange composing = TextRange.empty}) =>
      HighlightingTextController.highlight(
        text: text,
        highlighting: highlighting,
        style: _base,
        styles: _styles,
        composing: composing,
      );

  group('HighlightingTextController.highlight', () {
    test('marks SQL keywords in any case, strings, numbers and comments, across lines', () {
      final result = span("select * from orders\nWHERE id = 1 AND n = 'x' -- c", EditorHighlighting.sql);

      expect(_text(result), "select * from orders\nWHERE id = 1 AND n = 'x' -- c");
      expect(_pieces(result).where((piece) => piece.$2 != SourceTokenKind.plain).toList(), [
        ('select', SourceTokenKind.keyword),
        ('from', SourceTokenKind.keyword),
        ('WHERE', SourceTokenKind.keyword),
        ('1', SourceTokenKind.number),
        ('AND', SourceTokenKind.keyword),
        ("'x'", SourceTokenKind.string),
        ('-- c', SourceTokenKind.comment),
      ]);
    });

    test('marks JSON strings, numbers and literals', () {
      final result = span('{"a": 1, "b": true}', EditorHighlighting.json);

      expect(_text(result), '{"a": 1, "b": true}');
      expect(_pieces(result).where((piece) => piece.$2 != SourceTokenKind.plain).toList(), [
        ('"a"', SourceTokenKind.string),
        ('1', SourceTokenKind.number),
        ('"b"', SourceTokenKind.string),
        ('true', SourceTokenKind.keyword),
      ]);
    });

    test('plain text keeps every word plain', () {
      final result = span('select * from orders', EditorHighlighting.plain);

      expect(_pieces(result), [('select * from orders', SourceTokenKind.plain)]);
    });

    test('a text over 10,000 characters is shown plain, and one of exactly 10,000 is highlighted', () {
      // 10,000 keeps an edit within one frame at 60 Hz on the API 33 emulator; 20,000 took about two.
      expect(HighlightingTextController.maxHighlightedLength, 10000);
      final atLimit = 'select ${'x' * (HighlightingTextController.maxHighlightedLength - 7)}';
      final overLimit = '${atLimit}x';
      expect(atLimit.length, HighlightingTextController.maxHighlightedLength);

      expect(_pieces(span(atLimit, EditorHighlighting.sql)).first, ('select', SourceTokenKind.keyword));
      expect(_pieces(span(overLimit, EditorHighlighting.sql)), [(overLimit, SourceTokenKind.plain)]);
    });

    test('underlines the composing range across token borders and keeps the colours', () {
      final result = span('select x', EditorHighlighting.sql, composing: const TextRange(start: 4, end: 8));

      expect(_text(result), 'select x');
      final underlined = <String>[];
      void walk(TextSpan node) {
        if (node.text != null && node.style?.decoration == TextDecoration.underline) underlined.add(node.text!);
        for (final child in node.children ?? const <InlineSpan>[]) {
          walk(child as TextSpan);
        }
      }

      walk(result);
      expect(underlined.join(), 'ct x');
      expect(_pieces(result).first, ('sele', SourceTokenKind.keyword));
    });
  });

  testWidgets('the controller builds the highlighted span for its language and plain text without one', (tester) async {
    final controller = HighlightingTextController(text: 'select 1');
    addTearDown(controller.dispose);
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (built) {
            context = built;
            return const SizedBox();
          },
        ),
      ),
    );

    final plain = controller.buildTextSpan(context: context, style: _base, withComposing: false);
    expect(plain.children, anyOf(isNull, isEmpty));
    expect(plain.toPlainText(), 'select 1');

    var notified = 0;
    controller.addListener(() => notified++);
    controller.highlighting = EditorHighlighting.sql;
    expect(notified, 1);
    controller.highlighting = EditorHighlighting.sql;
    expect(notified, 1);

    final highlighted = controller.buildTextSpan(context: context, style: _base, withComposing: false);
    expect(highlighted.toPlainText(), 'select 1');
    expect(highlighted.children, isNotEmpty);
  });

  group('every kind of token can be read', () {
    // The editor and the source viewer paint a statement the user has to read, so every token colour is text
    // under WCAG 1.4.3 and carries the 4.5:1 floor the palette guards apply. Nothing measured them until #283
    // pointed `primary` at the product's indigo: `--action-primary` is 6.29:1 on a light page and **3.08:1** on a
    // dark one, so the keyword of every statement in the editor stopped clearing the floor in three of the six
    // palettes at once. A brand colour that works as a button fill is not thereby a colour text can be set in.
    for (final palette in AppThemePalette.values) {
      for (final brightness in Brightness.values) {
        test('in ${palette.name}/${brightness.name}', () {
          final scheme = ThemeColors.getColorScheme(palette, brightness);
          final styles = HighlightingTextController.stylesOf(scheme, const TextStyle(fontSize: 14));
          final under = <String>[];
          styles.forEach((kind, style) {
            final colour = style.color ?? scheme.onSurface;
            final ratio = contrastRatio(colour, scheme.surface);
            if (ratio < 4.5) under.add('${kind.name}: ${ratio.toStringAsFixed(2)}:1, floor 4.5:1');
          });
          expect(under, isEmpty, reason: 'in ${palette.name}/${brightness.name}:\n${under.join('\n')}');
        });
      }
    }
  });
}
