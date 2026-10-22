import 'package:equatable/equatable.dart';

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

  @override
  List<Object?> get props => [id, name, type, host, port, database, environment, group];
}
