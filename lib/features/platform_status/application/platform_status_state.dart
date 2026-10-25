import 'package:equatable/equatable.dart';
import 'package:libredb_mobile/core/errors/app_error.dart';

sealed class PlatformStatusState extends Equatable {
  const PlatformStatusState();

  @override
  List<Object?> get props => const [];
}

/// No liveness answer yet, or no check asked. Nothing is held back meanwhile.
final class PlatformStatusUnknown extends PlatformStatusState {
  const PlatformStatusUnknown();
}

/// Platform answered its liveness check.
final class PlatformReachable extends PlatformStatusState {
  const PlatformReachable();
}

/// Platform did not answer its liveness check, for [error]. [retrying] is true while a new check runs, so the page
/// stays until the answer arrives.
final class PlatformUnreachable extends PlatformStatusState {
  const PlatformUnreachable({required this.error, this.retrying = false});

  final AppError error;
  final bool retrying;

  @override
  List<Object?> get props => [error, retrying];
}
