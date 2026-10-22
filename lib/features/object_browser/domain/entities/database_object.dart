import 'package:equatable/equatable.dart';

/// A table, view, function or other object in a container.
class DatabaseObject extends Equatable {
  const DatabaseObject({
    required this.path,
    required this.name,
    required this.kind,
    this.status,
    this.rowCount,
    this.sizeBytes,
  });

  /// The container path and one segment per nesting level, such as `[schema, table, trigger]`.
  final List<String> path;

  /// What to show, which may differ from the last segment of [path].
  final String name;
  final String kind;

  /// Present only when notable, such as `INVALID` or `DISABLED`.
  final String? status;
  final int? rowCount;
  final int? sizeBytes;

  @override
  List<Object?> get props => [path, name, kind, status, rowCount, sizeBytes];
}
