part of 'revoke_grant_bloc.dart';

sealed class RevokeGrantEvent extends Equatable {
  const RevokeGrantEvent();

  @override
  List<Object?> get props => const [];
}

/// The admin confirmed removing the grant [grantId] of the connection [connectionId].
final class RevokeGrantConfirmed extends RevokeGrantEvent {
  const RevokeGrantConfirmed({required this.connectionId, required this.grantId});

  final String connectionId;
  final String grantId;

  @override
  List<Object?> get props => [connectionId, grantId];
}
