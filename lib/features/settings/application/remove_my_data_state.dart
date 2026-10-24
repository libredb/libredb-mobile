part of 'remove_my_data_bloc.dart';

sealed class RemoveMyDataState extends Equatable {
  const RemoveMyDataState();

  @override
  List<Object?> get props => const [];
}

/// Nothing asked yet.
final class RemoveMyDataIdle extends RemoveMyDataState {
  const RemoveMyDataIdle();
}

/// The stores are being cleared.
final class RemoveMyDataInProgress extends RemoveMyDataState {
  const RemoveMyDataInProgress();
}

/// Every store is cleared; the page signs out next.
final class RemoveMyDataDone extends RemoveMyDataState {
  const RemoveMyDataDone();
}

/// A store could not be cleared, so the user stays signed in and may try again.
final class RemoveMyDataFailure extends RemoveMyDataState {
  const RemoveMyDataFailure({required this.errorCode});

  /// Shown through `errorCode.resolve(context)`; it names no stored value.
  final AppErrorCode errorCode;

  @override
  List<Object?> get props => [errorCode];
}
