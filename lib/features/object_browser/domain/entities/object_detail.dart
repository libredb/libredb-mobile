import 'package:equatable/equatable.dart';

/// The columns, indexes and foreign keys of an object with columns.
class ObjectDetail extends Equatable {
  const ObjectDetail({
    required this.path,
    required this.columns,
    required this.foreignKeys,
    this.indexes,
    this.indexesUnavailable,
  });

  final List<String> path;
  final List<ColumnSchema> columns;
  final List<ForeignKeySchema> foreignKeys;

  /// The indexes, or null when the engine could not read them for [indexesUnavailable].
  final List<IndexSchema>? indexes;
  final String? indexesUnavailable;

  @override
  List<Object?> get props => [path, columns, foreignKeys, indexes, indexesUnavailable];
}

class ColumnSchema extends Equatable {
  const ColumnSchema({
    required this.name,
    required this.type,
    required this.nullable,
    required this.isPrimary,
    this.defaultValue,
    this.sampled = false,
  });

  final String name;
  final String type;
  final bool nullable;
  final bool isPrimary;
  final String? defaultValue;

  /// Inferred from sampled documents, as for a MongoDB collection, rather than declared.
  final bool sampled;

  @override
  List<Object?> get props => [name, type, nullable, isPrimary, defaultValue, sampled];
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
