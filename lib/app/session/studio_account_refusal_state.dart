part of 'studio_account_refusal_cubit.dart';

sealed class StudioAccountRefusalState extends Equatable {
  const StudioAccountRefusalState();

  @override
  List<Object?> get props => const [];
}

/// Studio has not refused the signed-in account, or nobody is signed in.
final class StudioAccountAccepted extends StudioAccountRefusalState {
  const StudioAccountAccepted();
}

/// Studio refused the signed-in account; shown via `errorCode.resolve(context)` on the refusal page.
final class StudioAccountRefused extends StudioAccountRefusalState {
  const StudioAccountRefused(this.errorCode);

  final AppErrorCode errorCode;

  @override
  List<Object?> get props => [errorCode];
}
