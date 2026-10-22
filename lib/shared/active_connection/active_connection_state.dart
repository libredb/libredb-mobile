part of 'active_connection_cubit.dart';

/// The connection Browse and SQL work on.
sealed class ActiveConnectionState extends Equatable {
  const ActiveConnectionState();

  /// The open connection, or null when none is open.
  StudioConnection? get connection;

  @override
  List<Object?> get props => const [];
}

/// No connection is open.
final class ActiveConnectionNone extends ActiveConnectionState {
  const ActiveConnectionNone();

  @override
  StudioConnection? get connection => null;
}

final class ActiveConnectionSelected extends ActiveConnectionState {
  const ActiveConnectionSelected(this.connection);

  @override
  final StudioConnection connection;

  @override
  List<Object?> get props => [connection];
}

/// No connection is open because Studio no longer offers [vanished], the one that was: the app says so by its name and
/// never says why.
final class ActiveConnectionVanished extends ActiveConnectionState {
  const ActiveConnectionVanished(this.vanished);

  final StudioConnection vanished;

  @override
  StudioConnection? get connection => null;

  @override
  List<Object?> get props => [vanished];
}
