part of 'connection_policy_cubit.dart';

sealed class ConnectionPolicyState extends Equatable {
  const ConnectionPolicyState();

  @override
  List<Object?> get props => const [];
}

/// Nobody is signed in, or nothing has been asked yet.
final class ConnectionPolicyInitial extends ConnectionPolicyState {
  const ConnectionPolicyInitial();
}

final class ConnectionPolicyLoading extends ConnectionPolicyState {
  const ConnectionPolicyLoading();
}

final class ConnectionPolicyLoaded extends ConnectionPolicyState {
  const ConnectionPolicyLoaded(this.policy);

  final ConnectionPolicy policy;

  @override
  List<Object?> get props => [policy];
}

final class ConnectionPolicyFailure extends ConnectionPolicyState {
  const ConnectionPolicyFailure(this.errorCode);

  /// The raw message only goes to the log.
  final AppErrorCode errorCode;

  @override
  List<Object?> get props => [errorCode];
}
