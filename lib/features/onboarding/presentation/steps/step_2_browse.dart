import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/shared/design_system/tokens/app_typography.dart';
import 'package:libredb_mobile/shared/design_system/tokens/tokens.dart';
import 'package:libredb_mobile/shared/models/query_result.dart';
import 'package:libredb_mobile/shared/security/result_masking/mask_result.dart';
import 'package:libredb_mobile/shared/security/result_masking/masking_policy.dart';
import 'package:libredb_mobile/shared/utils/cell_values.dart';
import 'package:libredb_mobile/shared/widgets/cells/compact_cell.dart';

/// The hero of the second screen of the introduction: the tree, then the rows, then a column closing over into a mask.
///
/// The schema unfolds, the three table row counts count up, `orders` lights, the tree slides out and a three-row grid
/// slides in. The addresses arrive **in the clear** and then close over: a short blur, then the masked form, with a
/// padlock beside the column, where `ResultTable` puts it.
///
/// The mask is not written here. The clear rows go through [maskResult] with the same [MaskingPolicy] a real screen
/// builds, so the shape on screen is Studio's own email mask — the one that keeps the value's length — and a change
/// to it changes this screen too. That direction is the point of the screen: `POST /api/db/query` answers raw rows
/// (`docs/architecture.md:361`), the rule is Studio's policy, and the phone is what applies it.
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

/// The tree leaving to the left, and the grid arriving from the right.
const _treeOutAt = Duration(milliseconds: 1900);
const _gridInAt = Duration(milliseconds: 2300);
const _gridIn = Duration(milliseconds: 450);
const _slideBy = AppSpacing.xl;

/// The masking: a value blurs from [_closeAt], and at [_maskAt] it is the mask that is left. One row after another.
const _closeAt = Duration(milliseconds: 3000);
const _maskAt = Duration(milliseconds: 3250);
const _rowStagger = Duration(milliseconds: 110);
const _blurSigma = 3.0;

/// The note, last.
const _noteAt = Duration(milliseconds: 3550);

/// The padlock beside the masked column's name, as `ResultTable` draws it.
const _lockSize = 12.0;

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
  late final Animation<double> _lock = _beat(_maskAt, AppDurations.media);
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
        children: [
          if (_treeIsShowing)
            Opacity(
              key: const ValueKey('ob2-tree'),
              opacity: 1 - _treeOut.value,
              child: Transform.translate(offset: Offset(-_treeOut.value * _slideBy, 0), child: _tree(context)),
            )
          else
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
              style: Theme.of(context).textTheme.labelSmall
                  ?.copyWith(fontFamily: AppTypography.mono, color: Theme.of(context).colorScheme.onSurfaceVariant),
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
            _TreeNode(name: _schema, trailing: l10n.ob2_tables(_tables.length), isSchema: true, lit: 0),
          ),
          for (final (index, (name, count)) in _tables.indexed)
            _rising(
              _nodes[index + 1],
              _Indented(
                child: _TreeNode(
                  name: name,
                  trailing: _rows(l10n, number, (count * _counts[index].value).round()),
                  isSchema: false,
                  lit: name == _litTable ? _lit.value : 0,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// A count of rows in the words the browse screen itself uses.
  String _rows(S l10n, NumberFormat number, int count) => l10n.browse_object_rows(count, number.format(count));

  Widget _rising(Animation<double> beat, Widget child) => Opacity(
    opacity: beat.value,
    child: Transform.translate(offset: Offset(0, (1 - beat.value) * _riseFrom), child: child),
  );

  Widget _grid(BuildContext context) {
    final theme = Theme.of(context);
    return _Card(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _GridHeader(lock: _lock.value),
          for (final (index, row) in _clear.rows.indexed)
            DecoratedBox(
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: theme.colorScheme.outlineVariant, width: 0.5)),
              ),
              child: _GridRow(
                clear: row,
                masked: _masked.result.rows[index],
                maskedColumns: _masked.maskedColumns,
                blur: _blurOf(index),
                isMasked: _reveals[index].value > 0,
              ),
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
class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      borderRadius: BorderRadius.circular(AppRadius.xl),
    ),
    child: ClipRRect(borderRadius: BorderRadius.circular(AppRadius.xl), child: child),
  );
}

/// A table under its schema, with the guide line the tree draws down the indentation.
class _Indented extends StatelessWidget {
  const _Indented({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: AppSpacing.lg),
    child: DecoratedBox(
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: Theme.of(context).colorScheme.outlineVariant)),
      ),
      child: Padding(
        padding: const EdgeInsets.only(left: AppSpacing.sm),
        child: child,
      ),
    ),
  );
}

/// One line of the tree: a name, and what the browse screen says of it on the right.
class _TreeNode extends StatelessWidget {
  const _TreeNode({required this.name, required this.trailing, required this.isSchema, required this.lit});

  final String name;
  final String trailing;

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
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Color.lerp(null, scheme.primaryContainer, lit),
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        child: Row(
          spacing: AppSpacing.sm,
          children: [
            Expanded(
              child: Text(
                name,
                style: (isSchema ? theme.textTheme.titleSmall : theme.textTheme.bodyMedium)?.copyWith(color: ink),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              trailing,
              style: theme.textTheme.bodySmall?.copyWith(fontFamily: AppTypography.mono, color: quiet),
              maxLines: 1,
            ),
          ],
        ),
      ),
    );
  }
}

/// The header of the demo grid: the column names, and the padlock beside the masked one.
class _GridHeader extends StatelessWidget {
  const _GridHeader({required this.lock});

  /// How far the padlock has appeared, 0 to 1.
  final double lock;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.labelMedium?.copyWith(
      fontFamily: AppTypography.mono,
      color: theme.colorScheme.onSurfaceVariant,
    );
    return ColoredBox(
      color: theme.colorScheme.surfaceContainerHigh,
      child: Padding(
        padding: _cellPadding,
        child: Row(
          children: [
            SizedBox(
              width: _idWidth,
              child: Text(_fields[0], style: style),
            ),
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Text(_fields[1], style: style, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                  Padding(
                    padding: const EdgeInsetsDirectional.only(start: AppSpacing.xs),
                    child: Opacity(
                      key: const ValueKey('ob2-mask-lock'),
                      opacity: lock,
                      child: Icon(
                        Icons.lock_outline,
                        size: MediaQuery.textScalerOf(context).scale(_lockSize),
                        color: theme.colorScheme.tertiary,
                        semanticLabel: S.of(context).result_masked_semantics,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: _totalWidth,
              child: Text(_fields[2], style: style, textAlign: TextAlign.end),
            ),
          ],
        ),
      ),
    );
  }
}

/// One row of the demo grid, in whichever form the timeline has reached: the clear values, or the masked ones.
class _GridRow extends StatelessWidget {
  const _GridRow({
    required this.clear,
    required this.masked,
    required this.maskedColumns,
    required this.blur,
    required this.isMasked,
  });

  final Map<String, Object?> clear;
  final Map<String, Object?> masked;
  final Set<String> maskedColumns;

  /// The blur the value closes over behind, in sigma.
  final double blur;

  /// Whether the mask has taken the clear value's place.
  final bool isMasked;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.bodySmall?.copyWith(fontFamily: AppTypography.mono);
    final maskedStyle = theme.textTheme.bodySmall?.copyWith(
      fontStyle: FontStyle.italic,
      color: theme.colorScheme.onSurfaceVariant,
    );

    Widget cell(String field, {TextAlign? align}) {
      final isHidden = isMasked && maskedColumns.contains(field);
      final value = isHidden ? masked[field] : clear[field];
      final text = Align(
        alignment: align == TextAlign.end ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
        child: CompactCell(cell: classifyCell(value), style: isHidden ? maskedStyle : style),
      );
      if (blur <= 0 || !maskedColumns.contains(field)) return text;
      return ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: text,
      );
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: AppSizes.minDenseTarget),
      child: Padding(
        padding: _cellPadding,
        child: Row(
          children: [
            SizedBox(width: _idWidth, child: cell(_fields[0])),
            Expanded(child: cell(_fields[1])),
            SizedBox(
              width: _totalWidth,
              child: cell(_fields[2], align: TextAlign.end),
            ),
          ],
        ),
      ),
    );
  }
}

const _cellPadding = EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.sm);
const _idWidth = AppSpacing.xxxxl;
const _totalWidth = AppSpacing.xxxxxl;
