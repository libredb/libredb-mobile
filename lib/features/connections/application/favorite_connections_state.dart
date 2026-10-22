part of 'favorite_connections_bloc.dart';

sealed class FavoriteConnectionsState extends Equatable {
  const FavoriteConnectionsState();

  @override
  List<Object?> get props => const [];
}

/// Nobody is signed in, or Studio names no subject for the user: the list shows no favorites and no star.
final class FavoriteConnectionsNone extends FavoriteConnectionsState {
  const FavoriteConnectionsNone();
}

final class FavoriteConnectionsLoading extends FavoriteConnectionsState {
  const FavoriteConnectionsLoading();
}

final class FavoriteConnectionsReady extends FavoriteConnectionsState {
  const FavoriteConnectionsReady(this.favorites);

  final ConnectionFavorites favorites;

  @override
  List<Object?> get props => [favorites];
}

/// The stored favorites could not be read: the list shows no favorites and no star.
final class FavoriteConnectionsUnavailable extends FavoriteConnectionsState {
  const FavoriteConnectionsUnavailable();
}
