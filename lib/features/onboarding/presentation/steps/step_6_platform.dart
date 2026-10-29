import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:libredb_mobile/features/onboarding/presentation/pages/onboarding_page.dart';
import 'package:libredb_mobile/features/onboarding/presentation/widgets/onboarding_type.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/shared/design_system/theme/environment_colors.dart';
import 'package:libredb_mobile/shared/design_system/theme/semantic_colors.dart';
import 'package:libredb_mobile/shared/design_system/tokens/app_typography.dart';
import 'package:libredb_mobile/shared/design_system/tokens/tokens.dart';

/// The connection the whole introduction has been standing on.
const _connection = 'orders-prod';

/// The administrator who granted the read, and the colleague whose lines sit under the person's own.
const _granter = 'ayse';
const _colleague = 'mert';
const _other = 'onur';

/// Statement types, as Platform records them: opaque strings, not words of the app.
const _select = 'SELECT';
const _update = 'UPDATE';

/// How long ago the colleague's and the refused line were written, in minutes. The app's own relative time turns
/// them into "12 min ago" and "21 min ago", or their Turkish.
const _colleagueAge = 12;
const _refusedAge = 21;

/// How long the person's statement took and how many rows it answered with — the figures of the third screen.
const _myDurationMs = 41;
const _myRowCount = 1;

/// The colleague's successful UPDATE, in the same two figures.
const _colleagueDurationMs = 86;
const _colleagueRowCount = 3;

/// How long before now the grant was made. Read off the clock rather than written as a date, so the deck says "two
/// days ago" in whatever month it is shown.
const _grantedAgo = Duration(days: 2);

/// The colleague's grant never expires: the infinity sign the prototype writes, a symbol and not a word.
const _noExpiry = '∞';

/// How many lines the demonstration log holds.
const _events = 3;

/// When each beat of the sixth screen starts, measured from the frame the step is first shown on: the prototype's own
/// `PLAY[5]` schedule, in milliseconds.
class Step6Beats {
  Step6Beats._();

  /// How long one row takes to arrive once its beat has come: `.riser{animation:rise .42s}`.
  static const Duration arrival = Duration(milliseconds: 420);

  /// The person's own grant arrives with the card, and the one under it 220 later.
  static const Duration grantStagger = Duration(milliseconds: 220);

  /// The first line of the audit log is written in — the **oldest** one.
  static const Duration firstLine = Duration(milliseconds: 650);

  /// Between one line being written in and the next.
  static const Duration lineStagger = Duration(milliseconds: 430);

  /// The whole timeline, long enough for the last line's own arrival to finish inside it.
  static const Duration whole = Duration(milliseconds: 2000);
}

/// The sixth screen of the introduction: what Platform decided, and what it wrote down.
///
/// Two cards. Above, the grants: the one that let the person read `orders-prod` — who granted it and on which day —
/// and a colleague's write grant. Below, the audit log, with the statement of the third screen at the top of it: the
/// thing the person just did, in the record, named as theirs.
///
/// **The log reads newest first**, which is the order the real Audit tab lists in (`docs/platform.md`), and it
/// **writes itself in oldest first**, so each arriving line pushes the older ones down and the newest lands on top.
/// The two orders are opposites and both are deliberate: an audit caught the prototype this is built from rendering
/// `Just now → 21 min → 12 min`, the right rows in the wrong order.
///
/// The words are the app's own throughout — `platform_audit_status_success`, `platform_audit_status_refused`,
/// `platform_grants_level_read`, `platform_grants_level_write`, `platform_audit_statement_redacted` — because English
/// literals in a Turkish deck are the defect this screen is most likely to ship. The two lines whose statement the
/// connection's capture setting withheld say so in the line under them, as the prototype does.
///
/// **The drawing is the prototype's**, measured in headless Chrome at 390x844 and a device scale of 2 (`ob.html`,
/// screen 6): the grants one card of rows of `padding:9px 11px`, the log another 14 under it whose rows carry a
/// coloured bar down the leading edge, the time in a column of 74, and the outcome a square outlined tag at the end.
///
/// Nothing here is tappable. Next is the only control, and the chassis draws it.
class Step6Platform extends StatefulWidget {
  const Step6Platform({super.key});

  @override
  State<Step6Platform> createState() => _Step6PlatformState();
}

class _Step6PlatformState extends State<Step6Platform> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: Step6Beats.whole);

  /// The step plays once, as soon as it is shown, and then stops.
  bool _played = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      // Not a shorter animation: the finished, readable record, on the first frame.
      _controller
        ..stop()
        ..value = 1;
      _played = true;
    } else if (!_played) {
      _played = true;
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
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => _Record(elapsed: Step6Beats.whole * _controller.value),
    );
  }
}

/// The prototype's own measures of this hero, none of them on the closed spacing scale:
/// `.g{padding:9px 11px;gap:9px}`, `.lv{padding:3px 5px}`, `.ev{padding:8px 11px 8px 0;gap:8px}`, `.bar{width:3px}`,
/// `.ts{flex:0 0 74px}`, `.out{padding:2px 5px}`, the second card's `margin-top:14px` and the rows' `margin-top:2px`.
const double _cardGap = 14;
const double _grantPadX = 11;
const double _grantPadY = 9;
const double _grantGap = 9;
const double _eventPadY = 8;
const double _eventPadRight = 11;
const double _eventGap = 8;
const double _barWidth = 3;
const double _barCorner = 2;
const double _timeWidth = 74;
const double _lineGap = 2;
const double _levelPadX = 5;
const double _levelPadY = 3;
const double _outPadX = 5;
const double _outPadY = 2;
const double _tagRadius = 4;
const double _mineRadius = 11;
const double _arrivesFrom = 13;

/// The type: everything is mono 11, the time over a line of 1.35, the level tracked `.11em`, the outcome `.1em`, the
/// third line of a row at .85 of its ink.
const double _small = 11;
const double _timeLine = 1.35;
const double _levelTrackingEm = 0.11;
const double _outTrackingEm = 0.1;
const double _redactedOpacity = 0.85;

/// How much of a row the outcome tag may take before it is scaled down: at an accessibility text size the tag would
/// otherwise be wider than the row it ends.
const double _tagShare = 0.4;

/// The text scale above which a log row stacks its pieces: the ordinary text sizes go to 1.3.
const double _stackedAbove = 1.3;

/// How far a beat that started at [start] and lasts [span] has come at [elapsed], on the product's entrance curve.
double _phase(Duration elapsed, Duration start, Duration span) {
  final raw = (elapsed - start).inMicroseconds / span.inMicroseconds;
  return AppDurations.easeOut.transform(raw.clamp(0.0, 1.0));
}

class _Record extends StatelessWidget {
  const _Record({required this.elapsed});

  final Duration elapsed;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final locale = Localizations.localeOf(context);
    final now = clock.now();
    final granted = DateFormat('d MMM', locale.toString()).format(now.subtract(_grantedAgo));
    final grantedBy = s.platform_grants_granted_by(_granter, granted);
    final theme = Theme.of(context);
    final success = context.semanticColors.success;
    final error = theme.colorScheme.error;

    final events = [
      _EventData(
        time: s.platform_audit_time_just_now,
        user: s.ob6_you,
        verb: _select,
        facts: '${s.platform_audit_duration(_myDurationMs)} · ${s.platform_audit_row_count(_myRowCount)}',
        outcome: s.platform_audit_status_success,
        colour: success,
        redacted: s.platform_audit_statement_redacted,
        mine: true,
      ),
      _EventData(
        time: s.platform_audit_time_minutes_ago(_colleagueAge),
        user: _colleague,
        verb: _update,
        facts: '${s.platform_audit_duration(_colleagueDurationMs)} · ${s.platform_audit_row_count(_colleagueRowCount)}',
        outcome: s.platform_audit_status_success,
        colour: success,
      ),
      _EventData(
        time: s.platform_audit_time_minutes_ago(_refusedAge),
        user: _other,
        verb: _update,
        outcome: s.platform_audit_status_refused,
        colour: error,
        redacted: s.platform_audit_statement_redacted,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Card(
          key: const ValueKey('ob6-grants'),
          children: [
            _Slot(
              slotKey: const ValueKey('ob6-grant-0'),
              phase: _phase(elapsed, Duration.zero, Step6Beats.arrival),
              present: true,
              child: _Grant(
                boxKey: const ValueKey('ob6-grant-box-0'),
                levelKey: const ValueKey('ob6-level-0'),
                holder: s.ob6_you,
                when: '$_connection · $grantedBy',
                level: onboardingCapitals(s.platform_grants_level_read, locale),
                colour: theme.colorScheme.primary,
                ink: theme.colorScheme.onPrimaryContainer,
                mine: true,
                first: true,
              ),
            ),
            _Slot(
              slotKey: const ValueKey('ob6-grant-1'),
              phase: _phase(elapsed, Step6Beats.grantStagger, Step6Beats.arrival),
              present: elapsed >= Step6Beats.grantStagger,
              child: _Grant(
                boxKey: const ValueKey('ob6-grant-box-1'),
                levelKey: const ValueKey('ob6-level-1'),
                holder: _colleague,
                when: '$_connection · $_noExpiry',
                level: onboardingCapitals(s.platform_grants_level_write, locale),
                colour: EnvironmentColors.staging,
                ink: EnvironmentColors.staging,
                mine: false,
                first: false,
              ),
            ),
          ],
        ),
        const SizedBox(height: _cardGap),
        _Card(
          key: const ValueKey('ob6-log'),
          children: [
            // Newest first, the order the Audit tab lists in. Each row is written in on its own beat, and the beats run
            // the other way — the oldest row first — so the line the person just ran lands on top of the others.
            for (var i = 0; i < _events; i++)
              _Slot(
                slotKey: ValueKey('ob6-event-$i'),
                phase: _phase(
                  elapsed,
                  Step6Beats.firstLine + Step6Beats.lineStagger * (_events - 1 - i),
                  Step6Beats.arrival,
                ),
                present: elapsed >= Step6Beats.firstLine + Step6Beats.lineStagger * (_events - 1 - i),
                child: _Event(index: i, data: events[i]),
              ),
          ],
        ),
      ],
    );
  }
}

/// A card: the border and the corners a list of rows has in the app, with the rows cut to its own corners. The border
/// is outside the rows, which only a `Container` gives.
class _Card extends StatelessWidget {
  const _Card({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      borderRadius: BorderRadius.circular(AppRadius.xl),
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.xl),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
    ),
  );
}

/// A row being written in: absent until its beat, then there at its whole height — so the rows under it are pushed down
/// at once, as `insertBefore` does — rising into place as it fades in.
class _Slot extends StatelessWidget {
  const _Slot({required this.slotKey, required this.phase, required this.present, required this.child});

  final Key slotKey;
  final double phase;
  final bool present;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!present) return SizedBox.shrink(key: slotKey);
    return Opacity(
      key: slotKey,
      opacity: phase,
      child: Transform.translate(offset: Offset(0, (1 - phase) * _arrivesFrom), child: child),
    );
  }
}

TextStyle? _mono(BuildContext context, {FontWeight weight = FontWeight.w400, double? tracking, Color? color}) =>
    Theme.of(context).textTheme.labelSmall?.copyWith(
      fontFamily: AppTypography.mono,
      fontSize: _small,
      fontWeight: weight,
      height: onboardingMonoLine,
      letterSpacing: tracking ?? 0,
      color: color ?? Theme.of(context).colorScheme.onSurface,
    );

/// A square outlined tag: mono 11 bold in [colour], in a border of the same colour and a 4 radius.
class _Tag extends StatelessWidget {
  const _Tag({
    required this.boxKey,
    required this.label,
    required this.colour,
    required this.ink,
    required this.padX,
    required this.padY,
    required this.trackingEm,
  });

  final Key boxKey;
  final String label;

  /// The border, and [ink] the words: `.lv.read` is an accent border round words in the accent ink.
  final Color colour;
  final Color ink;
  final double padX;
  final double padY;
  final double trackingEm;

  @override
  Widget build(BuildContext context) => Container(
    key: boxKey,
    decoration: BoxDecoration(
      border: Border.all(color: colour),
      borderRadius: BorderRadius.circular(_tagRadius),
    ),
    padding: EdgeInsets.symmetric(horizontal: padX, vertical: padY),
    child: Text(
      label,
      style: _mono(context, weight: FontWeight.w700, tracking: _small * trackingEm, color: ink),
    ),
  );
}

/// [child] at its own size, or scaled down to [share] of the width it is given when it would not fit: a tag at an
/// accessibility text size is wider than the row it ends.
class _Capped extends StatelessWidget {
  const _Capped({required this.width, required this.child});

  final double width;
  final Widget child;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: BoxConstraints(maxWidth: width * _tagShare),
    child: FittedBox(fit: BoxFit.scaleDown, alignment: AlignmentDirectional.topEnd, child: child),
  );
}

/// One grant: the holder over `orders-prod` and what is known about the grant, and the level at the end.
///
/// `.g{display:flex;align-items:center;gap:9px;padding:9px 11px}`, the reader's own `.me` on the accent fill with an
/// 11 radius and the holder in the accent ink at 600. The first row has no rule over it and the others have one.
class _Grant extends StatelessWidget {
  const _Grant({
    required this.boxKey,
    required this.levelKey,
    required this.holder,
    required this.when,
    required this.level,
    required this.colour,
    required this.ink,
    required this.mine,
    required this.first,
  });

  final Key boxKey;
  final Key levelKey;
  final String holder;
  final String when;
  final String level;

  /// The tag's border, and [ink] its words.
  final Color colour;
  final Color ink;
  final bool mine;
  final bool first;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      key: boxKey,
      decoration: BoxDecoration(
        color: mine ? scheme.primaryContainer : null,
        borderRadius: mine ? BorderRadius.circular(_mineRadius) : null,
        border: !mine && !first ? Border(top: BorderSide(color: scheme.outlineVariant)) : null,
      ),
      padding: const EdgeInsets.symmetric(horizontal: _grantPadX, vertical: _grantPadY),
      child: LayoutBuilder(
        builder: (context, row) => Row(
          spacing: _grantGap,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    holder,
                    style: _mono(
                      context,
                      weight: mine ? FontWeight.w600 : FontWeight.w400,
                      color: mine ? scheme.onPrimaryContainer : null,
                    ),
                  ),
                  const SizedBox(height: _lineGap),
                  Text(when, style: _mono(context, color: scheme.onSurfaceVariant)),
                ],
              ),
            ),
            _Capped(
              width: row.maxWidth,
              child: _Tag(
                boxKey: levelKey,
                label: level,
                colour: colour,
                ink: ink,
                padX: _levelPadX,
                padY: _levelPadY,
                trackingEm: _levelTrackingEm,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// What one line of the log says.
class _EventData {
  const _EventData({
    required this.time,
    required this.user,
    required this.verb,
    required this.outcome,
    required this.colour,
    this.facts,
    this.redacted,
    this.mine = false,
  });

  final String time;
  final String user;

  /// Platform's statement type, an opaque string: the verb of the statement, not a word of the app.
  final String verb;

  /// The duration and the row count, null on a line Platform refused before the engine saw it.
  final String? facts;
  final String outcome;

  /// The bar's colour and the outcome tag's: the success ink, or the error ink for a refusal.
  final Color colour;

  /// The sentence that says the statement was withheld, null where the deck shows none.
  final String? redacted;

  /// The reader's own line, which the deck marks so they can find what they just ran.
  final bool mine;
}

/// One line of the audit log, drawn the way the prototype draws one: a bar down the leading edge in the outcome's
/// colour, the time in a column of 74, the user and the statement type over the connection and its figures and — where
/// the connection's capture setting withheld the statement — the redaction, and the outcome as a tag at the end.
class _Event extends StatelessWidget {
  const _Event({required this.index, required this.data});

  final int index;
  final _EventData data;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final facts = data.facts;
    final redacted = data.redacted;
    final quiet = _mono(context, color: scheme.onSurfaceVariant);
    return Container(
      key: ValueKey('ob6-event-box-$index'),
      decoration: BoxDecoration(
        color: data.mine ? scheme.primaryContainer : null,
        borderRadius: data.mine ? BorderRadius.circular(_mineRadius) : null,
        border: index > 0 ? Border(top: BorderSide(color: scheme.outlineVariant)) : null,
      ),
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: _eventPadY,
            bottom: _eventPadY,
            width: _barWidth,
            child: Container(
              key: ValueKey('ob6-bar-$index'),
              decoration: BoxDecoration(
                color: data.colour,
                borderRadius: const BorderRadius.horizontal(right: Radius.circular(_barCorner)),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(_barWidth + _eventGap, _eventPadY, _eventPadRight, _eventPadY),
            child: LayoutBuilder(
              builder: (context, row) {
                final time = Text(data.time, style: quiet?.copyWith(height: _timeLine));
                final who = Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: '${data.user} '),
                      TextSpan(
                        text: data.verb,
                        style: TextStyle(color: scheme.onPrimaryContainer, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  style: _mono(context),
                );
                final tag = _Capped(
                  width: row.maxWidth,
                  child: _Tag(
                    boxKey: ValueKey('ob6-out-$index'),
                    label: data.outcome,
                    colour: data.colour,
                    ink: data.colour,
                    padX: _outPadX,
                    padY: _outPadY,
                    trackingEm: _outTrackingEm,
                  ),
                );
                final details = [
                  Text(facts == null ? _connection : '$_connection · $facts', style: quiet),
                  if (redacted != null)
                    Opacity(
                      opacity: _redactedOpacity,
                      child: Text(redacted, style: quiet),
                    ),
                ];
                // The prototype's row: the time in a column of 74, the words in the room that is left and the tag at
                // the end. At an accessibility text size the 74 and the tag leave the words a sliver and the line
                // becomes a tower, so there the time goes on its own line over the words and the tag beside the
                // name — the same pieces, stacked, as the chassis does with its two controls.
                if (MediaQuery.textScalerOf(context).scale(1) > _stackedAbove) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: _lineGap,
                    children: [
                      time,
                      Row(
                        spacing: _eventGap,
                        children: [
                          Expanded(child: who),
                          tag,
                        ],
                      ),
                      ...details,
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: _eventGap,
                  children: [
                    SizedBox(key: ValueKey('ob6-time-$index'), width: _timeWidth, child: time),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: _lineGap,
                        children: [who, ...details],
                      ),
                    ),
                    tag,
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
