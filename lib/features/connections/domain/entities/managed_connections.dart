import 'package:equatable/equatable.dart';
import 'package:libredb_mobile/shared/models/studio_connection.dart';

/// Studio's answer to `GET /api/connections/managed`: the connections and how long Studio expects the list to hold.
class ManagedConnections extends Equatable {
  const ManagedConnections({required this.connections, this.cacheHint});

  final List<StudioConnection> connections;

  /// How often Studio's own client asks again: 10 seconds under governance, `SEED_CACHE_TTL_MS` (60 seconds by
  /// default) otherwise, or null when Studio sent none.
  final Duration? cacheHint;

  @override
  List<Object?> get props => [connections, cacheHint];
}
