import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:libredb_mobile/features/object_browser/domain/entities/object_source.dart';
import 'package:libredb_mobile/features/object_browser/presentation/widgets/source_highlighter.dart';
import 'package:libredb_mobile/features/object_browser/presentation/widgets/source_share.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/shared/design_system/tokens/app_spacing.dart';

/// The definition of an object, without page chrome, so the source page shows it under its heading and the detail
/// page can show it as its Source tab. It fills the height it is given, which must be bounded.
///
/// Several parts get a segmented control. A text part shows what Studio says about it (regenerated, partial,
/// truncated with Studio's own sentence), Copy all and Share, and its text in monospace with line numbers, scrolling
/// both ways and built line by line, so a part of a million characters opens at once. A refusal shows that the
/// definition could not be read, with the engine's sentence; a neutral statement shows only its sentence.
class ObjectSourceView extends StatefulWidget {
  const ObjectSourceView({super.key, required this.source});

  final ObjectSource source;

  /// The most characters one row shows; a longer line continues on the rows under it, without a number of its own,
  /// so no row ever lays out a whole minified line.
  static const maxRowLength = 1000;

  @override
  State<ObjectSourceView> createState() => _ObjectSourceViewState();
}

class _ObjectSourceViewState extends State<ObjectSourceView> {
  int _selected = 0;

  @override
  void didUpdateWidget(ObjectSourceView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_selected >= widget.source.parts.length) _selected = 0;
  }

  @override
  Widget build(BuildContext context) {
    final parts = widget.source.parts;
    final part = parts[_selected];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (parts.length > 1)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
            child: SegmentedButton<int>(
              showSelectedIcon: false,
              segments: [
                for (var index = 0; index < parts.length; index++)
                  ButtonSegment(value: index, label: Text(parts[index].label)),
              ],
              selected: {_selected},
              onSelectionChanged: (selection) => setState(() => _selected = selection.single),
            ),
          ),
        Expanded(
          child: switch (part) {
            SourceText() => _TextPart(key: ValueKey(_selected), source: widget.source, part: part),
            SourceUnavailable(:final reason) => _Sentence(
              heading: S.of(context).browse_source_unavailable,
              text: reason,
            ),
            SourceStatement(:final statement) => _Sentence(text: statement),
          },
        ),
      ],
    );
  }
}

/// A part with no text: a refusal under its heading, or a neutral statement on its own.
class _Sentence extends StatelessWidget {
  const _Sentence({this.heading, required this.text});

  final String? heading;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final heading = this.heading;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        if (heading != null) ...[
          Text(heading, style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.error)),
          const SizedBox(height: AppSpacing.xs),
        ],
        Text(text, style: theme.textTheme.bodyMedium),
      ],
    );
  }
}

class _TextPart extends StatelessWidget {
  const _TextPart({super.key, required this.source, required this.part});

  final ObjectSource source;
  final SourceText part;

  Future<void> _copy(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final copied = S.of(context).browse_source_copied;
    await Clipboard.setData(ClipboardData(text: part.text));
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(copied)));
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final captionStyle = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final truncated = part.truncated;
    final captions = [
      if (part.isRegenerated) s.browse_source_regenerated,
      if (!part.complete) s.browse_source_partial,
      // Only Studio's sentence names what the limit counts, so the limit is never shown on its own.
      if (truncated != null) s.browse_source_truncated(truncated.reason),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: AppSpacing.lg, right: AppSpacing.sm),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [for (final caption in captions) Text(caption, style: captionStyle)],
                ),
              ),
              IconButton(
                tooltip: s.browse_source_copy,
                icon: const Icon(Icons.copy_all_outlined),
                onPressed: () => _copy(context),
              ),
              Builder(
                builder: (button) => IconButton(
                  tooltip: s.browse_source_share,
                  icon: const Icon(Icons.share_outlined),
                  onPressed: () => shareSourcePart(button, source: source, part: part),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _SourceLines(text: part.text, language: part.language),
        ),
      ],
    );
  }
}

/// One row of the text: a line, or a piece of a line longer than [ObjectSourceView.maxRowLength], which carries the
/// line's [number] only on its first row.
typedef _Row = ({int? number, String text});

/// The text in monospace with line numbers, scrolling both ways, built row by row as rows come into view.
class _SourceLines extends StatefulWidget {
  const _SourceLines({required this.text, required this.language});

  final String text;
  final String language;

  @override
  State<_SourceLines> createState() => _SourceLinesState();
}

class _SourceLinesState extends State<_SourceLines> {
  late List<_Row> _rows;
  late int _widest;
  late int _lineCount;
  final _horizontal = ScrollController();
  final _vertical = ScrollController();

  @override
  void initState() {
    super.initState();
    _split();
  }

  @override
  void didUpdateWidget(_SourceLines oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) _split();
  }

  void _split() {
    const most = ObjectSourceView.maxRowLength;
    final rows = <_Row>[];
    var widest = 0;
    final lines = widget.text.split('\n');
    for (var index = 0; index < lines.length; index++) {
      final line = lines[index].replaceAll('\t', '    ');
      if (line.length <= most) {
        rows.add((number: index + 1, text: line));
        if (line.length > widest) widest = line.length;
        continue;
      }
      widest = most;
      for (var start = 0; start < line.length; start += most) {
        final end = start + most < line.length ? start + most : line.length;
        rows.add((number: start == 0 ? index + 1 : null, text: line.substring(start, end)));
      }
    }
    _rows = rows;
    _widest = widest;
    _lineCount = lines.length;
  }

  @override
  void dispose() {
    _horizontal.dispose();
    _vertical.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final style = theme.textTheme.bodySmall!.copyWith(fontFamily: 'monospace', fontSize: 13, height: 1.4);
    final numberStyle = style.copyWith(color: scheme.onSurfaceVariant);
    final kindStyles = {
      SourceTokenKind.plain: style,
      SourceTokenKind.keyword: style.copyWith(color: scheme.primary, fontWeight: FontWeight.w600),
      SourceTokenKind.string: style.copyWith(color: scheme.tertiary),
      SourceTokenKind.number: style.copyWith(color: scheme.secondary),
      SourceTokenKind.comment: style.copyWith(color: scheme.onSurfaceVariant, fontStyle: FontStyle.italic),
    };
    final highlighter = SourceHighlighter.forLanguage(widget.language);
    final textScaler = MediaQuery.textScalerOf(context);
    final glyph = TextPainter(
      text: TextSpan(text: 'M', style: style),
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
    )..layout();
    final charWidth = glyph.width;
    final rowHeight = glyph.height;
    glyph.dispose();
    final gutter = charWidth * ('$_lineCount'.length + 2);
    final width = gutter + charWidth * (_widest + 1) + AppSpacing.lg * 2;

    return LayoutBuilder(
      builder: (context, constraints) => Scrollbar(
        controller: _horizontal,
        child: SingleChildScrollView(
          controller: _horizontal,
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: width > constraints.maxWidth ? width : constraints.maxWidth,
            child: Scrollbar(
              controller: _vertical,
              child: ListView.builder(
                controller: _vertical,
                padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                itemExtent: rowHeight,
                itemCount: _rows.length,
                itemBuilder: (context, index) {
                  final row = _rows[index];
                  return Row(
                    children: [
                      SizedBox(
                        width: gutter,
                        child: Padding(
                          padding: EdgeInsets.only(right: charWidth),
                          child: row.number == null
                              ? null
                              : Text('${row.number}', style: numberStyle, textAlign: TextAlign.right, maxLines: 1),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text.rich(
                        TextSpan(
                          children: [
                            for (final token in highlighter.tokens(row.text))
                              TextSpan(text: token.text, style: kindStyles[token.kind]),
                          ],
                        ),
                        style: style,
                        softWrap: false,
                        maxLines: 1,
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
