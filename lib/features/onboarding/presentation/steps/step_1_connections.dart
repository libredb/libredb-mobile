import 'package:flutter/material.dart';
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
  ),
  StudioConnection(
    id: 'demo-billing-stage',
    name: 'billing-stage',
    type: 'mysql',
    database: 'billing',
    environment: StudioEnvironment.staging,
    readOnly: true,
  ),
  StudioConnection(
    id: 'demo-lab',
    name: 'lab',
    type: 'postgres',
    database: 'dvdrental',
    environment: StudioEnvironment.development,
  ),
];

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
        DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: theme.colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(AppRadius.xl),
          ),
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
        const SizedBox(height: AppSpacing.sm),
        AnimatedBuilder(
          animation: _empty,
          builder: (context, _) => Opacity(
            key: const ValueKey('ob1-empty'),
            opacity: _empty.value,
            child: Text(
              l10n.ob1_empty(l10n.connection_list_empty_governed),
              style: theme.textTheme.labelSmall?.copyWith(
                fontFamily: AppTypography.mono,
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
    final badges = [
      if (EnvironmentBadge.showsFor(environment)) EnvironmentBadge(environment: environment!, color: connection.color),
      if (connection.readOnlyForUser) const ReadOnlyChip(),
    ];
    return Container(
      key: ValueKey('ob1-strip-$index'),
      constraints: const BoxConstraints(minHeight: AppSizes.minTapTarget),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: strip ?? Colors.transparent, width: 4)),
      ),
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.lg, AppSpacing.sm),
      child: Row(
        spacing: AppSpacing.md,
        children: [
          Icon(engineIcon(connection.type), semanticLabel: connection.type, color: theme.colorScheme.primary),
          // The prototype's row is `.crow{display:flex;align-items:center}`: the strip, the engine, the name over
          // the database, and then the badges on the *right*, on the same line. Stacked under the name instead,
          // the row is half again as tall and the badges read as a third line of the connection's name.
          // `Flexible`, not `Expanded`: a tight flex child takes every free pixel of the row, which left the badges
          // beside it nothing to be laid out in and scaled them down even at the ordinary text size. Loose, the two
          // share what the row has.
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(connection.name, style: theme.textTheme.bodyLarge, maxLines: 1, overflow: TextOverflow.ellipsis),
                if (secondary != null)
                  Text(
                    secondary,
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          // `Flexible`, because the badges sit beside the name rather than under it: without it the `Wrap` asks the
          // `Row` for its children's full width and the row overflows to the right at an accessibility text size,
          // which is the defect `scaleDown` below exists for. Bounded, the pills shrink into the slot they have.
          if (badges.isNotEmpty)
            Flexible(
              child: Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                crossAxisAlignment: WrapCrossAlignment.center,
                // A pill is laid out side by side and cannot wrap: `ReadOnlyChip` is a lock and 'Read only' in one
                // `Row`, so at an accessibility text size it asks for more width than the hero has and the row
                // overflows to the right — 169pt in Turkish at x3, measured. The hero scrolls vertically, so this is
                // the one axis nothing absorbs. `scaleDown` draws each pill at its own size whenever that fits, which
                // it does at every ordinary text size, and shrinks only the pill that would not.
                children: [for (final badge in badges) FittedBox(fit: BoxFit.scaleDown, child: badge)],
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
