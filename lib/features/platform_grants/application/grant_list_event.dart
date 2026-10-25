part of 'grant_list_bloc.dart';

sealed class GrantListEvent extends Equatable {
  const GrantListEvent();

  @override
  List<Object?> get props => const [];
}

/// Loads the grants of [connectionId], when the page opens or on the retry of a failure.
final class GrantListLoadRequested extends GrantListEvent {
  const GrantListLoadRequested(this.connectionId);

  final String connectionId;

  @override
  List<Object?> get props => [connectionId];
}

/// Asks again about the connection of the last load, keeping a loaded list on screen; ignored before any load.
///
/// Sent by a pull to refresh, the refresh banner's retry, after a revoke, and after a grant is saved.
final class GrantListRefreshRequested extends GrantListEvent {
  const GrantListRefreshRequested();
}
