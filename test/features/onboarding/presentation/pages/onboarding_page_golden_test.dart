import 'package:alchemist/alchemist.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/core/testing/app_key_constants.dart';
import 'package:libredb_mobile/features/onboarding/application/onboarding_cubit.dart';
import 'package:libredb_mobile/features/onboarding/data/repositories/onboarding_seen_preferences.dart';
import 'package:libredb_mobile/features/onboarding/presentation/pages/onboarding_page.dart';
import 'package:libredb_mobile/features/onboarding/presentation/steps/onboarding_steps.dart';

import '../../../../support/golden_app.dart' show goldenScreen, kGoldenScreenSize;
import '../../../../support/test_env.dart';

/// What the introduction draws: all six screens of the deck, in both brightnesses.
///
/// The page is the real one, wired the way the route wires it (`heroBuilder: onboardingStepHero`), so the image is
/// the hero of the step *and* the chassis around it: counter, caption, headline, body, progress rule, Skip and the
/// primary pill.
///
/// `alchemist` renders a frame, not a session, and the step the page is on is its own state. So each step is its own
/// golden (six steps, two brightnesses, twelve images), and `whilePerforming` swipes the page to that step the way a
/// thumb would, then lets the hero's one-shot animation play out, so the image is the resting frame the user is left
/// looking at. One golden per step rather than six scenarios in one, because an interaction applies to the whole
/// test and a composed frame would need a hook in the page that exists for no other reason. A failing image then
/// names the step that moved. The interaction also asserts the counter, so a swipe that lands on the wrong screen
/// fails the test instead of silently blessing a wrong image.
///
/// Languages are not repeated here: `onboarding_page_locales_test.dart` holds the Turkish copy, and the hero art is
/// language-free, so a second set of twelve images would mostly re-draw the same pixels.
void main() {
  setUpAll(() => TestEnv.autoReset = false);

  Widget page({required bool dark}) => BlocProvider<OnboardingCubit>(
    create: (_) => OnboardingCubit(store: OnboardingSeenPreferences()),
    child: goldenScreen(const OnboardingPage(heroBuilder: onboardingStepHero), dark: dark),
  );

  Future<void> swipeTo(WidgetTester tester, int step) async {
    await tester.pumpAndSettle();
    for (var i = 0; i < step; i++) {
      await tester.fling(find.byKey(onboardingHeadlineKey), const Offset(-300, 0), 800);
      await tester.pumpAndSettle();
    }
    final counter = tester.widget<Text>(find.byKey(onboardingCounterKey)).data!;
    expect(counter, startsWith('0${step + 1}'), reason: 'the swipe did not land on screen ${step + 1}');
  }

  for (final (name, dark) in [('light', false), ('dark', true)]) {
    for (var step = 0; step < onboardingStepCount; step++) {
      goldenTest(
        'OnboardingPage — screen ${step + 1}, $name',
        fileName: 'onboarding_page_${step + 1}_$name',
        pumpBeforeTest: pumpOnce,
        whilePerforming: (tester) async {
          await swipeTo(tester, step);
          return null;
        },
        builder: () => GoldenTestGroup(
          columns: 1,
          children: [
            GoldenTestScenario(
              name: 'screen ${step + 1} of $onboardingStepCount',
              child: SizedBox.fromSize(
                size: kGoldenScreenSize,
                child: page(dark: dark),
              ),
            ),
          ],
        ),
      );
    }
  }
}
