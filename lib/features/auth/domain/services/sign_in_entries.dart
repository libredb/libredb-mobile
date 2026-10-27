import 'package:libredb_mobile/infrastructure/config/environment.dart';
import 'package:libredb_mobile/shared/models/session_target.dart';

/// Which sign-in entries a build offers, in the order the page shows them.
///
/// **Platform may be restyled, never removed.** `docs/platform.md` says a user whose token carries no `studioRole`
/// cannot sign in to Studio at all, so a build that reaches Platform must offer the Platform entry or that user has
/// no way in. The rule lived in a getter buried in the page's `State`, where it could not be read without pumping
/// the screen and where the next person to restyle the entries would not have met it (#379).
List<SessionTarget> signInEntriesFor(PlatformTargetConfig platform) => switch (platform) {
  PlatformConfigured() => const [SessionTarget.studio, SessionTarget.platform],
  PlatformNotConfigured() => const [SessionTarget.studio],
};
