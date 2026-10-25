import 'package:equatable/equatable.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/shared/models/platform_identity.dart';
import 'package:libredb_mobile/shared/models/studio_identity.dart';

/// How a mode switch of the live session ended, once the gate of the target switched to has answered.
sealed class SessionTargetSwitchResult extends Equatable {
  const SessionTargetSwitchResult();

  @override
  List<Object?> get props => const [];
}

/// Studio accepted the account and the stored target is now Studio: [identity] is Studio's `GET /api/auth/me` answer.
final class SwitchedToStudio extends SessionTargetSwitchResult {
  const SwitchedToStudio(this.identity);

  final StudioIdentity identity;

  @override
  List<Object?> get props => [identity];
}

/// Platform accepted the account and the stored target is now Platform: [identity] is Platform's `GET /api/v1/me`
/// answer.
final class SwitchedToPlatform extends SessionTargetSwitchResult {
  const SwitchedToPlatform(this.identity);

  final PlatformIdentity identity;

  @override
  List<Object?> get props => [identity];
}

/// The gate of the target switched to refused the account, or the new target could not be stored; the session keeps
/// its target. [errorCode] is shown to the user.
final class SessionTargetSwitchRefused extends SessionTargetSwitchResult {
  const SessionTargetSwitchRefused(this.errorCode);

  final AppErrorCode errorCode;

  @override
  List<Object?> get props => [errorCode];
}
