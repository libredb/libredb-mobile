import 'package:equatable/equatable.dart';
import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:libredb_mobile/features/studio_status/domain/entities/governance_outage.dart';

sealed class StudioStatusState extends Equatable {
  const StudioStatusState();

  @override
  List<Object?> get props => const [];
}

/// No liveness answer yet. The app opens meanwhile: the check never holds it back.
final class StudioStatusUnknown extends StudioStatusState {
  const StudioStatusUnknown();
}

/// Studio answered its liveness check.
final class StudioReachable extends StudioStatusState {
  const StudioReachable();
}

/// Studio did not answer its liveness check, for [error]. [retrying] is true while the user's retry runs, so the page
/// stays until the answer arrives.
///
/// [outage] is the governance outage that was shown when Studio stopped answering: liveness says nothing about
/// governance, so it shows again when Studio answers, until a connection route answers again.
final class StudioUnreachable extends StudioStatusState {
  const StudioUnreachable({required this.error, this.retrying = false, this.outage});

  final AppError error;
  final bool retrying;
  final GovernanceOutage? outage;

  @override
  List<Object?> get props => [error, retrying, outage];
}

/// Studio answers, but a connection route answered 503 `GOVERNANCE_UNAVAILABLE`; [outage] carries the wording.
final class StudioGovernanceUnavailable extends StudioStatusState {
  const StudioGovernanceUnavailable({required this.outage});

  final GovernanceOutage outage;

  @override
  List<Object?> get props => [outage];
}
