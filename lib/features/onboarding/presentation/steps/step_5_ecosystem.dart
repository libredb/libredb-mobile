import 'package:flutter/material.dart';
import 'package:libredb_mobile/features/onboarding/presentation/pages/onboarding_page.dart';
import 'package:libredb_mobile/features/onboarding/presentation/widgets/onboarding_type.dart';
import 'package:libredb_mobile/features/onboarding/presentation/widgets/ring_decoration.dart';
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

/// When each beat of the fifth screen starts, measured from the frame the step is first shown on: the prototype's own
/// `PLAY[4]` schedule, in milliseconds.
///
/// The order is the one claim this screen makes with its drawing rather than its words — see [Step5Ecosystem].
class Step5Beats {
  Step5Beats._();

  /// How long a connector takes to grow once its beat has come, and how long a piece takes to arrive: `--d-med`.
  static const Duration arrival = Duration(milliseconds: 240);

  /// How long the rail takes, which is longer than the lines it joins: `transition:transform var(--d-slower)`.
  static const Duration railGrows = Duration(milliseconds: 400);

  /// Between one tier of the stack rising and the next: `animation-delay:90ms`.
  static const Duration tierStagger = Duration(milliseconds: 90);

  /// The legs from the databases up to the Studios.
  static const Duration legs = Duration(milliseconds: 600);

  /// `orders-prod`, its leg and the Studio that holds it take the accent.
  static const Duration lit = Duration(milliseconds: 1100);

  /// The branch: the rail the Studios hang under, and the stem up into Platform.
  static const Duration branch = Duration(milliseconds: 1600);

  /// The twigs, from each Studio up to the rail.
  static const Duration twigs = Duration(milliseconds: 1950);

  /// The branch and `orders-prod`'s twig take the accent: the path the statement travelled.
  static const Duration hot = Duration(milliseconds: 2500);

  /// Platform pops and rings, and its three role chips follow.
  static const Duration hub = Duration(milliseconds: 3100);

  /// The mode switch, which is what the screen ends on.
  static const Duration modes = Duration(milliseconds: 4100);

  /// The whole timeline, long enough for the mode switch's own fade to finish inside it.
  static const Duration whole = Duration(milliseconds: 4500);

  /// Between one role chip popping in and the next, and how long after the hub pops the first one does.
  static const Duration chipStagger = Duration(milliseconds: 150);
  static const Duration chipsAfter = Duration(milliseconds: 200);

  /// Between one connector of a row being drawn and the next: the legs 110 apart, the twigs 150.
  static const Duration wireStagger = Duration(milliseconds: 110);
  static const Duration twigStagger = Duration(milliseconds: 150);

  /// A pop and a ring: `pop var(--d-slower)`, `ringOut .7s`.
  static const Duration pop = Duration(milliseconds: 400);
  static const Duration ring = Duration(milliseconds: 700);
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
/// **The drawing is the prototype's**, measured in headless Chrome at 390x844 and a device scale of 2 (`ob.html`,
/// screen 5): Keycloak 45 high with its name over its note, the phone 31.5, Platform 68, a fan of 34, Studios of 46.5
/// in three columns with a 6 gap, legs of 15, databases of 26.5, the mode pills 28.
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

/// The same, without the easing.
double _linear(Duration elapsed, Duration start, Duration span) {
  final raw = (elapsed - start).inMicroseconds / span.inMicroseconds;
  return raw.clamp(0.0, 1.0);
}

/// [quiet] until [phase] has run, [accent] once it has, and exactly [accent] at the end so the finished diagram
/// states its colour rather than approaching it.
Color _taking(Color quiet, Color accent, double phase) =>
    phase >= 1 ? accent : Color.lerp(quiet, accent, phase) ?? quiet;

/// The prototype's own measures of this hero, none of them on the closed spacing scale:
/// `.kc{padding:7px 11px;border-radius:8px}`, `.you{border:1.5px;padding:7px 11px}`, `.hub{border:1.5px;
/// padding:10px 12px;border-radius:11px}`, `.hub .roles{gap:4px;margin-top:7px}`, `.hub .role{padding:2.5px 6px}`,
/// `.fan{height:34px}` with a stem of 13 and drops of 21, `.st{padding:7px 4px}`, `.legs{height:15px}`,
/// `.db{padding:5px 2px;border-radius:6px}`, `.modes{margin-top:9px}`, `.mode{padding:6px}` and the note's 5.
const double _gapTier = 7;
const double _gapColumns = 6;
const double _padX = 11;
const double _padY = 7;
const double _hubPadX = 12;
const double _hubPadY = 10;
const double _hubRadius = 11;
const double _accentBorder = 1.5;
const double _chipGap = 4;
const double _chipPadX = 6;
const double _chipPadY = 2.5;
const double _stemHeight = 13;
const double _dropHeight = 21;
const double _legHeight = 15;
const double _studioPadX = 4;
const double _databasePadX = 2;
const double _modesGap = 9;
const double _noteGap = 5;
const double _popScale = 1.05;
const double _chipFrom = 0.7;

/// The type: the identity's name 11.5 semibold, the phone 11.5 bold, Platform 13 bold, everything else 11, the roles
/// tracked `.07em`.
const double _kcSize = 11.5;
const double _hubSize = 13;
const double _small = 11;
const double _roleTrackingEm = 0.07;
const double _noteLine = 1.5;

/// How much a role chip overshoots as it pops in: `cubic-bezier(.2,1.6,.4,1)`.
const Curve _chipCurve = Cubic(0.2, 1.6, 0.4, 1);

class _Ecosystem extends StatelessWidget {
  const _Ecosystem({required this.elapsed});

  final Duration elapsed;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final locale = Localizations.localeOf(context);
    TextStyle? sans(double size, FontWeight weight, Color color) => theme.textTheme.bodySmall?.copyWith(
      fontSize: size,
      fontWeight: weight,
      height: onboardingSansLine,
      letterSpacing: 0,
      color: color,
    );
    final mono = theme.textTheme.labelSmall?.copyWith(
      fontFamily: AppTypography.mono,
      fontSize: _small,
      fontWeight: FontWeight.w400,
      height: onboardingMonoLine,
      letterSpacing: 0,
      color: scheme.onSurfaceVariant,
    );
    final litPhase = _phase(elapsed, Step5Beats.lit, Step5Beats.arrival);
    final hotPhase = _phase(elapsed, Step5Beats.hot, Step5Beats.arrival);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Riser(
          phase: _phase(elapsed, Duration.zero, Step5Beats.arrival),
          child: Container(
            key: const ValueKey('ob5-kc'),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              border: Border.all(color: scheme.outline),
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            padding: const EdgeInsets.symmetric(horizontal: _padX, vertical: _padY),
            // The name over its note, both on the leading edge, as `.kc` stacks them. It used to be a name at one edge
            // and a note at the other, which needed a render object of its own to survive an accessibility text size.
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.ob5_keycloak, style: sans(_kcSize, FontWeight.w600, scheme.onSurface)),
                Text(s.ob5_keycloak_note, style: mono),
              ],
            ),
          ),
        ),
        const SizedBox(height: _gapTier),
        _Riser(
          phase: _phase(elapsed, Step5Beats.tierStagger, Step5Beats.arrival),
          child: Container(
            key: const ValueKey('ob5-you'),
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              border: Border.all(color: scheme.primary, width: _accentBorder),
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            padding: const EdgeInsets.symmetric(horizontal: _padX, vertical: _padY),
            child: Text(
              s.ob5_you,
              textAlign: TextAlign.center,
              style: sans(_kcSize, FontWeight.w700, scheme.onPrimaryContainer),
            ),
          ),
        ),
        const SizedBox(height: _gapTier),
        _Riser(
          phase: _phase(elapsed, Step5Beats.tierStagger * 2, Step5Beats.arrival),
          child: _Hub(elapsed: elapsed, sans: sans, locale: locale),
        ),
        _Fan(elapsed: elapsed, hotPhase: hotPhase),
        Row(
          spacing: _gapColumns,
          children: [
            for (var i = 0; i < _columns; i++)
              Expanded(
                child: _Popping(
                  phase: i == 0 ? _linear(elapsed, Step5Beats.lit, Step5Beats.pop) : 0,
                  child: Container(
                    key: ValueKey('ob5-studio-$i'),
                    decoration: BoxDecoration(
                      color: scheme.surface,
                      border: Border.all(color: _taking(scheme.outline, scheme.primary, i == 0 ? litPhase : 0)),
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: _studioPadX, vertical: _padY),
                    child: Column(
                      children: [
                        Text(
                          _studios[i],
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: sans(
                            _small,
                            FontWeight.w600,
                            _taking(scheme.onSurface, scheme.onPrimaryContainer, i == 0 ? litPhase : 0),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs / 2),
                        Text(
                          _holdings[i],
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: mono,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
        _Legs(elapsed: elapsed, litPhase: litPhase),
        Row(
          spacing: _gapColumns,
          children: [
            for (var i = 0; i < _columns; i++)
              Expanded(
                child: _Riser(
                  phase: _phase(elapsed, Step5Beats.wireStagger * i, Step5Beats.arrival),
                  child: Container(
                    key: ValueKey('ob5-database-$i'),
                    decoration: BoxDecoration(
                      border: Border.all(color: _taking(scheme.outline, scheme.primary, i == 0 ? litPhase : 0)),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: _databasePadX, vertical: AppSpacing.xs + 1),
                    child: Text(
                      _databases[i],
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: mono?.copyWith(
                        color: _taking(scheme.onSurfaceVariant, scheme.onPrimaryContainer, i == 0 ? litPhase : 0),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        Opacity(
          key: const ValueKey('ob5-modes'),
          opacity: _phase(elapsed, Step5Beats.modes, AppDurations.media),
          child: Padding(
            padding: const EdgeInsets.only(top: _modesGap),
            child: Row(
              spacing: _gapColumns,
              children: [
                Expanded(
                  child: _Mode(boxKey: const ValueKey('ob5-mode-studio'), label: s.profile_mode_studio, on: true),
                ),
                Expanded(
                  child: _Mode(boxKey: const ValueKey('ob5-mode-platform'), label: s.profile_mode_platform, on: false),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: _noteGap),
        Text(
          s.ob5_mode_note,
          key: const ValueKey('ob5-note'),
          textAlign: TextAlign.center,
          style: mono?.copyWith(height: _noteLine),
        ),
      ],
    );
  }
}

/// A piece that comes in from below as it arrives, `riser`: up into place as it fades in.
class _Riser extends StatelessWidget {
  const _Riser({required this.phase, required this.child});

  final double phase;
  final Widget child;

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: phase,
    child: Transform.translate(offset: Offset(0, (1 - phase) * _arrivesFrom), child: child),
  );
}

/// How far a piece rises into place: `@keyframes rise{from{transform:translateY(13px)}}`.
const double _arrivesFrom = 13;

/// A piece that pops once as [phase] runs 0 to 1: up to [_popScale] by 38% of the beat and back to rest by its end.
class _Popping extends StatelessWidget {
  const _Popping({required this.phase, required this.child});

  final double phase;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final lift = phase <= 0 || phase >= 1
        ? 0.0
        : phase < 0.38
        ? Curves.easeOutCubic.transform(phase / 0.38)
        : 1 - Curves.easeOutCubic.transform((phase - 0.38) / 0.62);
    return Transform.scale(scale: 1 + (_popScale - 1) * lift, child: child);
  }
}

/// Platform: the accent box with its name and its three role chips, which pops and rings when its beat comes.
class _Hub extends StatelessWidget {
  const _Hub({required this.elapsed, required this.sans, required this.locale});

  final Duration elapsed;
  final TextStyle? Function(double size, FontWeight weight, Color color) sans;
  final Locale locale;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ring = _linear(elapsed, Step5Beats.hub, Step5Beats.ring);
    final roles = [s.ob5_role_connections, s.ob5_role_grants, s.ob5_role_audit];
    return _Popping(
      phase: _linear(elapsed, Step5Beats.hub, Step5Beats.pop),
      child: Container(
        key: const ValueKey('ob5-hub'),
        decoration: BoxDecoration(
          color: scheme.primaryContainer,
          border: Border.all(color: scheme.primary, width: _accentBorder),
          borderRadius: BorderRadius.circular(_hubRadius),
        ),
        foregroundDecoration: ring > 0 && ring < 1
            ? RingDecoration(color: scheme.primary, progress: ring, radius: _hubRadius)
            : null,
        padding: const EdgeInsets.symmetric(horizontal: _hubPadX, vertical: _hubPadY),
        child: Column(
          children: [
            Text(
              s.ob5_hub,
              textAlign: TextAlign.center,
              style: sans(_hubSize, FontWeight.w700, scheme.onPrimaryContainer),
            ),
            const SizedBox(height: _gapTier),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: _chipGap,
              runSpacing: _chipGap,
              children: [
                for (final (i, role) in roles.indexed)
                  _RoleChip(
                    key: ValueKey('ob5-chip-$i'),
                    label: onboardingCapitals(role, locale),
                    phase: _linear(
                      elapsed,
                      Step5Beats.hub + Step5Beats.chipsAfter + Step5Beats.chipStagger * i,
                      const Duration(milliseconds: 450),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// One role chip: a mono word in capitals in an accent outline, which pops in from 0.7 of itself.
class _RoleChip extends StatelessWidget {
  const _RoleChip({required this.label, required this.phase, super.key});

  final String label;
  final double phase;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final eased = _chipCurve.transform(phase);
    return Opacity(
      opacity: phase.clamp(0.0, 1.0),
      child: Transform.scale(
        scale: _chipFrom + (1 - _chipFrom) * eased,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: scheme.primary),
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          padding: const EdgeInsets.symmetric(horizontal: _chipPadX, vertical: _chipPadY),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontFamily: AppTypography.mono,
              fontSize: _small,
              fontWeight: FontWeight.w400,
              height: onboardingMonoLine,
              letterSpacing: _small * _roleTrackingEm,
              color: scheme.onPrimaryContainer,
            ),
          ),
        ),
      ),
    );
  }
}

/// One of the two mode pills: `.mode{border:1px solid var(--edge);border-radius:999px;padding:6px;font-weight:600}`,
/// and `.on` in the accent.
class _Mode extends StatelessWidget {
  const _Mode({required this.boxKey, required this.label, required this.on});

  final Key boxKey;
  final String label;
  final bool on;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      key: boxKey,
      decoration: BoxDecoration(
        color: on ? scheme.primaryContainer : null,
        border: Border.all(color: on ? scheme.primary : scheme.outline),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      padding: const EdgeInsets.all(AppSpacing.sm - 2),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          fontSize: _small,
          fontWeight: FontWeight.w600,
          height: onboardingSansLine,
          letterSpacing: 0,
          color: on ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// A connector that grows out of its lower end: [length] tall at full strength, [phase] of it drawn, one logical pixel
/// wide, in the quiet edge ink until [hot] and the accent after.
class _Line extends StatelessWidget {
  const _Line({required this.length, required this.phase, required this.hot, this.lineKey});

  final double length;
  final double phase;
  final double hot;
  final Key? lineKey;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.bottomCenter,
      child: SizedBox(
        key: lineKey,
        width: 1,
        height: length * phase,
        child: ColoredBox(color: _taking(scheme.outline, scheme.primary, hot)),
      ),
    );
  }
}

/// The legs from the databases up to the Studios, one under each column.
class _Legs extends StatelessWidget {
  const _Legs({required this.elapsed, required this.litPhase});

  final Duration elapsed;
  final double litPhase;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: _legHeight,
    child: Row(
      spacing: _gapColumns,
      children: [
        for (var i = 0; i < _columns; i++)
          Expanded(
            child: _Line(
              lineKey: ValueKey('ob5-leg-$i'),
              length: _legHeight,
              phase: _phase(elapsed, Step5Beats.legs + Step5Beats.wireStagger * i, Step5Beats.arrival),
              hot: i == 0 ? litPhase : 0,
            ),
          ),
      ],
    ),
  );
}

/// The branch under Platform: the stem up into it, the rail the Studios hang under, and the three twigs that drop
/// from the rail into the tops of the Studios.
///
/// `.fan{height:34px}`: the stem is the top 13, the rail is the line at 13 from the centre of the first column to the
/// centre of the last, and the twigs are the 21 under it, one at the centre of each column.
class _Fan extends StatelessWidget {
  const _Fan({required this.elapsed, required this.hotPhase});

  final Duration elapsed;
  final double hotPhase;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final railPhase = _phase(elapsed, Step5Beats.branch, Step5Beats.railGrows);
    final stemPhase = _phase(elapsed, Step5Beats.branch, Step5Beats.arrival);
    return SizedBox(
      height: _stemHeight + _dropHeight,
      child: LayoutBuilder(
        builder: (context, fan) {
          // `left:calc((100% - 12px)/6)`: half a column in from each side.
          final column = (fan.maxWidth - _gapColumns * (_columns - 1)) / _columns;
          return Stack(
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                height: _stemHeight,
                child: _Line(lineKey: const ValueKey('ob5-stem'), length: _stemHeight, phase: stemPhase, hot: hotPhase),
              ),
              Positioned(
                left: column / 2,
                right: column / 2,
                top: _stemHeight,
                height: 1,
                child: Align(
                  child: SizedBox(
                    key: const ValueKey('ob5-rail'),
                    width: (fan.maxWidth - column) * railPhase,
                    height: 1,
                    child: ColoredBox(color: _taking(scheme.outline, scheme.primary, hotPhase)),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: _stemHeight,
                height: _dropHeight,
                child: Row(
                  spacing: _gapColumns,
                  children: [
                    for (var i = 0; i < _columns; i++)
                      Expanded(
                        child: _Line(
                          lineKey: ValueKey('ob5-twig-$i'),
                          length: _dropHeight,
                          phase: _phase(elapsed, Step5Beats.twigs + Step5Beats.twigStagger * i, Step5Beats.arrival),
                          hot: i == 0 ? hotPhase : 0,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
