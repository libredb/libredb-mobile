part of 'withdraw_access_request_bloc.dart';

sealed class WithdrawAccessRequestEvent extends Equatable {
  const WithdrawAccessRequestEvent();

  @override
  List<Object?> get props => const [];
}

/// The user confirmed the withdrawal of the pending request [requestId].
final class WithdrawAccessRequestRequested extends WithdrawAccessRequestEvent {
  const WithdrawAccessRequestRequested(this.requestId);

  final String requestId;

  @override
  List<Object?> get props => [requestId];
}
