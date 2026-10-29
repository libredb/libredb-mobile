import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:libredb_mobile/features/onboarding/presentation/widgets/lock_mark.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/shared/design_system/tokens/app_typography.dart';
import 'package:libredb_mobile/shared/design_system/tokens/tokens.dart';
import 'package:libredb_mobile/shared/models/query_result.dart';
import 'package:libredb_mobile/shared/security/result_masking/mask_result.dart';
import 'package:libredb_mobile/shared/security/result_masking/masking_policy.dart';

/// The hero of the second screen of the introduction: the tree, then the rows, then a column closing over into a mask.
///
/// The schema unfolds, the three table row counts count up, `orders` lights, the tree slides out and a three-row grid
/// slides in. The addresses arrive **in the clear** and then close over: a short blur, then the masked form, with a
/// padlock beside each value.
///
/// The mask is not written here. The clear rows go through [maskResult] with the same [MaskingPolicy] a real screen
/// builds, so the shape on screen is Studio's own email mask — the one that keeps the value's length — and a change
/// to it changes this screen too. That direction is the point of the screen: `POST /api/db/query` answers raw rows
/// (`docs/architecture.md:361`), the rule is Studio's policy, and the phone is what applies it.
///
/// **The drawing is the prototype's**, measured in headless Chrome at 390x844 (`ob.html`, screen 2): the tree is four
/// 28
/// high rows in a card 114 high, the grid a 28 high header over three 29 high rows in a card 117 high, in mono 11, and
/// the padlock sits in each masked cell. The counts are the numbers alone, as the prototype writes them.
///
/// Nothing here is tappable: Next is the introduction's only control. It plays once, as soon as it is shown, and with
/// `MediaQuery.disableAnimationsOf` on it is finished on its first frame.
class Step2Browse extends StatefulWidget {
  const Step2Browse({super.key});

  @override
  State<Step2Browse> createState() => _Step2BrowseState();
}

/// The whole timeline, so every beat below is a fraction of one controller.
const _total = Duration(milliseconds: 4100);

/// The tree: one node's entrance, the gap between two entrances, and how far a node rises into place.
const _nodeRise = AppDurations.media;
const _nodeStagger = Duration(milliseconds: 90);
const _riseFrom = AppSpacing.md;

/// The counts, which start while the nodes are still arriving and run longer than they do.
const _countAt = Duration(milliseconds: 280);
const _countFor = Duration(milliseconds: 820);

/// `orders` lighting: the table the grid below is about to show.
const _litAt = Duration(milliseconds: 1150);

/// The tree leaving to the left, and the grid arriving from the right: `.out-l`/`.in-r` travel 22.
const _treeOutAt = Duration(milliseconds: 1900);
const _gridInAt = Duration(milliseconds: 2300);
const _gridIn = Duration(milliseconds: 450);
const _slideBy = 22.0;

/// The masking: a value blurs from [_closeAt], and at [_maskAt] it is the mask that is left. One row after another.
const _closeAt = Duration(milliseconds: 3000);
const _maskAt = Duration(milliseconds: 3250);
const _rowStagger = Duration(milliseconds: 110);
const _blurSigma = 3.0;

/// The note, last.
const _noteAt = Duration(milliseconds: 3550);

/// The tree's own measures: `.tn{display:flex;gap:8px;padding:6.5px 11px}` with a 12 name over a 15 line and the tables
/// at `padding-left:30px`, `.tn.l2:before{left:20px;width:1px}` and `.tn.lit{border-radius:11px}`.
const double _nodePadX = 11;
const double _nodePadY = 6.5;
const double _nodeIndent = 30;
const double _guideAt = 20;
const double _litRadius = 11;
const double _nameSize = 12;
const double _nameLine = 15 / _nameSize;

/// The grid's own measures: `.gh div,.gd div{padding:7px 8px}` in columns of `40px 1fr 66px`, mono 11 over a 14 line,
/// the padlock 10 square and `gap:5px` before the value, the header tracked `.09em`.
const double _cellPadX = 8;
const double _cellPadY = 7;
const double _idWidth = 40;
const double _totalWidth = 66;
const double _lockSize = 10;
const double _lockGap = 5;
const double _monoSize = 11;
const double _monoLine = 14 / _monoSize;
const double _headTrackingEm = 0.09;

/// `.note{font-family:var(--mono);font-size:11px;line-height:1.5;margin-top:8px}`.
const double _noteLine = 1.5;

/// The least room a tree line leaves the name beside the row count, in ems of the name's own type.
///
/// A row count is laid out at its natural width — a `Row` has nothing to shrink it with — and that width is the
/// reader's to set: at a text scale of 3.0 `128.440` is wider than half the hero. One em is the width of a character
/// of the name, so the line is kept while the name still has a character's room on it and given up when it has not,
/// which is the moment the name would otherwise be squeezed away and the count would spill out of the card. The count
/// then takes a line of its own, under the name.
const _nameFloorEm = 1.0;

/// The demo schema. The counts are the numbers the screen counts up to.
const _schema = 'public';
const _tables = [('orders', 128440), ('customers', 12901), ('invoices', 44512)];

/// The table the grid shows, which is the one that lights in the tree.
const _litTable = 'orders';

const _fields = ['id', 'email', 'total'];

/// What the engine answered: a `numeric` column arrives as the text the engine printed, so the totals are strings,
/// and nothing here is a locale rendering of a number.
final _clear = QueryResult(
  fields: _fields,
  rows: const [
    {'id': '8842', 'email': 'ayse@libredb.io', 'total': '1249.00'},
    {'id': '8839', 'email': 'mert@libredb.io', 'total': '3100.00'},
    {'id': '8831', 'email': 'onur@libredb.io', 'total': '1075.40'},
  ],
  rowCount: 3,
  executionTime: const Duration(milliseconds: 41),
);

/// The same rows under the policy a signed-in user gets, and the columns it masked.
final _masked = maskResult(_clear, MaskingPolicy.forRole(null));

class _Step2BrowseState extends State<Step2Browse> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: _total);

  late final List<Animation<double>> _nodes = [
    for (var i = 0; i < _tables.length + 1; i++) _beat(_nodeStagger * i, _nodeRise),
  ];
  late final List<Animation<double>> _counts = [
    for (var i = 0; i < _tables.length; i++) _beat(_countAt + _nodeStagger * (i + 1), _countFor),
  ];
  late final Animation<double> _lit = _beat(_litAt, AppDurations.normal);
  late final Animation<double> _treeOut = CurvedAnimation(
    parent: _controller,
    curve: _interval(_treeOutAt, AppDurations.media, AppDurations.easeIn),
  );
  late final Animation<double> _gridInProgress = _beat(_gridInAt, _gridIn);
  late final List<Animation<double>> _closes = [
    for (var i = 0; i < _tables.length; i++) _beat(_closeAt + _rowStagger * i, AppDurations.media),
  ];
  late final List<Animation<double>> _reveals = [
    for (var i = 0; i < _tables.length; i++) _beat(_maskAt + _rowStagger * i, AppDurations.media),
  ];
  late final Animation<double> _note = _beat(_noteAt, AppDurations.media);

  Interval _interval(Duration begin, Duration length, Curve curve) => Interval(
    begin.inMilliseconds / _total.inMilliseconds,
    (begin + length).inMilliseconds / _total.inMilliseconds,
    curve: curve,
  );

  /// [length] of the timeline from [begin], on the design system's entrance curve.
  Animation<double> _beat(Duration begin, Duration length) =>
      CurvedAnimation(parent: _controller, curve: _interval(begin, length, AppDurations.easeOut));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Read here rather than in initState: the setting is a MediaQuery, and a step shown with animations off settles
    // into its finished, usable state instead of playing.
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller
        ..stop()
        ..value = 1;
    } else if (_controller.isDismissed) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Whether the tree is still the thing on screen. Past [_gridInAt] it is gone rather than merely transparent, so
  /// what a test — or a screen reader — finds is what the screen is showing.
  bool get _treeIsShowing => _controller.value * _total.inMilliseconds < _gridInAt.inMilliseconds;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        // The tree is centred on its own and the grid with its note under it, as the prototype's two wrappers are: the
        // note belongs to the grid's phase, so it is not there to take room while the tree is.
        children: _treeIsShowing
            ? [
                Opacity(
                  key: const ValueKey('ob2-tree'),
                  opacity: 1 - _treeOut.value,
                  child: Transform.translate(offset: Offset(-_treeOut.value * _slideBy, 0), child: _tree(context)),
                ),
              ]
            : [
                Opacity(
                  key: const ValueKey('ob2-grid'),
                  opacity: _gridInProgress.value,
                  child: Transform.translate(
                    offset: Offset((1 - _gridInProgress.value) * _slideBy, 0),
                    child: _grid(context),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Opacity(
                  key: const ValueKey('ob2-note'),
                  opacity: _note.value,
                  child: Text(
                    S.of(context).ob2_why,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontFamily: AppTypography.mono,
                      fontSize: _monoSize,
                      height: _noteLine,
                      letterSpacing: 0,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
      ),
    );
  }

  Widget _tree(BuildContext context) {
    final l10n = S.of(context);
    final number = NumberFormat.decimalPattern(Localizations.localeOf(context).toString());
    return _Card(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _rising(
            _nodes.first,
            _TreeNode(
              key: const ValueKey('ob2-node-0'),
              name: _schema,
              trailing: l10n.ob2_tables(_tables.length),
              isSchema: true,
              lit: 0,
            ),
          ),
          for (final (index, (name, count)) in _tables.indexed)
            _rising(
              _nodes[index + 1],
              _TreeNode(
                key: ValueKey('ob2-node-${index + 1}'),
                guideKey: ValueKey('ob2-guide-${index + 1}'),
                name: name,
                // The number alone, as `.ct` is in the prototype; the unit is said to a screen reader.
                trailing: number.format((count * _counts[index].value).round()),
                semanticsLabel: l10n.browse_object_rows(count, number.format(count)),
                isSchema: false,
                lit: name == _litTable ? _lit.value : 0,
              ),
            ),
        ],
      ),
    );
  }

  Widget _rising(Animation<double> beat, Widget child) => Opacity(
    opacity: beat.value,
    child: Transform.translate(offset: Offset(0, (1 - beat.value) * _riseFrom), child: child),
  );

  Widget _grid(BuildContext context) {
    return _Card(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _GridHeader(),
          for (final (index, row) in _clear.rows.indexed)
            _GridRow(
              key: ValueKey('ob2-row-$index'),
              index: index,
              clear: row,
              masked: _masked.result.rows[index],
              maskedColumns: _masked.maskedColumns,
              blur: _blurOf(index),
              reveal: _reveals[index].value,
              isMasked: _reveals[index].value > 0,
            ),
        ],
      ),
    );
  }

  /// How far the values of row [index] are blurred: they close over, and once the mask has replaced them the blur
  /// clears again, so the moment the value changes is the moment nobody can read either form.
  double _blurOf(int index) => _blurSigma * (_closes[index].value - _reveals[index].value);
}

/// The card the tree and the grid are drawn in: the surface and the border a list of rows has in the app.
///
/// A `Container`, not a `DecoratedBox`: CSS draws the 1px border outside the rows, which only the `Container` gives.
class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      borderRadius: BorderRadius.circular(AppRadius.xl),
    ),
    child: ClipRRect(borderRadius: BorderRadius.circular(AppRadius.xl), child: child),
  );
}

/// One line of the tree: a name, and the number or the count of tables on the right.
///
/// One line while the two fit on one. At an accessibility text size the count outgrows the line it shares — a count is
/// as wide as the text size makes it and a `Row` cannot shrink it — and then it takes a line of its own under the
/// name, where it is free to wrap rather than spill out of the card. [_nameFloorEm] is where the line is given up; at
/// the ordinary text size, which is the size the screen was measured against, nothing moves.
class _TreeNode extends StatelessWidget {
  const _TreeNode({
    required this.name,
    required this.trailing,
    required this.isSchema,
    required this.lit,
    super.key,
    this.guideKey,
    this.semanticsLabel,
  });

  final String name;
  final String trailing;

  /// What a screen reader says for [trailing] when the digits alone are not it.
  final String? semanticsLabel;

  /// The key of the guide line the tables are drawn against; the schema has none.
  final Key? guideKey;

  /// Whether the line is the schema rather than one of its tables.
  final bool isSchema;

  /// How far the line is lit, 0 to 1.
  final double lit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ink = Color.lerp(scheme.onSurface, scheme.onPrimaryContainer, lit);
    final quiet = Color.lerp(scheme.onSurfaceVariant, scheme.onPrimaryContainer, lit);
    final nameStyle = theme.textTheme.bodyMedium?.copyWith(
      fontSize: _nameSize,
      height: _nameLine,
      letterSpacing: 0,
      fontWeight: isSchema ? FontWeight.w600 : FontWeight.w500,
      color: ink,
    );
    final countStyle = theme.textTheme.labelSmall?.copyWith(
      fontFamily: AppTypography.mono,
      fontSize: _monoSize,
      height: _monoLine,
      letterSpacing: 0,
      fontWeight: FontWeight.w400,
      color: quiet,
    );
    final nameText = Text(name, style: nameStyle, maxLines: 1, overflow: TextOverflow.ellipsis);
    final countText = Semantics(
      label: semanticsLabel,
      excludeSemantics: semanticsLabel != null,
      child: Text(trailing, style: countStyle, maxLines: 1),
    );
    return Container(
      decoration: BoxDecoration(
        color: Color.lerp(null, scheme.primaryContainer, lit),
        borderRadius: BorderRadius.circular(_litRadius),
      ),
      child: Stack(
        children: [
          if (!isSchema)
            Positioned(
              left: _guideAt,
              top: 0,
              bottom: 0,
              width: 1,
              child: ColoredBox(key: guideKey, color: scheme.outlineVariant),
            ),
          Padding(
            padding: EdgeInsets.fromLTRB(isSchema ? _nodePadX : _nodeIndent, _nodePadY, _nodePadX, _nodePadY),
            // The line is laid out against the room it actually has, which is a width and not a text scale: the same
            // count fits a phone at a scale of 1.3 and does not fit a small one. Safe here — the chassis answers the
            // page's intrinsic question itself and never puts it to the hero.
            //
            // The two texts are built once above the branch rather than twice inside it: both arrangements draw the
            // same two, and written inline their `maxLines: 1` sat where `design_token_test`'s spacing pattern, which
            // scans forward from the word for the next number, read it as an off-scale gap of 1.
            child: LayoutBuilder(
              builder: (context, line) => _holdsOneLine(context, line.maxWidth, nameStyle, countStyle)
                  ? Row(
                      spacing: AppSpacing.sm,
                      children: [
                        Expanded(child: nameText),
                        countText,
                      ],
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: nameStyle, maxLines: 1, overflow: TextOverflow.ellipsis),
                        // Nothing cuts the count short on its own line: a count a line cannot hold wraps onto the
                        // next, which the hero's own scroll view absorbs.
                        Text(trailing, style: countStyle),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  /// Whether the name and the count still share one line of [width].
  ///
  /// The count's width is measured rather than guessed: what `128.440` comes to is the font's business and the text
  /// size is the reader's, and a `Row` lays an inflexible child out at its natural width whatever is left.
  bool _holdsOneLine(BuildContext context, double width, TextStyle? nameStyle, TextStyle? countStyle) {
    final scaler = MediaQuery.textScalerOf(context);
    final painter = TextPainter(
      text: TextSpan(text: trailing, style: DefaultTextStyle.of(context).style.merge(countStyle)),
      textDirection: Directionality.of(context),
      textScaler: scaler,
      maxLines: 1,
    )..layout();
    final count = painter.width;
    painter.dispose();
    return count + AppSpacing.sm + scaler.scale(nameStyle?.fontSize ?? 0) * _nameFloorEm <= width;
  }
}

/// One cell of the grid: `padding:7px 8px` in a column, with the rule `border-right:1px` the first two carry.
///
/// A cell with a fixed [width] scales its words down rather than spill: the prototype's own `id` is wider than the
/// content box its padding leaves and is clipped to the padding box, so the right padding is given up when [bleed] is
/// set, which is what lets `8842` sit at full size in a 40 column. The one that takes the rest ellipsizes instead.
class _Cell extends StatelessWidget {
  const _Cell({
    required this.child,
    super.key,
    this.width,
    this.rule = true,
    this.alignEnd = false,
    this.bleed = false,
  });

  /// The column's width, or null for the one that takes the rest.
  final double? width;

  /// Whether the cell carries the rule on its right.
  final bool rule;
  final bool alignEnd;
  final bool bleed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final alignment = alignEnd ? Alignment.centerRight : Alignment.centerLeft;
    final cell = Container(
      width: width,
      decoration: BoxDecoration(
        border: rule ? Border(right: BorderSide(color: Theme.of(context).colorScheme.outlineVariant)) : null,
      ),
      padding: EdgeInsets.fromLTRB(_cellPadX, _cellPadY, bleed ? 0 : _cellPadX, _cellPadY),
      alignment: alignment,
      child: width == null ? child : FittedBox(fit: BoxFit.scaleDown, alignment: alignment, child: child),
    );
    return width == null ? Expanded(child: cell) : cell;
  }
}

TextStyle? _monoStyle(BuildContext context, {FontWeight weight = FontWeight.w400, double tracking = 0, Color? color}) {
  final theme = Theme.of(context);
  return theme.textTheme.labelSmall?.copyWith(
    fontFamily: AppTypography.mono,
    fontSize: _monoSize,
    height: _monoLine,
    fontWeight: weight,
    letterSpacing: tracking,
    color: color ?? theme.colorScheme.onSurface,
  );
}

/// The header of the demo grid: `.gh{background:var(--fill);color:var(--quiet);font-weight:600;letter-spacing:.09em}`.
class _GridHeader extends StatelessWidget {
  const _GridHeader();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = _monoStyle(
      context,
      weight: FontWeight.w600,
      tracking: _monoSize * _headTrackingEm,
      color: scheme.onSurfaceVariant,
    );
    Text label(String field) => Text(field, style: style, softWrap: false, overflow: TextOverflow.ellipsis);
    return ColoredBox(
      key: const ValueKey('ob2-head'),
      color: scheme.surfaceContainerHighest,
      child: Row(
        children: [
          _Cell(key: const ValueKey('ob2-head-id'), width: _idWidth, bleed: true, child: label(_fields[0])),
          _Cell(key: const ValueKey('ob2-head-email'), child: label(_fields[1])),
          _Cell(
            key: const ValueKey('ob2-head-total'),
            width: _totalWidth,
            rule: false,
            alignEnd: true,
            child: label(_fields[2]),
          ),
        ],
      ),
    );
  }
}

/// One row of the demo grid, in whichever form the timeline has reached: the clear values, or the masked ones.
///
/// `.gd{border-top:1px solid var(--line)}` over 28 of cells, so 29; the padlock is in the cell, a 10 square that is
/// there from the start so the value never moves when it fades in.
class _GridRow extends StatelessWidget {
  const _GridRow({
    required this.index,
    required this.clear,
    required this.masked,
    required this.maskedColumns,
    required this.blur,
    required this.reveal,
    required this.isMasked,
    super.key,
  });

  final int index;
  final Map<String, Object?> clear;
  final Map<String, Object?> masked;
  final Set<String> maskedColumns;

  /// The blur the value closes over behind, in sigma.
  final double blur;

  /// How far the mask has taken the clear value's place, 0 to 1: the padlock's opacity.
  final double reveal;

  /// Whether the mask has taken the clear value's place.
  final bool isMasked;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    String value(String field) => '${(isMasked && maskedColumns.contains(field) ? masked : clear)[field]}';

    Text text(String field, {Color? color, TextOverflow overflow = TextOverflow.visible}) => Text(
      value(field),
      style: _monoStyle(context, color: color),
      softWrap: false,
      overflow: overflow,
    );

    final email = text(_fields[1], color: isMasked ? scheme.onPrimaryContainer : null, overflow: TextOverflow.ellipsis);
    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Row(
        children: [
          _Cell(width: _idWidth, bleed: true, child: text(_fields[0])),
          _Cell(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: _lockGap,
              children: [
                Opacity(
                  key: ValueKey('ob2-mask-lock-$index'),
                  opacity: reveal,
                  child: Semantics(
                    label: S.of(context).result_masked_semantics,
                    child: LockMark(size: _lockSize, color: scheme.onSurfaceVariant),
                  ),
                ),
                Flexible(
                  child: blur > 0
                      ? ImageFiltered(
                          imageFilter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
                          child: email,
                        )
                      : email,
                ),
              ],
            ),
          ),
          _Cell(width: _totalWidth, rule: false, alignEnd: true, child: text(_fields[2])),
        ],
      ),
    );
  }
}
