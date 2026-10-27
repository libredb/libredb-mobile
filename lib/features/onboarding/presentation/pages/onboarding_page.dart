import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:libredb_mobile/core/testing/app_key_constants.dart';
import 'package:libredb_mobile/features/onboarding/application/onboarding_cubit.dart';
import 'package:libredb_mobile/features/onboarding/navigation/onboarding_destination.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/shared/design_system/tokens/tokens.dart';

/// The introduction, shown once before the first sign-in.
///
/// The body is a placeholder: the four panels and the adoption figures replace it in the flow's own step. What is
/// settled here is the way the page leaves, because that is the part the router depends on. Both controls mark the
/// introduction seen and go to the login page; [returnUrl] is the location the first run was heading for, which the
/// redirect handed over and which the login page re-validates before honoring.
///
/// Skip and the final control do the same thing while there is one panel. They stay two controls because a user who
/// wants out looks for the word, not for the last panel — and the flow's step gives Skip its own meaning without
/// having to add it to the page then.
class OnboardingPage extends StatelessWidget {
  const OnboardingPage({super.key, this.returnUrl});

  /// Where the first run was going before the introduction took its place, or null when it was going nowhere special.
  final String? returnUrl;

  /// Marks the introduction seen and leaves. The cubit emits before it stores, so the redirect has the new answer by
  /// the time [GoRouter.go] runs even on a device that refuses the write.
  void _leave(BuildContext context) {
    context.read<OnboardingCubit>().markSeen();
    context.go(onboardingDestination(returnUrl: returnUrl));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context);
    final text = Theme.of(context).textTheme;
    return Scaffold(
      // Scrolls only when it has to. The body was a plain Column whose two Spacers absorbed the slack until there was
      // none, and then it overflowed: sideways at an accessibility text size, upright at the largest one, and on a
      // short viewport. Android's font-size setting reaches well past the largest ordinary step, so that is a setting
      // a real user has, and what they got was the overflow stripe across the first screen the app ever shows them.
      // The minimum height keeps the Spacers working at the sizes that do fit, so the layout is unchanged there.
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, viewport) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: viewport.maxHeight),
              child: IntrinsicHeight(child: _body(l10n, text, context)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _body(S l10n, TextTheme text, BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(),
          Text(l10n.onboarding_title, style: text.headlineSmall, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.md),
          Text(l10n.onboarding_subtitle, style: text.bodyMedium, textAlign: TextAlign.center),
          const Spacer(),
          SizedBox(
            height: AppSizes.minTapTarget,
            child: FilledButton(
              key: onboardingDoneKey,
              onPressed: () => _leave(context),
              child: Text(l10n.onboarding_done),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            height: AppSizes.minTapTarget,
            child: TextButton(
              key: onboardingSkipKey,
              onPressed: () => _leave(context),
              child: Text(l10n.onboarding_skip),
            ),
          ),
        ],
      ),
    );
  }
}
