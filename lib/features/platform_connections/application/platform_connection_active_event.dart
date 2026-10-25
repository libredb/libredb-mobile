part of 'platform_connection_active_bloc.dart';

sealed class PlatformConnectionActiveEvent extends Equatable {
  const PlatformConnectionActiveEvent();

  @override
  List<Object?> get props => const [];
}

/// The admin confirmed enabling ([active] true) or disabling the connection [id]; it carries no name.
final class PlatformConnectionActiveRequested extends PlatformConnectionActiveEvent {
  const PlatformConnectionActiveRequested(this.id, {required this.active});

  final String id;
  final bool active;

  @override
  List<Object?> get props => [id, active];
}
