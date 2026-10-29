part of 'my_access_requests_bloc.dart';

sealed class MyAccessRequestsEvent extends Equatable {
  const MyAccessRequestsEvent();

  @override
  List<Object?> get props => const [];
}

/// An event that asks Platform; a newer one replaces the one still running.
sealed class MyAccessRequestsFetchEvent extends MyAccessRequestsEvent {
  const MyAccessRequestsFetchEvent();
}

/// Loads the list, when the page opens or on the retry of a failure.
final class MyAccessRequestsLoadRequested extends MyAccessRequestsFetchEvent {
  const MyAccessRequestsLoadRequested();
}

/// Asks again, keeping a loaded list on screen until the answer; a pull to refresh, or a request the form just sent.
final class MyAccessRequestsRefreshRequested extends MyAccessRequestsFetchEvent {
  const MyAccessRequestsRefreshRequested();
}

/// Puts [request], as Platform now holds it, in the place of the loaded row with its id, such as a withdrawn one.
final class MyAccessRequestReplaced extends MyAccessRequestsEvent {
  const MyAccessRequestReplaced(this.request);

  final MyAccessRequest request;

  @override
  List<Object?> get props => [request];
}
