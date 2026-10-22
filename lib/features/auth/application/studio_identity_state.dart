part of 'studio_identity_cubit.dart';

sealed class StudioIdentityState extends Equatable {
  const StudioIdentityState();

  @override
  List<Object?> get props => const [];
}

/// Nobody is signed in, or nothing has been asked yet.
final class StudioIdentityInitial extends StudioIdentityState {
  const StudioIdentityInitial();
}

final class StudioIdentityLoading extends StudioIdentityState {
  const StudioIdentityLoading();
}

final class StudioIdentityLoaded extends StudioIdentityState {
  const StudioIdentityLoaded(this.identity);

  final StudioIdentity identity;

  @override
  List<Object?> get props => [identity];
}

final class StudioIdentityFailure extends StudioIdentityState {
  const StudioIdentityFailure(this.errorCode);

  /// Shown via `errorCode.resolve(context)` with a retry; the raw message only goes to the log.
  final AppErrorCode errorCode;

  @override
  List<Object?> get props => [errorCode];
}
