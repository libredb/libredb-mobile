part of 'revoke_grant_bloc.dart';

sealed class RevokeGrantState extends Equatable {
  const RevokeGrantState();

  @override
  List<Object?> get props => const [];
}

/// No revoke has run yet.
final class RevokeGrantIdle extends RevokeGrantState {
  const RevokeGrantIdle();
}

final class RevokeGrantInProgress extends RevokeGrantState {
  const RevokeGrantInProgress(this.grantId);

  final String grantId;

  @override
  List<Object?> get props => [grantId];
}

final class RevokeGrantSucceeded extends RevokeGrantState {
  const RevokeGrantSucceeded(this.grantId);

  final String grantId;

  @override
  List<Object?> get props => [grantId];
}

/// Platform answered 404: the grant was revoked meanwhile, or the connection is gone.
final class RevokeGrantAlreadyRemoved extends RevokeGrantState {
  const RevokeGrantAlreadyRemoved(this.grantId);

  final String grantId;

  @override
  List<Object?> get props => [grantId];
}

final class RevokeGrantFailed extends RevokeGrantState {
  const RevokeGrantFailed(this.grantId, {required this.errorCode});

  final String grantId;

  /// Shown via `errorCode.resolve(context)`; the raw message only goes to the log.
  final AppErrorCode errorCode;

  @override
  List<Object?> get props => [grantId, errorCode];
}
