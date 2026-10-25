part of 'platform_connection_active_bloc.dart';

sealed class PlatformConnectionActiveState extends Equatable {
  const PlatformConnectionActiveState();

  @override
  List<Object?> get props => const [];
}

/// No request has run yet.
final class PlatformConnectionActiveIdle extends PlatformConnectionActiveState {
  const PlatformConnectionActiveIdle();
}

final class PlatformConnectionActiveInProgress extends PlatformConnectionActiveState {
  const PlatformConnectionActiveInProgress(this.id);

  final String id;

  @override
  List<Object?> get props => [id];
}

/// Platform answered 200 with [connection] as it now holds it; its status can differ from the one asked for when
/// another admin changed it meanwhile.
final class PlatformConnectionActiveSucceeded extends PlatformConnectionActiveState {
  const PlatformConnectionActiveSucceeded(this.connection);

  /// Its text never carries the name.
  final PlatformConnection connection;

  @override
  List<Object?> get props => [connection];
}

/// Platform answered 404: the install has no such connection any more.
final class PlatformConnectionActiveGone extends PlatformConnectionActiveState {
  const PlatformConnectionActiveGone(this.id);

  final String id;

  @override
  List<Object?> get props => [id];
}

final class PlatformConnectionActiveFailed extends PlatformConnectionActiveState {
  const PlatformConnectionActiveFailed(this.id, {required this.errorCode});

  final String id;

  /// Shown via `errorCode.resolve(context)`, or the connection-worded text for a user-seats refusal; the raw message
  /// only goes to the log.
  final AppErrorCode errorCode;

  @override
  List<Object?> get props => [id, errorCode];
}
