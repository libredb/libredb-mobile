import 'package:equatable/equatable.dart';
import 'package:libredb_mobile/shared/models/studio_access.dart';

/// A database connection Studio offers the signed-in user, without its credentials.
///
/// Studio opens it by [id] (`seed:<id>`), so the app never holds a secret for it.
class StudioConnection extends Equatable {
  const StudioConnection({
    required this.id,
    required this.name,
    required this.type,
    this.host,
    this.port,
    this.database,
    this.environment,
    this.group,
    this.color,
    this.readOnly = false,
    this.managed = false,
    this.seedId,
    this.access,
    this.queryTimeout,
  });

  final String id;
  final String name;

  /// The engine, such as `postgres` or `sqlite`.
  final String type;
  final String? host;
  final int? port;
  final String? database;

  /// `production`, `staging`, `development`, `local` or `other`, when Studio's configuration names one.
  final String? environment;
  final String? group;

  /// The operator's color for the connection, as `#rrggbb`.
  final String? color;

  /// Whether the operator set the connection read only in Studio's seed configuration, for every user.
  final bool readOnly;

  /// Whether Studio keeps the connection's credentials to itself; an unmanaged seed is copied into Studio's browser.
  final bool managed;

  /// The id in Studio's seed configuration, without the `seed:` prefix; a governed connection may send none.
  final String? seedId;

  /// The level of the signed-in user's grant under governance; null without governance or from an older Studio.
  final StudioAccess? access;

  /// How long Studio lets a statement run on this connection, when the connection sets its own or governance sends its
  /// runtime setting; null means Studio's default of 60 seconds.
  final Duration? queryTimeout;

  /// Whether Studio refuses every statement that writes on this connection for the signed-in user.
  ///
  /// The lock in the list and the app bar and the write confirmation read this, never [readOnly] or [access] alone.
  bool get readOnlyForUser => switch (access) {
    StudioAccess.read => true,
    StudioAccess.write => readOnly,
    null => readOnly,
  };

  @override
  List<Object?> get props => [
    id,
    name,
    type,
    host,
    port,
    database,
    environment,
    group,
    color,
    readOnly,
    managed,
    seedId,
    access,
    queryTimeout,
  ];
}
