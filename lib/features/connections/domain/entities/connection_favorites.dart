import 'package:equatable/equatable.dart';

/// The connections one signed-in subject starred and opened on this device, by connection id.
///
/// An id stays here when Studio no longer lists the connection, so a grant that is unavailable for a while keeps its
/// star; the list shows only the ids it has.
final class ConnectionFavorites extends Equatable {
  const ConnectionFavorites({required this.starred, required this.recent});

  static const empty = ConnectionFavorites(starred: {}, recent: []);

  final Set<String> starred;

  /// The opened connections, the one opened last first, each once.
  final List<String> recent;

  @override
  List<Object?> get props => [starred, recent];
}
