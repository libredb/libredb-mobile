import 'package:equatable/equatable.dart';

/// Which rows of a SELECT to fetch. Studio pages a statement only when it adds the row bound itself, that is when the
/// statement has no LIMIT of its own; it then fetches [limit] rows from [offset].
class QueryPage extends Equatable {
  const QueryPage({this.limit, this.offset = 0, this.unlimited = false});

  /// The first page with Studio's default size (500 rows).
  static const first = QueryPage();

  /// The page after [previous], whose [QueryPagination.totalReturned] rows are already shown.
  factory QueryPage.after(QueryPagination previous) =>
      QueryPage(limit: previous.limit, offset: previous.offset + previous.totalReturned);

  final int? limit;
  final int offset;

  /// Raises the bound to Studio's maximum (100000 rows); ask the user first, as Studio's own UI does.
  final bool unlimited;

  Map<String, Object> toJson() => {'limit': ?limit, 'offset': offset, if (unlimited) 'unlimited': true};

  @override
  List<Object?> get props => [limit, offset, unlimited];
}

/// How a result relates to the rows the statement would return.
class QueryPagination extends Equatable {
  const QueryPagination({
    required this.limit,
    required this.offset,
    required this.hasMore,
    required this.totalReturned,
    required this.wasLimited,
  });

  final int limit;
  final int offset;

  /// More rows follow; fetch them with [QueryPage.after].
  final bool hasMore;

  /// The rows on this page.
  final int totalReturned;

  /// Studio added the row bound to the statement.
  final bool wasLimited;

  @override
  List<Object?> get props => [limit, offset, hasMore, totalReturned, wasLimited];
}
