part of 'connection_check_bloc.dart';

sealed class ConnectionCheckState extends Equatable {
  const ConnectionCheckState();

  @override
  List<Object?> get props => const [];
}

/// Nothing checked yet: the sheet never checks on its own.
final class ConnectionCheckIdle extends ConnectionCheckState {
  const ConnectionCheckIdle();
}

/// Not checked, because the engine resumes billed compute (`capabilities.resumesBilledCompute`) and a check would
/// wake it; the user may check anyway.
final class ConnectionCheckNotChecked extends ConnectionCheckState {
  const ConnectionCheckNotChecked();
}

final class ConnectionCheckChecking extends ConnectionCheckState {
  const ConnectionCheckChecking();
}

/// Studio connected and read the server's health in [latency], when it sent one; [warnings] are what the server
/// cautioned while the connection opened.
final class ConnectionCheckOnline extends ConnectionCheckState {
  const ConnectionCheckOnline({this.latency, this.warnings = const []});

  final Duration? latency;
  final List<QueryWarning> warnings;

  @override
  List<Object?> get props => [latency, warnings];
}

/// Studio connected but could not read the server's health; [message] is Studio's sentence, which names why, and
/// [warnings] are what the server cautioned while the connection opened.
final class ConnectionCheckDegraded extends ConnectionCheckState {
  const ConnectionCheckDegraded({required this.message, this.warnings = const []});

  final String message;
  final List<QueryWarning> warnings;

  @override
  List<Object?> get props => [message, warnings];
}

/// The check failed. The sheet shows [error] through `StudioErrorBanner`, which shows the translated message of
/// [errorCode], the `fixStatement` of a refused database credential and the countdown of a rate limit, and never
/// the raw message.
final class ConnectionCheckFailed extends ConnectionCheckState {
  const ConnectionCheckFailed({required this.error});

  final AppError error;

  AppErrorCode get errorCode => AppErrorCode.fromKey(error.code) ?? AppErrorCode.generic;

  @override
  List<Object?> get props => [error];
}
