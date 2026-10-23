part of 'object_rows_bloc.dart';

sealed class ObjectRowsEvent extends Equatable {
  const ObjectRowsEvent();

  @override
  List<Object?> get props => const [];
}

/// Runs the preview, on open, on a pull and on a retry. [role] is the one `StudioRoleScope` answers, null while Studio
/// has not named one, which the answer is masked for.
final class ObjectRowsRequested extends ObjectRowsEvent {
  const ObjectRowsRequested({required this.role});

  final StudioRole? role;

  @override
  List<Object?> get props => [role];
}
