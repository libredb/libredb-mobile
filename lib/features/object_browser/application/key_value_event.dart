part of 'key_value_bloc.dart';

sealed class KeyValueEvent extends Equatable {
  const KeyValueEvent();

  @override
  List<Object?> get props => const [];
}

/// Reads the key, on open, on a pull and on a retry: the typed read of the type the page named or the user chose, else
/// `TYPE <key>`. [role] is the one `StudioRoleScope` answers, null while Studio has not named one, which the answer is
/// masked for.
final class KeyValueRequested extends KeyValueEvent {
  const KeyValueRequested({required this.role});

  final StudioRole? role;

  @override
  List<Object?> get props => [role];
}

/// 'Read value' after Studio answered the key's [type], one of the seven types a read exists for.
final class KeyValueTypedReadRequested extends KeyValueEvent {
  const KeyValueTypedReadRequested({required this.role, required this.type});

  final StudioRole? role;
  final String type;

  @override
  List<Object?> get props => [role, type];
}
