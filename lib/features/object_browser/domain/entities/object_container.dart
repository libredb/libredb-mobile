import 'package:equatable/equatable.dart';

/// A database, schema or keyspace of a connection.
class ObjectContainer extends Equatable {
  const ObjectContainer({
    required this.path,
    required this.name,
    required this.level,
    this.isSessionDefault = false,
    this.kinds,
  });

  /// Its address, one segment per level from the top, which the other object requests take as `container`.
  final List<String> path;
  final String name;

  /// Its index in [ProviderMeta.containerLevels].
  final int level;

  /// The container a statement runs in when it names none.
  final bool isSessionDefault;

  /// The kinds it can hold, or null for every kind of the engine.
  final List<String>? kinds;

  @override
  List<Object?> get props => [path, name, level, isSessionDefault, kinds];
}
