/// The design system's tokens, in one import.
///
/// `components/components.dart` is a barrel with 26 consumers; `tokens/` had none, so a screen imported
/// `app_spacing.dart` by name — because the author already knew spacing existed — and never learned that
/// `app_sizes.dart` or `app_breakpoints.dart` did. That is how `login_page.dart` and `community_section_widget.dart`
/// came to hold every raw `fontSize`, every `Color(0x…)` and every `circular(999)` in the app while importing no part
/// of the design system at all.
///
/// `app_typography.dart` is deliberately not exported. It is an input to `AppTheme`, not something a screen reads:
/// a widget takes its text styles from `Theme.of(context).textTheme`.
library;

export 'app_breakpoints.dart';
export 'app_durations.dart';
export 'app_gradients.dart';
export 'app_radius.dart';
export 'app_sizes.dart';
export 'app_spacing.dart';
export 'engine_icons.dart';
