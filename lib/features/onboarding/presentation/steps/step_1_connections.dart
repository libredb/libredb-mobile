import 'package:flutter/material.dart';
import 'package:libredb_mobile/features/onboarding/presentation/widgets/engine_mark.dart';
import 'package:libredb_mobile/features/onboarding/presentation/widgets/onboarding_marks.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/shared/design_system/theme/environment_colors.dart';
import 'package:libredb_mobile/shared/design_system/tokens/app_typography.dart';
import 'package:libredb_mobile/shared/design_system/tokens/tokens.dart';
import 'package:libredb_mobile/shared/models/studio_connection.dart';
import 'package:libredb_mobile/shared/models/studio_environment.dart';
import 'package:libredb_mobile/shared/widgets/connection_badges.dart';

/// The hero of the first screen of the introduction: the connection list assembling itself.
///
/// Three rows arrive one after another, the production row is then ringed, and the sentence the real list shows when
/// nothing has been granted fades in under them — a first run may have no connections at all, and the app ships that
/// sentence.
///
/// The rows are the real list's rows: `EnvironmentAccent` decides the strip and the badge ink, so the strip appears
/// only on production and PROD is filled rather than outlined, and `EnvironmentBadge` and [ReadOnlyChip] are the ones
/// `ConnectionRow` itself draws. Nothing here is tappable: Next is the introduction's only control, so the row is a
/// plain `Container` where the real one is an `InkWell`.
///
/// It plays once, as soon as it is shown. With `MediaQuery.disableAnimationsOf` on it is finished on its first frame.
class Step1Connections extends StatefulWidget {
  const Step1Connections({super.key});

  @override
  State<Step1Connections> createState() => _Step1ConnectionsState();
}

/// The whole timeline, so every beat below is a fraction of one controller.
const _total = Duration(milliseconds: 1400);

/// One row's entrance, and the gap between two entrances. The gap is what makes the list assemble rather than appear.
const _rise = AppDurations.media;
const _stagger = Duration(milliseconds: 110);

/// How far a row rises into place.
const _riseFrom = AppSpacing.md;

/// The ring that lights the production row once the list is there, and how far past the row it travels.
const _ringAt = Duration(milliseconds: 700);
const _ringFor = Duration(milliseconds: 700);
const _ringOpacity = 0.85;
const _ringGrowth = 0.13;
const _ringWidth = 1.5;

/// The empty-list sentence, last.
const _emptyAt = Duration(milliseconds: 900);
const _emptyFor = AppDurations.media;

/// The three connections the screen shows. They are the demo of a list, never read from Studio, so they carry no
/// credential and no real id.
const _connections = [
  StudioConnection(
    id: 'demo-orders-prod',
    name: 'orders-prod',
    type: 'postgres',
    database: 'orders',
    environment: StudioEnvironment.production,
    // The design puts both flags on this row — `[PG,'orders-prod','orders','PROD',var(--prod),1,1]`, the strip and
    // the read-only mark — and none on the staging one. The other way round, the screen says the staging database
    // is the locked one and production is not, which is the opposite of the sentence under it.
    readOnly: true,
  ),
  StudioConnection(
    id: 'demo-billing-stage',
    name: 'billing-stage',
    type: 'mysql',
    database: 'billing',
    environment: StudioEnvironment.staging,
  ),
  StudioConnection(
    id: 'demo-lab',
    name: 'lab',
    type: 'postgres',
    database: 'dvdrental',
    environment: StudioEnvironment.development,
  ),
];

/// The row's own measures, each the prototype's rule as measured in headless Chrome at 390x844 (Turkish and English,
/// light and dark alike). None is on the closed spacing scale and all are this row's own.
///
/// `.crow{display:flex;align-items:center;gap:10px;padding:11px 11px 11px 0}`, `.strip{width:4px;height:30px;
/// border-radius:0 2px 2px 0}`, `.eng{width:17px;height:17px}`, `.nm{font-size:12.5px;font-weight:600;
/// letter-spacing:-.01em}` over a 16 line, `.sb{font-family:var(--mono);font-size:11px;margin-top:2px}` over a 14 line.
const double _markGap = 10;
const double _rowInset = 11;
const double _stripWidth = 4;
const double _stripHeight = 30;
const double _stripCorner = 2;
const double _engineSize = 17;
const double _nameSize = 12.5;
const double _nameLine = 16 / _nameSize;
const double _nameTracking = -0.01 * _nameSize;
const double _subSize = 11;
const double _subLine = 14 / _subSize;
const double _subGap = 2;

/// `.empt{font-family:var(--mono);font-size:11px;margin-top:9px;line-height:1.5}`.
const double _emptyGap = 9;
const double _emptyLine = 1.5;

/// The row the ring lights: the production one.
const _litRow = 0;

class _Step1ConnectionsState extends State<Step1Connections> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: _total);

  late final List<Animation<double>> _rows = [for (var i = 0; i < _connections.length; i++) _beat(_stagger * i, _rise)];
  late final Animation<double> _ring = _beat(_ringAt, _ringFor);
  late final Animation<double> _empty = _beat(_emptyAt, _emptyFor);

  /// [length] of the timeline from [begin], on the design system's entrance curve.
  Animation<double> _beat(Duration begin, Duration length) => CurvedAnimation(
    parent: _controller,
    curve: Interval(
      begin.inMilliseconds / _total.inMilliseconds,
      (begin + length).inMilliseconds / _total.inMilliseconds,
      curve: AppDurations.easeOut,
    ),
  );

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

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context);
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // A `Container`, not a `DecoratedBox`: CSS draws the 1px border outside the rows, which only the `Container`
        // gives (a `DecoratedBox` paints it over the first row's top and the last row's bottom, 2 short of 166).
        Container(
          key: const ValueKey('ob1-card'),
          decoration: BoxDecoration(
            border: Border.all(color: theme.colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(AppRadius.xl),
          ),
          // `overflow:hidden`, which the prototype's `.card` carries. Without it a row's environment strip is
          // painted at the row's own left edge while the card's corner curves away from it, so the first row's
          // strip stood outside the rounded rectangle as a straight bar with a gap behind it.
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final (index, connection) in _connections.indexed) ...[
                  if (index > 0) const Divider(height: 1, thickness: 1),
                  AnimatedBuilder(
                    animation: Listenable.merge([_rows[index], _ring]),
                    builder: (context, _) {
                      final arrived = _rows[index].value;
                      return Opacity(
                        key: ValueKey('ob1-row-$index'),
                        opacity: arrived,
                        child: Transform.translate(
                          offset: Offset(0, (1 - arrived) * _riseFrom),
                          child: index == _litRow
                              ? _Ringed(
                                  progress: _ring.value,
                                  child: _DemoConnectionRow(index: index, connection: connection),
                                )
                              : _DemoConnectionRow(index: index, connection: connection),
                        ),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: _emptyGap),
        AnimatedBuilder(
          animation: _empty,
          builder: (context, _) => Opacity(
            key: const ValueKey('ob1-empty'),
            opacity: _empty.value,
            child: Text(
              l10n.ob1_empty(l10n.connection_list_empty_governed),
              style: theme.textTheme.labelSmall?.copyWith(
                fontFamily: AppTypography.mono,
                fontSize: _subSize,
                height: _emptyLine,
                letterSpacing: 0,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// One demo connection, drawn the way `ConnectionRow` draws a real one, without its gestures.
class _DemoConnectionRow extends StatelessWidget {
  const _DemoConnectionRow({required this.index, required this.connection});

  /// The row's place in the list, which names its strip so a test can read it.
  final int index;

  final StudioConnection connection;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final environment = connection.environment;
    final strip = EnvironmentAccent.resolve(
      environment: environment,
      color: connection.color,
      scheme: theme.colorScheme,
    ).strip;
    final secondary = connection.database ?? connection.host;
    // The pill first and the badge last, as the prototype's row writes them.
    final badges = [
      if (connection.readOnlyForUser) const OnboardingReadOnlyPill(),
      if (EnvironmentBadge.showsFor(environment)) OnboardingBadge(environment: environment!, color: connection.color),
    ];
    final nameBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          connection.name,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontSize: _nameSize,
            height: _nameLine,
            fontWeight: FontWeight.w600,
            letterSpacing: _nameTracking,
            color: theme.colorScheme.onSurface,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (secondary != null) ...[
          const SizedBox(height: _subGap),
          Text(
            secondary,
            style: theme.textTheme.labelSmall?.copyWith(
              fontFamily: AppTypography.mono,
              fontSize: _subSize,
              height: _subLine,
              letterSpacing: 0,
              fontWeight: FontWeight.w400,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
    return Container(
      key: ValueKey('ob1-line-$index'),
      padding: const EdgeInsets.fromLTRB(0, _rowInset, _rowInset, _rowInset),
      child: Row(
        spacing: _markGap,
        children: [
          // The environment strip is a short bar at the row's left edge, not the row's height: `.strip` is 4 x 30 in a
          // 54 row, rounded on its right corners only. A row without one keeps the 4 so the marks line up.
          if (strip != null)
            Container(
              key: ValueKey('ob1-strip-$index'),
              width: _stripWidth,
              height: _stripHeight,
              decoration: BoxDecoration(
                color: strip,
                borderRadius: const BorderRadius.horizontal(right: Radius.circular(_stripCorner)),
              ),
            )
          else
            const SizedBox(width: _stripWidth),
          // The engine's own mark, named for a test and read aloud as the engine's type. The `Semantics` is outside
          // the key so what the key addresses is the mark alone: two rows of the same engine draw the same thing,
          // and a test that compared the labelled widget would pass on the label and never see the glyph.
          Semantics(
            label: connection.type,
            child: KeyedSubtree(
              key: ValueKey('ob1-engine-$index'),
              child: EngineMarkIcon(type: connection.type, color: theme.colorScheme.primary, size: _engineSize),
            ),
          ),
          // The name over the database on the left, the pill and the badge on the right of the same line. A `Wrap` is
          // the arrangement that keeps both promises: the marks take the right end of the name's line while the two
          // fit together, and the whole group moves to a line of its own — the old stacked form — only at the text
          // size where they cannot, rather than being squeezed or clipped.
          Expanded(
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: _markGap,
              runSpacing: AppSpacing.xs,
              children: [
                nameBlock,
                if (badges.isNotEmpty)
                  // A pill is laid out side by side and cannot wrap: at an accessibility text size it asks for more
                  // width than the hero has and the row overflows to the right. The hero scrolls vertically, so this
                  // is the one axis nothing absorbs.
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(mainAxisSize: MainAxisSize.min, spacing: _markGap, children: badges),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A ring that travels outwards from [child] and fades, once, as [progress] runs 0 to 1: the list has assembled and
/// this is the connection the next screen opens.
class _Ringed extends StatelessWidget {
  const _Ringed({required this.progress, required this.child});

  final double progress;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (progress == 0 || progress == 1) return child;
    return Stack(
      children: [
        child,
        Positioned.fill(
          child: IgnorePointer(
            child: Opacity(
              opacity: _ringOpacity * (1 - progress),
              child: Transform.scale(
                scale: 1 + _ringGrowth * progress,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: Theme.of(context).colorScheme.primary, width: _ringWidth),
                    borderRadius: BorderRadius.circular(AppRadius.xl),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
