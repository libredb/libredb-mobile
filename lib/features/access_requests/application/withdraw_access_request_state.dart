part of 'withdraw_access_request_bloc.dart';

sealed class WithdrawAccessRequestState extends Equatable {
  const WithdrawAccessRequestState();

  @override
  List<Object?> get props => const [];
}

/// No withdraw has run yet.
final class WithdrawAccessRequestIdle extends WithdrawAccessRequestState {
  const WithdrawAccessRequestIdle();
}

final class WithdrawAccessRequestInProgress extends WithdrawAccessRequestState {
  const WithdrawAccessRequestInProgress(this.requestId);

  final String requestId;

  @override
  List<Object?> get props => [requestId];
}

/// Platform withdrew the request; [request] is it as Platform now holds it.
final class WithdrawAccessRequestDone extends WithdrawAccessRequestState {
  const WithdrawAccessRequestDone(this.request);

  final MyAccessRequest request;

  @override
  List<Object?> get props => [request];
}

final class WithdrawAccessRequestFailed extends WithdrawAccessRequestState {
  const WithdrawAccessRequestFailed(this.requestId, {required this.errorCode});

  final String requestId;

  /// Shown via `errorCode.resolve(context)`; the raw message only goes to the log.
  final AppErrorCode errorCode;

  @override
  List<Object?> get props => [requestId, errorCode];
}
