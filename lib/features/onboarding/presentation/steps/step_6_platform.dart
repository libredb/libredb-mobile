import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/shared/design_system/components/app_card.dart';
import 'package:libredb_mobile/shared/design_system/components/app_status_badge.dart';
import 'package:libredb_mobile/shared/design_system/theme/semantic_colors.dart';
import 'package:libredb_mobile/shared/design_system/tokens/app_typography.dart';
import 'package:libredb_mobile/shared/design_system/tokens/tokens.dart';

/// The connection the whole introduction has been standing on.
const _connection = 'orders-prod';

/// The statement the person watched run on the third screen, as the Audit tab records it.
const _myStatement = 'select count(*) from orders';

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

/// How long before now the grant was made, and how long from now it runs out. Both are read off the clock rather
/// than written as dates, so the deck never shows a date in the past as a future expiry.
const _grantedAgo = Duration(days: 2);
const _expiresIn = Duration(days: 30);

/// How many lines the demonstration log holds.
const _events = 3;

/// When each beat of the sixth screen starts, measured from the frame the step is first shown on.
///
/// Every value is a sum of `AppDurations`, so the screen moves at the speeds the rest of the app moves at.
class Step6Beats {
  Step6Beats._();

  /// How long one row takes to arrive once its beat has come.
  static final Duration arrival = AppDurations.normal;

  /// Between the person's own grant and the one under it.
  static final Duration grantStagger = AppDurations.normal;

  /// The first line of the audit log is written in — the **oldest** one.
  static final Duration firstLine = AppDurations.media + AppDurations.normal;

  /// Between one line being written in and the next.
  static final Duration lineStagger = AppDurations.slow + AppDurations.instant;

  /// The note that says why one line has no statement.
  static final Duration note = firstLine + lineStagger * _events + AppDurations.normal;

  /// The whole timeline.
  static final Duration whole = note + AppDurations.media;
}

/// The sixth screen of the introduction: what Platform decided, and what it wrote down.
///
/// Two halves. Above, the grant that let the person read `orders-prod` — its level, when it runs out and **who
/// granted it and when**, in `platform_grants_granted_by`, the sentence the real grant list uses. Below, the audit
/// log, with the statement of the third screen at the top of it: the same `select count(*) from orders`, reading
/// the product's own relative time, its 41 ms and its one row. That line is the point of the whole deck — the thing
/// the person just did, in the record, named as theirs.
///
/// **The log reads newest first**, which is the order the real Audit tab lists in (`docs/platform.md`), and it
/// **writes itself in oldest first**, so each arriving line pushes the older ones down and the newest lands on
/// top. The two orders are opposites and both are deliberate: an audit caught the prototype this is built from
/// rendering `Just now → 21 min → 12 min`, the right rows in the wrong order.
///
/// Three rows, and the third is the one that earns the note under the card: a refused UPDATE whose statement the
/// connection's capture setting withheld, so the row carries `ob6_redacted` where the statement would be and the
/// note says why in the app's own `platform_audit_statement_redacted`. The outcome and the level are the app's
/// words throughout — `platform_audit_status_success`, `platform_audit_status_refused`,
/// `platform_grants_level_read`, `platform_grants_level_write` — because English literals in a Turkish deck are the
/// defect this screen is most likely to ship.
///
/// Two things the agreed prototype leaves out are left out here rather than invented: the colleague's line shows no
/// statement text, and the refused line shows no duration, because Platform refused it before the engine saw it.
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

/// How far a beat that started at [start] and lasts [span] has come at [elapsed], on the product's entrance curve.
double _phase(Duration elapsed, Duration start, Duration span) {
  final raw = (elapsed - start).inMicroseconds / span.inMicroseconds;
  return AppDurations.easeOut.transform(raw.clamp(0.0, 1.0));
}

/// A date and time in the language of the app, the way the grant list writes one.
String _grantDate(BuildContext context, DateTime value) =>
    DateFormat.yMMMd(Localizations.localeOf(context).toString()).add_Hm().format(value.toLocal());

class _Record extends StatelessWidget {
  const _Record({required this.elapsed});

  final Duration elapsed;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final now = clock.now();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Arriving(
          slotKey: const ValueKey('ob6-grant-0'),
          phase: _phase(elapsed, Duration.zero, Step6Beats.arrival),
          child: _Grant(
            holder: s.ob6_you,
            level: s.platform_grants_level_read,
            expiry: s.platform_grants_expires(_grantDate(context, now.add(_expiresIn))),
            granted: s.platform_grants_granted_by(_granter, _grantDate(context, now.subtract(_grantedAgo))),
            mine: true,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        _Arriving(
          slotKey: const ValueKey('ob6-grant-1'),
          phase: _phase(elapsed, Step6Beats.grantStagger, Step6Beats.arrival),
          child: _Grant(
            holder: _colleague,
            level: s.platform_grants_level_write,
            expiry: s.platform_grants_no_expiry,
            granted: s.platform_grants_granted_by(_granter, _grantDate(context, now.subtract(_grantedAgo))),
            mine: false,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        // Newest first, the order the Audit tab lists in. Each row is written in on its own beat, and the beats run
        // the other way — the oldest row first — so the line the person just ran lands on top of the others.
        for (var i = 0; i < _events; i++)
          _Arriving(
            slotKey: ValueKey('ob6-event-$i'),
            phase: _phase(
              elapsed,
              Step6Beats.firstLine + Step6Beats.lineStagger * (_events - 1 - i),
              Step6Beats.arrival,
            ),
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: _row(context, i),
            ),
          ),
        Opacity(
          opacity: _phase(elapsed, Step6Beats.note, AppDurations.media),
          child: Text(
            s.platform_audit_statement_redacted,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ),
      ],
    );
  }

  /// The log's rows, newest first.
  Widget _row(BuildContext context, int index) {
    final s = S.of(context);
    return switch (index) {
      0 => _Event(
        user: s.ob6_you,
        verb: _select,
        outcome: s.platform_audit_status_success,
        succeeded: true,
        details: [
          s.platform_audit_time_just_now,
          s.platform_audit_duration(_myDurationMs),
          s.platform_audit_row_count(_myRowCount),
        ],
        sql: _myStatement,
        redacted: false,
        mine: true,
      ),
      1 => _Event(
        user: _colleague,
        verb: _update,
        outcome: s.platform_audit_status_success,
        succeeded: true,
        details: [
          s.platform_audit_time_minutes_ago(_colleagueAge),
          s.platform_audit_duration(_colleagueDurationMs),
          s.platform_audit_row_count(_colleagueRowCount),
        ],
        sql: null,
        redacted: false,
        mine: false,
      ),
      _ => _Event(
        user: _other,
        verb: _update,
        outcome: s.platform_audit_status_refused,
        succeeded: false,
        details: [s.platform_audit_time_minutes_ago(_refusedAge)],
        sql: null,
        redacted: true,
        mine: false,
      ),
    };
  }
}

/// A row being written in: it unrolls from nothing and fades up as it does, so the rows below it are pushed down
/// rather than appearing already moved.
class _Arriving extends StatelessWidget {
  const _Arriving({required this.slotKey, required this.phase, required this.child});

  /// The key of the slot, whose height is how far the row has been written in.
  final Key slotKey;
  final double phase;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      key: slotKey,
      child: Align(
        alignment: Alignment.topCenter,
        heightFactor: phase,
        child: Opacity(opacity: phase, child: child),
      ),
    );
  }
}

/// One grant, drawn the way the real grant list draws one: the holder, the connection, the level and the expiry on
/// one line, and who granted it under them.
class _Grant extends StatelessWidget {
  const _Grant({
    required this.holder,
    required this.level,
    required this.expiry,
    required this.granted,
    required this.mine,
  });

  final String holder;
  final String level;
  final String expiry;
  final String granted;

  /// The reader's own grant, which the deck marks so they can find themselves in the list.
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final secondary = text.bodySmall?.copyWith(color: scheme.onSurfaceVariant);
    // The prototype sets the grant's own line in `font-family:mono;font-size:11px`, not in the title size the
    // headline uses; three title-sized lines is what made the card 86pt against its 48.
    final dense = text.labelLarge?.copyWith(fontFamily: AppTypography.mono);
    return AppCard(
      variant: mine ? AppCardVariant.filled : AppCardVariant.outlined,
      // One row, the way the prototype draws it — `.g{display:flex;align-items:center}`, the holder and what is
      // known about the grant in a column on the left and the level beside them on the right. Stacked instead,
      // the two grants and the three audit lines overflowed the hero by 257pt on the emulator and drew over the
      // headline and both controls.
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(holder, style: dense, maxLines: 1, overflow: TextOverflow.ellipsis),
                Text('$_connection  ·  $expiry', style: secondary, maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(granted, style: secondary, maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          AppStatusBadge(label: level, color: scheme.primary),
        ],
      ),
    );
  }
}

/// One line of the audit log, drawn the way the real Audit tab draws one: the user and the outcome, the connection
/// and the statement type, the relative time with the duration and the row count, and the statement — or, when the
/// connection's capture setting withheld it, the redaction in its place.
class _Event extends StatelessWidget {
  const _Event({
    required this.user,
    required this.verb,
    required this.outcome,
    required this.succeeded,
    required this.details,
    required this.sql,
    required this.redacted,
    required this.mine,
  });

  final String user;

  /// Platform's statement type, an opaque string: the verb of the statement, not a word of the app.
  final String verb;
  final String outcome;

  /// Which semantic colour the outcome badge takes. Refused is the warning colour, as `auditStatusColor` gives it:
  /// a refusal is governance working, not an error.
  final bool succeeded;
  final List<String> details;

  /// The statement text the row shows, null when the deck shows none for that line.
  final String? sql;
  final bool redacted;

  /// The reader's own line, which the deck marks so they can find what they just ran.
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final secondary = text.bodySmall?.copyWith(color: scheme.onSurfaceVariant);
    final sql = this.sql;
    // Same as the grant: the audit line's own name is mono and small in the prototype, not title-sized.
    final dense = text.labelLarge?.copyWith(fontFamily: AppTypography.mono);
    return AppCard(
      variant: mine ? AppCardVariant.filled : AppCardVariant.outlined,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(user, style: dense, overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(verb, style: text.labelMedium?.copyWith(color: scheme.onPrimaryContainer)),
              const SizedBox(width: AppSpacing.sm),
              AppStatusBadge(
                label: outcome,
                color: succeeded ? context.semanticColors.success : context.semanticColors.warning,
              ),
            ],
          ),
          Text([_connection, ...details].join('  ·  '), style: secondary, maxLines: 1, overflow: TextOverflow.ellipsis),
          if (sql != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              sql,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.bodySmall?.copyWith(fontFamily: AppTypography.mono),
            ),
          ] else if (redacted) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              s.ob6_redacted,
              style: text.bodySmall?.copyWith(fontFamily: AppTypography.mono, color: scheme.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}
