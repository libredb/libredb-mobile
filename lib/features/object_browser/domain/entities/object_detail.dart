import 'package:equatable/equatable.dart';

/// The columns, indexes, foreign keys and exclusion constraints of an object with columns.
class ObjectDetail extends Equatable {
  const ObjectDetail({
    required this.path,
    required this.columns,
    required this.foreignKeys,
    this.indexes,
    this.indexesUnavailable,
    this.exclusionConstraints = const [],
  });

  final List<String> path;
  final List<ColumnSchema> columns;
  final List<ForeignKeySchema> foreignKeys;

  /// The indexes, or null when the engine could not read them for [indexesUnavailable].
  final List<IndexSchema>? indexes;
  final String? indexesUnavailable;

  /// Only where the engine has them (PostgreSQL's `EXCLUDE`); empty elsewhere.
  final List<ExclusionConstraintSchema> exclusionConstraints;

  @override
  List<Object?> get props => [path, columns, foreignKeys, indexes, indexesUnavailable, exclusionConstraints];
}

class ColumnSchema extends Equatable {
  const ColumnSchema({
    required this.name,
    required this.type,
    required this.nullable,
    required this.isPrimary,
    this.declaredType,
    this.defaultValue,
    this.sampled = false,
  });

  final String name;

  /// The engine's base name of the type, such as `numeric`.
  final String type;

  /// The type as the engine prints the declaration, modifier included, such as `numeric(20,2)`; absent where the
  /// engine has nothing beyond [type].
  final String? declaredType;
  final bool nullable;
  final bool isPrimary;
  final String? defaultValue;

  /// Inferred from sampled documents, as for a Firestore collection, rather than declared.
  final bool sampled;

  /// The type a person is shown: the declaration when Studio sends one, else [type].
  String get shownType => declaredType ?? type;

  @override
  List<Object?> get props => [name, type, declaredType, nullable, isPrimary, defaultValue, sampled];
}

class IndexSchema extends Equatable {
  const IndexSchema({required this.name, required this.columns, required this.unique});

  final String name;
  final List<String> columns;
  final bool unique;

  @override
  List<Object?> get props => [name, columns, unique];
}

class ForeignKeySchema extends Equatable {
  const ForeignKeySchema({required this.columnName, required this.referencedTable, required this.referencedColumn});

  final String columnName;
  final String referencedTable;
  final String referencedColumn;

  @override
  List<Object?> get props => [columnName, referencedTable, referencedColumn];
}

/// A PostgreSQL `EXCLUDE` constraint: its name and the definition `pg_get_constraintdef()` prints.
class ExclusionConstraintSchema extends Equatable {
  const ExclusionConstraintSchema({required this.name, required this.definition});

  final String name;
  final String definition;

  @override
  List<Object?> get props => [name, definition];
}
