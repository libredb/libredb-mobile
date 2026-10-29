import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:libredb_mobile/core/testing/app_key_constants.dart';
import 'package:libredb_mobile/features/onboarding/application/onboarding_cubit.dart';
import 'package:libredb_mobile/features/onboarding/navigation/onboarding_destination.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/shared/design_system/tokens/app_typography.dart';
import 'package:libredb_mobile/shared/design_system/tokens/tokens.dart';

/// Builds the animated hero of one step of the introduction, by index.
///
/// Each step is its own `StatefulWidget` under `presentation/steps/`, plays itself as soon as it is shown, and then
/// stops. A step draws **only** its hero: the caption, the headline, the body, the counter, the progress and the
/// controls are the chassis's, so that all six read as one screen with one thing changing.
typedef OnboardingHeroBuilder = Widget Function(BuildContext context, int step);

/// How many screens the introduction has. The counter's denominator, the number of segments in the progress rule
/// and the step the primary control leaves on are all this one number.
const int onboardingStepCount = 6;

/// The lines of its own type the headline block is given, whatever the title in it comes to.
///
/// The prototype's `h2{min-height:98px}` over `30px/1.08` type is three of its lines, and the app's `displaySmall`
/// is the same 30/1.08, so the rule carries over as a line count rather than as a pixel count — it then holds at
/// any text size, which a pixel would not.
const int _headlineLines = 3;

/// The least the hero is ever given, in logical pixels.
///
/// The hero is the one part of the page that yields. At the ordinary text size it takes the whole slack the words
/// leave — 493pt on a 390x844 phone, which is what the approved prototype measures on all six of its screens — and
/// at an accessibility text size the words grow into it until only this is left, at which point the page starts to
/// scroll and both controls stay reachable. The prototype has no text-scaling story to copy, so this number is
/// mine; it is set where a hero still reads as a picture rather than a sliver.
const double _heroFloor = 180;

/// The connection the second and third screens are set on. A connection name reads the same in every language, so
/// it is a value the captions take rather than a string either language owns.
const String _demoConnection = 'orders-prod';

/// The eyebrow tracking of the design system's mono overline, in the system's own unit — a fraction of the size.
///
/// `AppTypography` deliberately leaves `labelSmall` untracked: its own note says the system ties 0.1em to the
/// mono eyebrow treatment and that this app's 33 `labelSmall` call sites are ordinary small labels rather than
/// eyebrows. The caption and the step counter are the two that *are* eyebrows, so they take it here instead of
/// widening every other label in the app.
const double _eyebrowTrackingEm = 0.1;

/// How wide the counter's numbers are drawn: `01 / 06`, not `1 / 6`. Padding is a drawing decision, so it is made
/// here rather than in the ARB, whose `ob_step` carries the shape of the line and whose placeholders are numbers.
const int _counterDigits = 2;

/// The introduction, shown once before the first sign-in: six screens that say what the app does, what it never
/// holds, and who decides what you may reach.
///
/// **This file is the chassis, not the screens.** It owns the frame the prototype agreed — the step counter in the
/// corner, the caption, the headline with its one accented word, the body, the six-segment progress rule and the
/// two controls — and it owns the step the flow is on. The animated hero of each step comes from [heroBuilder].
///
/// Three things the audits of the prototype settled, and each one is a layout decision rather than a preference:
///
/// * **The headline and body boxes are fixed, so nothing moves between screens.** They are not fixed to a pixel
///   count, which no translation survives: each box reserves the height of the *tallest of the six strings* in the
///   language and at the text size actually in force, measured against the width actually available. Nothing is
///   ever cut off to make it — if a string outgrows the reserve, the reserve is simply taller.
///
///   The foot is held down by the hero above it, which takes all the slack, so the controls would sit at the
///   bottom even without the reserve. What the reserve buys is the **words'** own y: without it the headline of a
///   two-line screen starts a line and a half lower than the headline of a three-line one, and the eye is dragged
///   up and down the six screens. `onboarding_chassis_test.dart` measures both and says which of the two bites.
/// * **One ground.** Every colour comes from `Theme.of(context).colorScheme`, so the page is wholly light or wholly
///   dark with the rest of the app. There is no inverted panel and no second surface.
/// * **The last control keeps its promise.** Skip and the primary control on the sixth screen both mark the
///   introduction seen and go to the sign-in; neither loops back to the first screen.
///
/// **The step is local state, not a cubit.** What the cubit owns is whether the introduction has been shown at all,
/// which the router depends on; routing six taps of one control through it would buy nothing. [returnUrl] is the
/// location the first run was heading for, which the redirect handed over and which the login page re-validates.
///
/// **The hero must be able to report an intrinsic height.** The frame pins the foot to the bottom and gives the
/// hero the slack above it, and it does that by measuring the column — so a step whose root is a `LayoutBuilder`
/// cannot be measured. A `Column`, a `Stack`, a `SizedBox` or a `CustomPaint` with a size all can.
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key, this.returnUrl, this.heroBuilder});

  /// Where the first run was going before the introduction took its place, or null when it was going nowhere
  /// special.
  final String? returnUrl;

  /// The animated hero of each step. Null draws no hero, which is what the chassis's own tests pump: every claim
  /// the frame makes holds whatever the six steps paint inside it.
  final OnboardingHeroBuilder? heroBuilder;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> with SingleTickerProviderStateMixin {
  /// The entrance of the words of the step now on screen.
  ///
  /// The prototype re-renders its whole panel on a step change, so its words arrive with the same rise its hero
  /// children use. Flutter rebuilds in place, where the same change would read as a flicker, so the words are
  /// given that rise here: a step change is a page transition, which is what `AppDurations.slow` names, and the
  /// curve is the product's own `--ease-out` rather than Flutter's.
  late final AnimationController _controller = AnimationController(vsync: this, duration: AppDurations.slow, value: 1);
  late final Animation<double> _entrance = CurvedAnimation(parent: _controller, curve: AppDurations.easeOut);

  /// The frame scrolls only at a text size where the words outgrow it, and then the offset has to be given back on
  /// a step change: a reader who scrolled down the fifth screen's body otherwise meets the sixth screen already
  /// scrolled past its own headline.
  final ScrollController _scroll = ScrollController();

  int _step = 0;

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// Marks the introduction seen and leaves. The cubit emits before it stores, so the redirect has the new answer
  /// by the time [GoRouter.go] runs even on a device that refuses the write.
  void _leave() {
    context.read<OnboardingCubit>().markSeen();
    context.go(onboardingDestination(returnUrl: widget.returnUrl));
  }

  /// The primary control: the next screen while there is one, and the way out on the last.
  ///
  /// With animations turned off the new screen is not played in — it is already there, finished and usable, on the
  /// frame the tap produces.
  void _advance() {
    if (_step == onboardingStepCount - 1) {
      _leave();
      return;
    }
    final settled = MediaQuery.disableAnimationsOf(context);
    setState(() => _step++);
    if (_scroll.hasClients) {
      settled ? _scroll.jumpTo(0) : _scroll.animateTo(0, duration: AppDurations.slow, curve: AppDurations.easeOut);
    }
    if (settled) {
      _controller.value = 1;
    } else {
      _controller.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final eyebrow = theme.textTheme.labelSmall?.copyWith(
      fontFamily: AppTypography.mono,
      color: colors.onSurfaceVariant,
      letterSpacing: (theme.textTheme.labelSmall?.fontSize ?? 0) * _eyebrowTrackingEm,
    );
    final headline = theme.textTheme.displaySmall?.copyWith(color: colors.onSurface);
    final body = theme.textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant);
    final words = _words(l10n, _step);

    return Scaffold(
      body: SafeArea(
        // The page is laid out against the box it is given rather than against the screen, and it scrolls only when
        // it must: at the ordinary text size the hero absorbs all the slack and nothing scrolls, and at an
        // accessibility size the words grow past the screen and both controls stay reachable.
        child: LayoutBuilder(
          builder: (context, viewport) {
            final reserve = viewport.maxWidth - _gutter.horizontal;
            return SingleChildScrollView(
              controller: _scroll,
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: viewport.maxHeight),
                child: IntrinsicHeight(
                  child: Padding(
                    padding: _gutter,
                    child: AnimatedBuilder(
                      animation: _entrance,
                      builder: (context, _) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: _rise(Text(words.caption, key: onboardingCaptionKey, style: eyebrow)),
                              ),
                              _Counter(step: _step, style: eyebrow),
                            ],
                          ),
                          Expanded(
                            child: _HeroExtent(
                              floor: _heroFloor,
                              // `overflow-y:auto`, the prototype's own word for the hero. On a phone every hero
                              // fits the slack and this scrolls nothing; it is here because `flutter test` draws
                              // in Ahem, whose square-em glyphs make the same heroes a third taller than they are
                              // on a device, and a frame that is right on the phone must not be red in CI.
                              //
                              // The `LayoutBuilder` is safe under `_HeroExtent`, which answers the page's
                              // intrinsic question itself and never puts it to its child.
                              child: LayoutBuilder(
                                builder: (context, slack) => SingleChildScrollView(
                                  physics: const ClampingScrollPhysics(),
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(minHeight: slack.maxHeight),
                                    child: Center(
                                      child: KeyedSubtree(
                                        key: ValueKey<int>(_step),
                                        child: widget.heroBuilder?.call(context, _step) ?? const SizedBox.shrink(),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          _rise(
                            _Reserved(
                              candidates: _titles(l10n),
                              style: headline,
                              width: reserve,
                              minLines: _headlineLines,
                              child: Text.rich(
                                _accented(words.title, words.accent, colors.primary),
                                key: onboardingHeadlineKey,
                                style: headline,
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          _rise(
                            _Reserved(
                              candidates: _bodies(l10n),
                              style: body,
                              width: reserve,
                              child: Text(words.body, key: onboardingBodyKey, style: body),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          _Progress(step: _step, entrance: _entrance.value),
                          const SizedBox(height: AppSpacing.lg),
                          // The two controls sit at opposite ends of one line and stack when they no longer fit on
                          // one, which they do not at an accessibility text size: a `Row` overflowed its box by
                          // 124 pt in Turkish at a scale of 3.0 — a real Android setting — and drew the stripe
                          // across the controls of the first screen the app ever shows.
                          ConstrainedBox(
                            constraints: const BoxConstraints(minWidth: double.infinity),
                            child: Wrap(
                              alignment: WrapAlignment.spaceBetween,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: AppSpacing.lg,
                              runSpacing: AppSpacing.sm,
                              children: [
                                // Skip is on every screen, because someone who wants out looks for the word
                                // rather than for the last screen.
                                ConstrainedBox(
                                  constraints: const BoxConstraints(minHeight: AppSizes.minTapTarget),
                                  child: TextButton(
                                    key: onboardingSkipKey,
                                    onPressed: _leave,
                                    child: Text(l10n.ob_skip),
                                  ),
                                ),
                                ConstrainedBox(
                                  constraints: const BoxConstraints(minHeight: AppSizes.minTapTarget),
                                  child: FilledButton(
                                    key: onboardingDoneKey,
                                    onPressed: _advance,
                                    child: Text(
                                      _step == onboardingStepCount - 1 ? l10n.ob_done : l10n.ob_next,
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// The rise the words of a new step arrive with: up into place as they fade in, and nothing at all when the
  /// device asks for no animation, because the controller is then already finished.
  Widget _rise(Widget child) => FadeTransition(
    opacity: _entrance,
    child: Transform.translate(offset: Offset(0, AppSpacing.md * (1 - _entrance.value)), child: child),
  );
}

/// The gutters of the frame. The left one is wide on purpose: it is the indent the prototype sets every screen's
/// words and hero against, and the counter sits in the narrow one opposite it.
const EdgeInsets _gutter = EdgeInsets.fromLTRB(AppSpacing.xxxxl, AppSpacing.xl, AppSpacing.xl, AppSpacing.xl);

/// The words of one step: everything the chassis draws around that step's hero.
typedef _Words = ({String caption, String title, String accent, String body});

_Words _words(S l10n, int step) => switch (step) {
  0 => (caption: l10n.ob1_cap, title: l10n.ob1_title, accent: l10n.ob1_accent, body: l10n.ob1_body),
  1 => (caption: l10n.ob2_cap(_demoConnection), title: l10n.ob2_title, accent: l10n.ob2_accent, body: l10n.ob2_body),
  2 => (caption: l10n.ob3_cap(_demoConnection), title: l10n.ob3_title, accent: l10n.ob3_accent, body: l10n.ob3_body),
  3 => (caption: l10n.ob4_cap, title: l10n.ob4_title, accent: l10n.ob4_accent, body: l10n.ob4_body),
  4 => (caption: l10n.ob5_cap, title: l10n.ob5_title, accent: l10n.ob5_accent, body: l10n.ob5_body),
  _ => (caption: l10n.ob6_cap, title: l10n.ob6_title, accent: l10n.ob6_accent, body: l10n.ob6_body),
};

/// Every headline of the flow, which is what the headline box reserves room for.
List<String> _titles(S l10n) => [
  l10n.ob1_title,
  l10n.ob2_title,
  l10n.ob3_title,
  l10n.ob4_title,
  l10n.ob5_title,
  l10n.ob6_title,
];

/// Every body of the flow, which is what the body box reserves room for.
List<String> _bodies(S l10n) => [
  l10n.ob1_body,
  l10n.ob2_body,
  l10n.ob3_body,
  l10n.ob4_body,
  l10n.ob5_body,
  l10n.ob6_body,
];

/// The headline, with the one run [accent] names painted in the accent colour and nothing else.
///
/// The run has to appear in the title verbatim — the ARB entry says so — and when it does not, the headline is
/// drawn whole rather than half-coloured, because a flow that loses a word is worse than one that loses a colour.
TextSpan _accented(String title, String accent, Color colour) {
  final at = accent.isEmpty ? -1 : title.indexOf(accent);
  if (at < 0) return TextSpan(text: title);
  return TextSpan(
    children: [
      if (at > 0) TextSpan(text: title.substring(0, at)),
      TextSpan(
        text: accent,
        style: TextStyle(color: colour),
      ),
      if (at + accent.length < title.length) TextSpan(text: title.substring(at + accent.length)),
    ],
  );
}

/// A box as tall as the tallest of [candidates], so that what it holds never moves what is under it.
///
/// The height is measured rather than declared: the same style, the same width and the same text size the real
/// paragraph is laid out with. A pixel count would be a claim about one language at one text size, which is the
/// claim that put the controls in a different place on each screen to begin with.
class _Reserved extends StatelessWidget {
  const _Reserved({
    required this.candidates,
    required this.style,
    required this.width,
    required this.child,
    this.minLines = 0,
  });

  final List<String> candidates;

  /// The least the box is given, counted in lines of [style].
  ///
  /// The prototype sets `h2{min-height:98px}` against its own `30px/1.08` type — three of its lines for titles it
  /// authors as two, so the headline sits in a block with air under it. Measured on the emulator, reserving only
  /// the tallest of the six titles gave 64, which is the two lines and none of the air.
  final int minLines;
  final TextStyle? style;
  final double width;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    var tallest = scaler.scale((style?.fontSize ?? 0) * (style?.height ?? 1)) * minLines;
    for (final candidate in candidates) {
      final painter = TextPainter(
        text: TextSpan(text: candidate, style: style),
        textDirection: direction,
        textScaler: scaler,
      )..layout(maxWidth: width);
      tallest = math.max(tallest, painter.height);
      painter.dispose();
    }
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: tallest),
      child: child,
    );
  }
}

/// The step counter: `01 / 06`, in the mono face, tracked open, in the corner opposite the caption.
///
/// The digits are padded and the separator is the ARB's, because the padding is a drawing decision and the shape of
/// the line is not. A screen reader hears the step in words instead — `02 / 06` read out digit by digit is not what
/// the counter means.
class _Counter extends StatelessWidget {
  const _Counter({required this.step, required this.style});

  final int step;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context);
    final padded = l10n
        .ob_step(step + 1, onboardingStepCount)
        .replaceAllMapped(RegExp(r'\d+'), (match) => match[0]!.padLeft(_counterDigits, '0'));
    return Semantics(
      label: l10n.ob_step_semantics(step + 1, onboardingStepCount),
      child: ExcludeSemantics(
        child: Text(padded, key: onboardingCounterKey, style: style),
      ),
    );
  }
}

/// The progress of the flow, drawn as a rule of [onboardingStepCount] segments — never dots.
///
/// Dots say "there are six of these"; a rule that fills says how much of the introduction is behind you, which is
/// the thing a reader of six screens wants to know. The segment of the step just reached fills with the same
/// entrance the words rise on, so one beat carries the whole change.
class _Progress extends StatelessWidget {
  const _Progress({required this.step, required this.entrance});

  final int step;

  /// How far the current step's entrance has got, 0 to 1.
  final double entrance;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ExcludeSemantics(
      child: Row(
        key: onboardingProgressKey,
        spacing: AppSpacing.xs,
        children: [
          for (var index = 0; index < onboardingStepCount; index++)
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: _colour(index, colors),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: const SizedBox(height: AppSpacing.xs),
              ),
            ),
        ],
      ),
    );
  }

  Color _colour(int index, ColorScheme colors) {
    if (index > step) return colors.outlineVariant;
    if (index < step || entrance >= 1) return colors.primary;
    return Color.lerp(colors.outlineVariant, colors.primary, entrance)!;
  }
}

/// A box that answers every intrinsic question with [floor] and never puts the question to its child.
///
/// The prototype's own stylesheet says what the hero is: `.hero{flex:1 1 auto;min-height:0;overflow-y:auto}`. It
/// takes the slack the words leave and shrinks rather than pushing them, which is why the controls sit at the same
/// `772..820` on all six of its screens in both themes and both languages — 24 measurements, one answer.
///
/// Flutter needs this said out loud. The page measures itself with an [IntrinsicHeight] so that [Expanded] has
/// slack to hand out inside a scroll view, and an `IntrinsicHeight` asks every child how tall it wants to be. Asked
/// that, a hero answers with its natural height and is given it — which put the primary control 14, 26, 176 and
/// 464pt below the fold on screens 1, 4, 5 and 6, and made the page scroll on four of six. Answering [floor]
/// instead leaves the hero exactly the slack and nothing else.
///
/// It also keeps the question away from a hero drawn with a `LayoutBuilder`, which cannot answer an intrinsic
/// question at all and throws when one reaches it.
///
/// A hero whose content does not fit the slack is *not* quietly scrolled here, unlike the prototype's
/// `overflow-y:auto`: it overflows, loudly, in a debug build and in every test. A step that does not fit is a step
/// drawn to the wrong size, and the prototype's own heroes never overflow (`scrollHeight == clientHeight` in all 24
/// measurements), so there is nothing faithful to preserve by hiding it.
class _HeroExtent extends SingleChildRenderObjectWidget {
  const _HeroExtent({required this.floor, required super.child});

  final double floor;

  @override
  _RenderHeroExtent createRenderObject(BuildContext context) => _RenderHeroExtent(floor);

  @override
  void updateRenderObject(BuildContext context, _RenderHeroExtent renderObject) => renderObject.floor = floor;
}

class _RenderHeroExtent extends RenderProxyBox {
  _RenderHeroExtent(this._floor);

  double get floor => _floor;
  double _floor;
  set floor(double value) {
    if (_floor == value) return;
    _floor = value;
    markNeedsLayout();
  }

  @override
  double computeMinIntrinsicHeight(double width) => _floor;

  @override
  double computeMaxIntrinsicHeight(double width) => _floor;

  // The page is laid out in a column, so nothing asks the hero for an intrinsic width. Answering without descending
  // keeps the promise this box makes whole: the child is never asked an intrinsic question.
  @override
  double computeMinIntrinsicWidth(double height) => 0;

  @override
  double computeMaxIntrinsicWidth(double height) => 0;
}
