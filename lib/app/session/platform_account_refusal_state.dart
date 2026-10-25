part of 'platform_account_refusal_cubit.dart';

sealed class PlatformAccountRefusalState extends Equatable {
  const PlatformAccountRefusalState();

  @override
  List<Object?> get props => const [];
}

/// Platform has not refused the signed-in admin, or nobody is signed in to Platform.
final class PlatformAccountAccepted extends PlatformAccountRefusalState {
  const PlatformAccountAccepted();
}

/// Platform refused the signed-in admin; shown via `errorCode.resolve(context)` on the refusal page.
final class PlatformAccountRefused extends PlatformAccountRefusalState {
  const PlatformAccountRefused(this.errorCode);

  final AppErrorCode errorCode;

  @override
  List<Object?> get props => [errorCode];
}
