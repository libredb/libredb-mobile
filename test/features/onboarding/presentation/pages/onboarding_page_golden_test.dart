import 'package:alchemist/alchemist.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/features/onboarding/domain/repositories/adoption_figures_source.dart';
import 'package:libredb_mobile/features/onboarding/presentation/widgets/onboarding_panel.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/shared/adoption/adoption_figures.dart';
import 'package:libredb_mobile/shared/design_system/theme/app_theme.dart';

import '../../../../support/golden_app.dart' show kGoldenScreenSize;
import '../../../../support/test_env.dart';

/// What the introduction draws, in both brightnesses.
///
/// The four panels are rendered directly rather than by swiping the page: `alchemist` renders a frame, not a
/// session, and driving a pager through it would need a hook in the page that exists only for this file. The page's
/// own chrome — the dots, the two controls, the way the primary one changes on the last panel — is covered by
/// `onboarding_page_test.dart`, which can tap.
///
/// The figures are the ones shipped in the source, so the image does not move when `assets/adoption.json` is
/// refreshed: a committed number is a fact about the product, and a golden that re-renders every time it changes
/// would make every refresh a visual review.
void main() {
  setUpAll(() => TestEnv.autoReset = false);

  Widget panels({required bool dark}) {
    const figures = AdoptionFigures.fallback;
    return RepositoryProvider<IAdoptionFiguresSource>(
      create: (_) => const _ShippedFigures(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: dark ? AppTheme.dark() : AppTheme.light(),
        localizationsDelegates: const [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.delegate.supportedLocales,
        locale: const Locale('en'),
        home: Builder(
          builder: (context) {
            final l10n = S.of(context);
            return Scaffold(
              body: Column(
                children: [
                  Expanded(
                    child: OnboardingPanel(
                      icon: Icons.verified_user_outlined,
                      title: l10n.onboarding_platform_title,
                      body: l10n.onboarding_platform_body,
                    ),
                  ),
                  Expanded(
                    child: OnboardingPanel(
                      icon: Icons.storage_outlined,
                      title: l10n.onboarding_studio_title,
                      body: l10n.onboarding_studio_body,
                      figures: l10n.onboarding_studio_figures(figures.engines, figures.channels),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  for (final (name, dark) in [('light', false), ('dark', true)]) {
    goldenTest(
      'OnboardingPage — $name',
      fileName: 'onboarding_page_$name',
      pumpBeforeTest: pumpOnce,
      builder: () => GoldenTestGroup(
        columns: 1,
        children: [
          GoldenTestScenario(
            name: 'the panel that governs, and the one that carries the figures',
            child: SizedBox.fromSize(
              size: kGoldenScreenSize,
              child: panels(dark: dark),
            ),
          ),
        ],
      ),
    );
  }
}

/// The figures the source ships, so the image does not move when the asset is refreshed.
class _ShippedFigures implements IAdoptionFiguresSource {
  const _ShippedFigures();

  @override
  Future<AdoptionFigures> read() async => AdoptionFigures.fallback;
}
