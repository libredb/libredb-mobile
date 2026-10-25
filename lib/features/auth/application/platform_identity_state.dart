part of 'platform_identity_cubit.dart';

sealed class PlatformIdentityState extends Equatable {
  const PlatformIdentityState();

  @override
  List<Object?> get props => const [];
}

/// Nobody is signed in to Platform, or nothing has been asked yet.
final class PlatformIdentityInitial extends PlatformIdentityState {
  const PlatformIdentityInitial();
}

final class PlatformIdentityLoading extends PlatformIdentityState {
  const PlatformIdentityLoading();
}

final class PlatformIdentityLoaded extends PlatformIdentityState {
  const PlatformIdentityLoaded(this.identity);

  final PlatformIdentity identity;

  @override
  List<Object?> get props => [identity];
}

final class PlatformIdentityFailure extends PlatformIdentityState {
  const PlatformIdentityFailure(this.errorCode);

  /// Shown via `errorCode.resolve(context)` with a retry; the raw message only goes to the log.
  final AppErrorCode errorCode;

  @override
  List<Object?> get props => [errorCode];
}
