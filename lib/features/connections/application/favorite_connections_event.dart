part of 'favorite_connections_bloc.dart';

sealed class FavoriteConnectionsEvent extends Equatable {
  const FavoriteConnectionsEvent();

  @override
  List<Object?> get props => const [];
}

/// The identity provider's subject of the signed-in user, from Studio's `GET /api/auth/me`, or null when nobody is
/// signed in or Studio names no subject.
final class FavoriteConnectionsSubjectChanged extends FavoriteConnectionsEvent {
  const FavoriteConnectionsSubjectChanged(this.subject);

  final String? subject;

  @override
  List<Object?> get props => [subject];
}

/// Reads the favorites of the signed-in subject again, as the device stores them now, such as after 'Remove my data'
/// cleared them while the user stays signed in.
final class FavoriteConnectionsReloaded extends FavoriteConnectionsEvent {
  const FavoriteConnectionsReloaded();
}

/// Stars the connection, or removes its star.
final class FavoriteConnectionStarToggled extends FavoriteConnectionsEvent {
  const FavoriteConnectionStarToggled(this.connectionId);

  final String connectionId;

  @override
  List<Object?> get props => [connectionId];
}

/// The user opened the connection, which puts it first among the recent ones.
final class FavoriteConnectionOpened extends FavoriteConnectionsEvent {
  const FavoriteConnectionOpened(this.connectionId);

  final String connectionId;

  @override
  List<Object?> get props => [connectionId];
}
