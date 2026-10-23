part of 'connection_check_bloc.dart';

/// Asks Studio to connect once. Every event of a sheet shares one droppable handler, so a second tap while a check
/// runs spends no second Studio request slot.
sealed class ConnectionCheckEvent extends Equatable {
  const ConnectionCheckEvent();

  @override
  List<Object?> get props => const [];
}

/// The Check button: checks the connection unless its engine resumes billed compute and the user has not accepted
/// that cost in this sheet.
final class ConnectionCheckRequested extends ConnectionCheckEvent {
  const ConnectionCheckRequested();
}

/// Check anyway: the user accepts that the check may wake billed compute, so it runs without reading the engine.
final class ConnectionCheckForced extends ConnectionCheckEvent {
  const ConnectionCheckForced();
}
