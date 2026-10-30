import 'package:flutter/material.dart';
import 'package:libredb_mobile/core/testing/app_key_constants.dart';
import 'package:libredb_mobile/features/onboarding/presentation/pages/onboarding_page.dart';
import 'package:libredb_mobile/features/onboarding/presentation/steps/onboarding_steps.dart';
import 'package:libredb_mobile/generated/l10n.dart';

/// The settings row that plays the introduction again.
///
/// The introduction is shown once, on the first run, and the router keeps a signed-in session off `/welcome` — so a
/// replay cannot be a visit to that route, and must not end where the first run ends, on the sign-in page. The deck
/// is pushed over the app instead and its way out pops it, which leaves the user on the settings they opened it from
/// and leaves the stored "seen" answer alone (#129).
///
/// It lives in the onboarding feature and is handed to the settings screen by the app layer, as the app lock section
/// is: a feature never imports another feature's internals.
class OnboardingReplayTile extends StatelessWidget {
  const OnboardingReplayTile({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    return ListTile(
      key: settingsIntroductionButtonKey,
      leading: Icon(Icons.auto_stories_outlined, color: colorScheme.primary),
      title: Text(l10n.settings_introduction),
      subtitle: Text(
        l10n.settings_introduction_subtitle,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
      ),
      trailing: Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
      onTap: () => replayTheIntroduction(context),
    );
  }
}

/// Plays the introduction over the current page and returns once the user leaves it.
///
/// Pushed on the root navigator, so the deck covers the shell it was opened from rather than sitting inside it, and
/// named so `AnalyticsRouteObserver` reports it like any other page.
Future<void> replayTheIntroduction(BuildContext context) {
  final navigator = Navigator.of(context, rootNavigator: true);
  return navigator.push<void>(
    MaterialPageRoute<void>(
      settings: const RouteSettings(name: 'welcomeReplay'),
      fullscreenDialog: true,
      builder: (context) => OnboardingPage(heroBuilder: onboardingStepHero, onLeave: () => Navigator.of(context).pop()),
    ),
  );
}
