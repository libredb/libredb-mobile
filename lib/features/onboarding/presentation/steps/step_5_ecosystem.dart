import 'package:flutter/material.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/shared/design_system/tokens/app_typography.dart';
import 'package:libredb_mobile/shared/design_system/tokens/tokens.dart';

/// The names of the three Studios the ecosystem is drawn with. Identifiers of a demonstration deployment, so they
/// read the same in every language and carry no ARB key.
const _studios = ['studio-eu', 'studio-us', 'studio-lab'];

/// What each Studio holds, under its name. Only the first is named, because it is the one the person has spent four
/// screens inside; the other two arrive quietly.
const _holdings = ['orders-prod', '…', '…'];

/// The databases under the Studios, in the same order.
const _databases = ['orders-prod', '…', '…'];

/// How many columns the three tiers are laid out in. The fan's rail and every connector is measured from it rather
/// than from a drawing, so a fourth Studio would move the geometry and not the code.
const _columns = 3;

/// When each beat of the fifth screen starts, measured from the frame the step is first shown on.
///
/// Every value is a sum of `AppDurations`, so the screen moves at the speeds the rest of the app moves at and a
/// change to the product's motion carries the deck with it. The order is the one claim this screen makes with its
/// drawing rather than its words — see [Step5Ecosystem].
class Step5Beats {
  Step5Beats._();

  /// How long one piece takes to arrive once its beat has come.
  static final Duration arrival = AppDurations.normal;

  /// Between one tier of the stack rising and the next.
  static final Duration tierStagger = AppDurations.instant;

  /// The legs from the databases up to the Studios.
  static final Duration legs = AppDurations.slow + AppDurations.normal;

  /// `orders-prod`, its leg and the Studio that holds it take the accent.
  static final Duration lit = legs + AppDurations.normal + AppDurations.fast;

  /// The branch: the rail the Studios hang under, and the stem up into Platform.
  static final Duration branch = lit + AppDurations.slow + AppDurations.normal;

  /// The twigs, from each Studio up to the rail.
  static final Duration twigs = branch + AppDurations.slow;

  /// The branch and `orders-prod`'s twig take the accent: the path the statement travelled.
  static final Duration hot = twigs + AppDurations.slow + AppDurations.fast;

  /// Platform's three role chips.
  static final Duration hub = hot + AppDurations.slow + AppDurations.normal;

  /// The mode switch, which is what the screen ends on.
  static final Duration modes = hub + AppDurations.media + AppDurations.slow;

  /// The whole timeline.
  static final Duration whole = modes + AppDurations.media;

  /// Between one role chip popping in and the next.
  static final Duration chipStagger = AppDurations.fast;

  /// Between one connector of a row being drawn and the next.
  static final Duration wireStagger = AppDurations.instant;
}

/// The fifth screen of the introduction: the ecosystem, and where the viewer stands in it.
///
/// Four tiers, bottom to top — the databases, three Studios, **LibreDB Platform** above them holding the
/// connections, the grants and the audit log, and **Keycloak**, the identity that knows the person once. The phone
/// is on the map too: a diagram of an ecosystem that does not show where its viewer stands is a vendor diagram.
///
/// **The connectors are drawn bottom-up, because that is the direction the headline claims.** "Studios connect to
/// Platform" is a direction, and every line here grows out of its lower end: the legs out of the databases into the
/// Studios, the twigs out of the Studios into the rail, the stem out of the rail into Platform. An audit caught the
/// prototype this is built from drawing them downward while the sparks ran up them, which is the same picture
/// saying two opposite things. The branch — rail and stem — is drawn before the twigs that hang from it.
///
/// **Only `orders-prod`'s path lights.** The person ran their statement on that one connection, through the Studio
/// that holds it; lighting all three would say the ecosystem routes everything everywhere.
///
/// It ends on the mode switch, with `profile_mode_platform` as its second pill and the note that it is the same
/// session and no second sign-in — and that the first switch takes an admin seat of the licence. Studio is the pill
/// that is on: Platform mode is for administrators, and an audit caught the prototype promising every new reader a
/// mode they may not be able to enter (`docs/platform.md`).
///
/// Nothing here is tappable. Next is the only control, and the chassis draws it.
class Step5Ecosystem extends StatefulWidget {
  const Step5Ecosystem({super.key});

  @override
  State<Step5Ecosystem> createState() => _Step5EcosystemState();
}

class _Step5EcosystemState extends State<Step5Ecosystem> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: Step5Beats.whole);

  /// The step plays once, as soon as it is shown, and then stops.
  bool _played = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      // Not a shorter animation: the finished, readable diagram, on the first frame.
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
      builder: (context, _) => _Ecosystem(elapsed: Step5Beats.whole * _controller.value),
    );
  }
}

/// How far a beat that started at [start] and lasts [span] has come at [elapsed], on the product's entrance curve.
double _phase(Duration elapsed, Duration start, Duration span) {
  final raw = (elapsed - start).inMicroseconds / span.inMicroseconds;
  return AppDurations.easeOut.transform(raw.clamp(0.0, 1.0));
}

/// The design system's hairline: the thickness its dividers paint with, so a connector is as thin as a divider and
/// not a number of its own.
double _hairline(BuildContext context) => DividerTheme.of(context).thickness ?? 1;

/// [quiet] until [phase] has run, [accent] once it has, and exactly [accent] at the end so the finished diagram
/// states its colour rather than approaching it.
Color _taking(Color quiet, Color accent, double phase) =>
    phase >= 1 ? accent : Color.lerp(quiet, accent, phase) ?? quiet;

class _Ecosystem extends StatelessWidget {
  const _Ecosystem({required this.elapsed});

  final Duration elapsed;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final mono = text.bodySmall?.copyWith(fontFamily: AppTypography.mono, color: scheme.onSurfaceVariant);
    final litPhase = _phase(elapsed, Step5Beats.lit, Step5Beats.arrival);
    final hotPhase = _phase(elapsed, Step5Beats.hot, Step5Beats.arrival);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Riser(
          phase: _phase(elapsed, Duration.zero, Step5Beats.arrival),
          child: _TierBox(
            lit: 0,
            child: Row(
              children: [
                Expanded(child: Text(s.ob5_keycloak, style: text.titleSmall)),
                Text(s.ob5_keycloak_note, style: mono),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        _Riser(
          phase: _phase(elapsed, Step5Beats.tierStagger, Step5Beats.arrival),
          child: _TierBox(
            lit: 1,
            child: Text(
              s.ob5_you,
              textAlign: TextAlign.center,
              style: text.titleSmall?.copyWith(color: scheme.onPrimaryContainer),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        _Riser(
          phase: _phase(elapsed, Step5Beats.tierStagger * 2, Step5Beats.arrival),
          child: _TierBox(
            lit: 1,
            child: Column(
              children: [
                Text(s.ob5_hub, style: text.titleSmall?.copyWith(color: scheme.onPrimaryContainer)),
                const SizedBox(height: AppSpacing.sm),
                _Roles(elapsed: elapsed),
              ],
            ),
          ),
        ),
        _Fan(elapsed: elapsed, hotPhase: hotPhase),
        Row(
          spacing: AppSpacing.sm,
          children: [
            for (var i = 0; i < _columns; i++)
              Expanded(
                child: _TierBox(
                  boxKey: ValueKey('ob5-studio-$i'),
                  lit: i == 0 ? litPhase : 0,
                  child: Column(
                    children: [
                      Text(_studios[i], style: text.labelLarge, textAlign: TextAlign.center),
                      Text(_holdings[i], style: mono, textAlign: TextAlign.center),
                    ],
                  ),
                ),
              ),
          ],
        ),
        _WireRow(
          keyPrefix: 'ob5-leg',
          height: AppSpacing.lg,
          start: Step5Beats.legs,
          hotPhase: litPhase,
          elapsed: elapsed,
        ),
        Row(
          spacing: AppSpacing.sm,
          children: [
            for (var i = 0; i < _columns; i++)
              Expanded(
                child: _Riser(
                  phase: _phase(elapsed, Step5Beats.wireStagger * i, Step5Beats.arrival),
                  child: _TierBox(
                    boxKey: ValueKey('ob5-database-$i'),
                    lit: i == 0 ? litPhase : 0,
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: AppSpacing.sm),
                    child: Text(_databases[i], style: mono, textAlign: TextAlign.center),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Opacity(
          key: const ValueKey('ob5-modes'),
          opacity: _phase(elapsed, Step5Beats.modes, AppDurations.media),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                spacing: AppSpacing.sm,
                children: [
                  Expanded(
                    child: _TierBox(
                      boxKey: const ValueKey('ob5-mode-studio'),
                      lit: 1,
                      pill: true,
                      child: Text(
                        s.profile_mode_studio,
                        textAlign: TextAlign.center,
                        style: text.labelLarge?.copyWith(color: scheme.onPrimaryContainer),
                      ),
                    ),
                  ),
                  Expanded(
                    child: _TierBox(
                      boxKey: const ValueKey('ob5-mode-platform'),
                      lit: 0,
                      pill: true,
                      child: Text(
                        s.profile_mode_platform,
                        textAlign: TextAlign.center,
                        style: text.labelLarge?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                s.ob5_mode_note,
                textAlign: TextAlign.center,
                style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A piece arriving: it fades in and settles the last few points upward, the way the rest of the app enters.
class _Riser extends StatelessWidget {
  const _Riser({required this.phase, required this.child});

  final double phase;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: phase,
      child: Transform.translate(offset: Offset(0, AppSpacing.sm * (1 - phase)), child: child),
    );
  }
}

/// One box of a tier. [lit] is how far it has taken the accent: 0 is a quiet member of the ecosystem, 1 is on the
/// path the person's statement travelled.
class _TierBox extends StatelessWidget {
  const _TierBox({required this.lit, required this.child, this.boxKey, this.padding, this.pill = false});

  final double lit;
  final Widget child;

  /// The key of the painted box itself, so a test reads the decoration it is asserting and nothing else.
  final Key? boxKey;
  final EdgeInsetsGeometry? padding;

  /// A mode pill, which is the one shape here that is not a card.
  final bool pill;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      key: boxKey,
      padding: padding ?? const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: _taking(scheme.surface, scheme.primaryContainer, lit),
        borderRadius: BorderRadius.circular(pill ? AppRadius.pill : AppRadius.lg),
        border: Border.all(color: _taking(scheme.outline, scheme.primary, lit)),
      ),
      child: child,
    );
  }
}

/// The three things Platform holds, popping in one after another once the branch has reached it.
class _Roles extends StatelessWidget {
  const _Roles({required this.elapsed});

  final Duration elapsed;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    // Rendered in the case the ARB writes them: Dart's toUpperCase has no Turkish locale and would print YETKILER.
    final roles = [s.ob5_role_connections, s.ob5_role_grants, s.ob5_role_audit];
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      alignment: WrapAlignment.center,
      children: [
        for (var i = 0; i < roles.length; i++)
          _Popping(
            phase: _phase(elapsed, Step5Beats.hub + Step5Beats.chipStagger * i, Step5Beats.arrival),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: Border.all(color: scheme.primary),
              ),
              child: Text(roles[i], style: text.labelSmall?.copyWith(color: scheme.onPrimaryContainer)),
            ),
          ),
      ],
    );
  }
}

/// A chip arriving: it grows from nothing to its size on the entrance curve, which reads as a pop without a curve
/// that overshoots — `AppDurations` has none, on purpose.
class _Popping extends StatelessWidget {
  const _Popping({required this.phase, required this.child});

  final double phase;
  final Widget child;

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: phase,
    child: Transform.scale(scale: phase, child: child),
  );
}

/// A vertical connector, drawn out of its **lower** end: the direction the current flows and the headline claims.
class _Wire extends StatelessWidget {
  const _Wire({required this.height, required this.phase, required this.hotPhase, this.lineKey});

  final double height;
  final double phase;

  /// The key of the drawn line, whose height is how far it has been drawn.
  final Key? lineKey;

  /// How far this connector has taken the accent, once the path it belongs to is the lit one.
  final double hotPhase;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: height,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          key: lineKey,
          width: _hairline(context),
          height: height * phase,
          color: _taking(scheme.outline, scheme.primary, hotPhase),
        ),
      ),
    );
  }
}

/// One row of connectors, one under the centre of each column, drawn left to right.
class _WireRow extends StatelessWidget {
  const _WireRow({
    required this.keyPrefix,
    required this.height,
    required this.start,
    required this.hotPhase,
    required this.elapsed,
  });

  final String keyPrefix;
  final double height;
  final Duration start;

  /// Applied to the first connector only: the path that lit is `orders-prod`'s.
  final double hotPhase;
  final Duration elapsed;

  @override
  Widget build(BuildContext context) {
    return Row(
      spacing: AppSpacing.sm,
      children: [
        for (var i = 0; i < _columns; i++)
          Expanded(
            child: _Wire(
              lineKey: ValueKey('$keyPrefix-$i'),
              height: height,
              phase: _phase(elapsed, start + Step5Beats.wireStagger * i, Step5Beats.arrival),
              hotPhase: i == 0 ? hotPhase : 0,
            ),
          ),
      ],
    );
  }
}

/// The branch and its twigs: the rail the three Studios hang under, the stem up into Platform, and one twig out of
/// each Studio. The branch is drawn first; the twigs hang from it afterwards.
class _Fan extends StatelessWidget {
  const _Fan({required this.elapsed, required this.hotPhase});

  final Duration elapsed;

  /// How far the branch has taken the accent.
  final double hotPhase;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const stemHeight = AppSpacing.md;
    const twigHeight = AppSpacing.xl;
    final railPhase = _phase(elapsed, Step5Beats.branch, Step5Beats.arrival);
    // The box sits outside the `LayoutBuilder`, not inside it. The chassis measures the hero with an
    // `IntrinsicHeight` so it can absorb the page's slack, a `LayoutBuilder` answers no intrinsic question, and a
    // tight height short-circuits the question before it ever reaches one. The drawing is unchanged: the builder
    // still gets the full width, and this subtree was already exactly this tall.
    return SizedBox(
      height: stemHeight + twigHeight,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // The rail runs from the centre of the first column to the centre of the last, so it meets every twig
          // and overhangs none of them.
          final cell = (constraints.maxWidth - AppSpacing.sm * (_columns - 1)) / _columns;
          final railWidth = (cell + AppSpacing.sm) * (_columns - 1);
          return Stack(
            children: [
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: stemHeight,
                child: _Wire(
                  lineKey: const ValueKey('ob5-stem'),
                  height: stemHeight,
                  phase: railPhase,
                  hotPhase: hotPhase,
                ),
              ),
              Positioned(
                top: stemHeight,
                left: 0,
                right: 0,
                child: Align(
                  child: Container(
                    key: const ValueKey('ob5-rail'),
                    width: railWidth * railPhase,
                    height: _hairline(context),
                    color: _taking(scheme.outline, scheme.primary, hotPhase),
                  ),
                ),
              ),
              Positioned(
                top: stemHeight,
                left: 0,
                right: 0,
                height: twigHeight,
                child: _WireRow(
                  keyPrefix: 'ob5-twig',
                  height: twigHeight,
                  start: Step5Beats.twigs,
                  hotPhase: hotPhase,
                  elapsed: elapsed,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
