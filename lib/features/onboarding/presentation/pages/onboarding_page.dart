import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:libredb_mobile/core/testing/app_key_constants.dart';
import 'package:libredb_mobile/features/onboarding/application/onboarding_cubit.dart';
import 'package:libredb_mobile/features/onboarding/domain/repositories/adoption_figures_source.dart';
import 'package:libredb_mobile/features/onboarding/navigation/onboarding_destination.dart';
import 'package:libredb_mobile/features/onboarding/presentation/widgets/onboarding_panel.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/shared/adoption/adoption_figures.dart';
import 'package:libredb_mobile/shared/design_system/tokens/tokens.dart';

/// The introduction, shown once before the first sign-in: four panels that say what the three parts of LibreDB are
/// and where the product is listed.
///
/// **The panel is local state, not a cubit.** `OnboardingState` says so itself — routing every swipe through a
/// cubit would turn a four-panel flow into four variants for nothing. What the cubit owns is whether the
/// introduction has been shown at all, which the router depends on.
///
/// **The figures have no loading state and no error state**, because they cannot fail: `IAdoptionFiguresSource`
/// promises [AdoptionFigures.fallback] instead of throwing, and the fallback is the `initialData` here, so the
/// panels are drawn with numbers from the first frame and the asset only ever replaces them with fresher ones.
/// That is also why there is no BLoC for them: there is no event, no second state and nothing to retry.
///
/// Both controls mark the introduction seen and go to the login page; [returnUrl] is the location the first run was
/// heading for, which the redirect handed over and which the login page re-validates before honoring.
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key, this.returnUrl});

  /// Where the first run was going before the introduction took its place, or null when it was going nowhere special.
  final String? returnUrl;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  /// Platform, Studio, this app, and where the product is listed.
  static const int _panelCount = 4;

  final PageController _controller = PageController();
  late final Future<AdoptionFigures> _figures = context.read<IAdoptionFiguresSource>().read();

  int _panel = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Marks the introduction seen and leaves. The cubit emits before it stores, so the redirect has the new answer by
  /// the time [GoRouter.go] runs even on a device that refuses the write.
  void _leave() {
    context.read<OnboardingCubit>().markSeen();
    context.go(onboardingDestination(returnUrl: widget.returnUrl));
  }

  /// The primary control: the next panel while there is one, and the way out on the last.
  void _advance() {
    if (_panel == _panelCount - 1) {
      _leave();
      return;
    }
    _controller.nextPage(duration: AppDurations.normal, curve: AppDurations.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: FutureBuilder<AdoptionFigures>(
                future: _figures,
                initialData: AdoptionFigures.fallback,
                builder: (context, snapshot) => PageView(
                  controller: _controller,
                  onPageChanged: (panel) => setState(() => _panel = panel),
                  children: _panels(l10n, snapshot.data ?? AdoptionFigures.fallback),
                ),
              ),
            ),
            _Dots(count: _panelCount, current: _panel),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // The tap target has a floor, not a fixed height: a height pins the label to the box and a word
                  // that outgrows it is cut off in half, silently — there is no overflow stripe for text that
                  // simply does not fit its box. The word on this control is the longest in the flow and it
                  // changes with the language, so it is given room to grow and keeps the 48 pt minimum.
                  //
                  // Growing room means the label can wrap, which is why it is centred. A button label's box is as
                  // wide as its longest line, so the short line of a wrapped label would otherwise hang on the
                  // leading edge: at a text scale of 3.0 "Get started" breaks after the first word and
                  // "Başlayalım" breaks mid-word, and both leave a line with 184 pt of slack beside it.
                  ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: AppSizes.minTapTarget),
                    child: FilledButton(
                      key: onboardingDoneKey,
                      onPressed: _advance,
                      child: Text(
                        _panel == _panelCount - 1 ? l10n.onboarding_done : l10n.onboarding_next,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: AppSizes.minTapTarget),
                    // Skip stays on every panel, because a user who wants out looks for the word rather than for the
                    // last panel. It is not centred, because there is nothing to centre: a label that fits on one
                    // line is laid out in a box of exactly its own width, and this label is one short word in both
                    // languages — "Skip" and "Atla" still take a single line at a text scale of 3.0, where the
                    // primary control's word has already wrapped. An alignment no rendering can show is a line no
                    // test can defend.
                    child: TextButton(key: onboardingSkipKey, onPressed: _leave, child: Text(l10n.onboarding_skip)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _panels(S l10n, AdoptionFigures figures) {
    final panels = <OnboardingPanel>[
      OnboardingPanel(
        icon: Icons.verified_user_outlined,
        title: l10n.onboarding_platform_title,
        body: l10n.onboarding_platform_body,
      ),
      OnboardingPanel(
        icon: Icons.storage_outlined,
        title: l10n.onboarding_studio_title,
        body: l10n.onboarding_studio_body,
        figures: l10n.onboarding_studio_figures(figures.engines, figures.channels),
      ),
      OnboardingPanel(
        icon: Icons.phone_iphone_outlined,
        title: l10n.onboarding_mobile_title,
        body: l10n.onboarding_mobile_body,
      ),
      OnboardingPanel(
        icon: Icons.public_outlined,
        title: l10n.onboarding_listings_title,
        body: l10n.onboarding_listings_body(figures.listings),
      ),
    ];
    return [
      for (final (index, panel) in panels.indexed)
        // Where in the flow this is, said rather than only drawn: the dots carry it for a sighted reader and nothing
        // carried it for anyone else.
        Semantics(label: l10n.onboarding_panel_position(index + 1, panels.length), child: panel),
    ];
  }
}

/// The position in the flow, drawn. It is excluded from semantics because each panel already says the same thing in
/// words, and a screen reader that announced both would say it twice.
class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.current});

  final int count;
  final int current;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ExcludeSemantics(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var index = 0; index < count; index++)
            AnimatedContainer(
              duration: AppDurations.fast,
              curve: AppDurations.easeOut,
              margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
              height: AppSpacing.sm,
              width: index == current ? AppSpacing.xl : AppSpacing.sm,
              decoration: BoxDecoration(
                color: index == current ? colors.primary : colors.outlineVariant,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ),
        ],
      ),
    );
  }
}
