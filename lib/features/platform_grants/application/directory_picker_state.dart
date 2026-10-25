part of 'directory_picker_bloc.dart';

enum DirectoryPickerStatus { loading, loaded, failure }

/// The directory search on screen, one snapshot whose fields evolve together (CLAUDE.md, single state exception 2):
/// the trimmed [query], the [users] of every page loaded so far, the last [page] and Platform's [total].
///
/// [queryTooLong] is the local hint for a typed query longer than Platform accepts, which is never sent; the snapshot
/// keeps the last query that was.
final class DirectoryPickerState extends Equatable {
  const DirectoryPickerState({
    required this.status,
    required this.query,
    this.users = const [],
    this.page = 0,
    this.total = 0,
    this.lastPageSize = 0,
    this.error,
    this.queryTooLong = false,
    this.loadingMore = false,
    this.loadMoreError,
  });

  final DirectoryPickerStatus status;
  final String query;
  final List<DirectoryUser> users;

  /// The last page loaded, from 1; 0 before the first answer.
  final int page;

  /// The users matching [query] on every page, from a separate Keycloak count, so it can disagree with the pages.
  final int total;

  /// How many users the last page held, before any was left out as already listed.
  final int lastPageSize;

  /// Why the first page failed, shown via `error.resolve(context)`.
  final AppErrorCode? error;

  final bool queryTooLong;

  final bool loadingMore;

  /// Why the last "load more" failed; the loaded users stay on screen with a retry row.
  final AppErrorCode? loadMoreError;

  /// Whether a next page can be asked for: Platform's total says more users match, the last page was full, and the
  /// next page is one Platform accepts. Either signal stops the paging, since the total can disagree with the pages.
  bool get canLoadMore =>
      status == DirectoryPickerStatus.loaded &&
      !loadingMore &&
      page * DirectoryPage.pageSize < total &&
      lastPageSize == DirectoryPage.pageSize &&
      page < DirectoryPage.maxPage;

  DirectoryPickerState _with({bool? queryTooLong, bool? loadingMore, AppErrorCode? Function()? loadMoreError}) =>
      DirectoryPickerState(
        status: status,
        query: query,
        users: users,
        page: page,
        total: total,
        lastPageSize: lastPageSize,
        error: error,
        queryTooLong: queryTooLong ?? this.queryTooLong,
        loadingMore: loadingMore ?? this.loadingMore,
        loadMoreError: loadMoreError == null ? this.loadMoreError : loadMoreError(),
      );

  @override
  List<Object?> get props => [
    status,
    query,
    users,
    page,
    total,
    lastPageSize,
    error,
    queryTooLong,
    loadingMore,
    loadMoreError,
  ];

  /// Not the query nor a user: this text can reach a log.
  @override
  String toString() =>
      'DirectoryPickerState(status: ${status.name}, users: ${users.length}, page: $page, total: $total, '
      'error: ${error?.key}, queryTooLong: $queryTooLong, loadingMore: $loadingMore, '
      'loadMoreError: ${loadMoreError?.key})';
}
