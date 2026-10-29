import 'package:flutter/material.dart';
import 'package:libredb_mobile/features/onboarding/presentation/steps/step_1_connections.dart';
import 'package:libredb_mobile/features/onboarding/presentation/steps/step_2_browse.dart';
import 'package:libredb_mobile/features/onboarding/presentation/steps/step_3_editor.dart';
import 'package:libredb_mobile/features/onboarding/presentation/steps/step_4_credentials.dart';
import 'package:libredb_mobile/features/onboarding/presentation/steps/step_5_ecosystem.dart';
import 'package:libredb_mobile/features/onboarding/presentation/steps/step_6_platform.dart';

/// The animated hero of each of the six screens, by index — the one place the chassis and the steps meet.
///
/// Each step is a `StatefulWidget` of its own, plays itself as soon as it is shown and then stops; none of them is
/// tappable, because the primary control is the only control. The chassis draws the caption, the headline, the
/// body, the counter, the progress and the controls around whatever this hands back, so a step that drew any of
/// those would draw it twice.
///
/// **Wiring.** `OnboardingPage` takes this through its `heroBuilder`, and the route is where it is handed over:
///
/// ```dart
/// OnboardingPage(returnUrl: state.uri.queryParameters['returnUrl'], heroBuilder: onboardingStepHero)
/// ```
///
/// That line is deliberately *not* in `onboarding_routes.dart` on the chassis's own branch: the six step files are
/// written on four other branches and do not exist here, so a route that referenced them would take the page, its
/// route and all of their tests down with it. The chassis is built, tested and analysed without them; this file is
/// the only one on the branch the analyzer cannot resolve, and it resolves the moment the step branches land.
Widget onboardingStepHero(BuildContext context, int step) => switch (step) {
  0 => const Step1Connections(),
  1 => const Step2Browse(),
  2 => const Step3Editor(),
  3 => const Step4Credentials(),
  4 => const Step5Ecosystem(),
  _ => const Step6Platform(),
};
