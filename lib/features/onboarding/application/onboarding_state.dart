import 'package:equatable/equatable.dart';

/// Whether this launch has to show the introduction.
///
/// Three variants and no fields: the question has exactly three answers and none of them carries data. The panel the
/// user is on is deliberately not here — it is local state in the page, because routing every swipe frame through a
/// cubit would turn a four-panel flow into four variants for nothing.
///
/// Sealed rather than one state with a status enum, because all three of CLAUDE.md's exceptions fail: nothing renders
/// the introduction while reacting to a different state, there is no bundle of fields that evolve together, and there
/// is no form. Every consumer switches on it, so a fourth variant fails to compile until each one handles it.
sealed class OnboardingState extends Equatable {
  const OnboardingState();

  @override
  List<Object?> get props => const [];
}

/// The stored flag is being read at startup. The app shows no page meanwhile, so a first run never paints the login
/// page and then jumps off it.
final class OnboardingRestoring extends OnboardingState {
  const OnboardingRestoring();
}

/// This device has not shown the introduction, so it has to.
final class OnboardingRequired extends OnboardingState {
  const OnboardingRequired();
}

/// This device has shown the introduction, or could not be asked. Either way the app opens where it always does.
final class OnboardingSeen extends OnboardingState {
  const OnboardingSeen();
}
